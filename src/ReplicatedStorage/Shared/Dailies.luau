--!strict
-- Daily objective logic. Pure (no Roblox APIs): the server owns progress and rewards; the client only displays.
-- `daily` is the save-data table { Day = number, Progress = { ["1"] = n }, Claimed = { ["1"] = true } }.
-- Keys are strings because DataStore cannot store gapped numeric keys reliably.

export type Def = { Slot: number, Id: string, Kind: string, Target: number, Text: string, RewardBase: number }

local Dailies = {}

local SECONDS_PER_DAY = 86400

function Dailies.DayNumber(now: number): number
	return now // SECONDS_PER_DAY
end

function Dailies.SecondsUntilReset(now: number): number
	return SECONDS_PER_DAY - now % SECONDS_PER_DAY
end

-- Park-Miller PRNG: exact in Luau doubles.
local function makeRng(seed: number)
	local state = seed % 2147483646 + 1
	return function(): number
		state = state * 48271 % 2147483647
		return state / 2147483647
	end
end

-- The three objectives for a given day. Same day => same objectives on every server.
function Dailies.ForDay(day: number, cfg: any): { Def }
	local rng = makeRng(day * 9973 + 17)
	local order = {}
	for i = 1, #cfg.Templates do
		order[i] = i
	end
	for i = #order, 2, -1 do -- Fisher-Yates
		local j = math.floor(rng() * i) + 1
		order[i], order[j] = order[j], order[i]
	end

	local defs: { Def } = {}
	for slot = 1, cfg.SlotCount do
		local t = cfg.Templates[order[slot]]
		local target = t.Targets[math.min(slot, #t.Targets)]
		table.insert(defs, {
			Slot = slot,
			Id = t.Id,
			Kind = t.Kind,
			Target = target,
			Text = t.Text:format(target),
			RewardBase = cfg.SlotRewards[slot],
		})
	end
	return defs
end

-- Shards for completing a def. Scales with unlocked strata so the reward stays meaningful.
function Dailies.Reward(def: Def, strataUnlocked: number): number
	return math.floor(def.RewardBase * (1 + 0.5 * (math.max(strataUnlocked, 1) - 1)) + 0.5)
end

-- Reset progress when the UTC day changes. Returns true if it reset.
function Dailies.Refresh(daily: { [string]: any }, day: number): boolean
	if daily.Day ~= day then
		daily.Day = day
		daily.Progress = {}
		daily.Claimed = {}
		return true
	end
	return false
end

-- Record gameplay. Chain keeps the maximum; everything else accumulates. Progress is capped at the target.
function Dailies.Record(daily: { [string]: any }, defs: { Def }, kind: string, amount: number)
	if amount <= 0 then
		return
	end
	for _, def in defs do
		if def.Kind == kind then
			local key = tostring(def.Slot)
			local current = daily.Progress[key] or 0
			local updated = if kind == "Chain" then math.max(current, amount) else current + amount
			daily.Progress[key] = math.min(updated, def.Target)
		end
	end
end

function Dailies.IsComplete(daily: { [string]: any }, def: Def): boolean
	return (daily.Progress[tostring(def.Slot)] or 0) >= def.Target
end

function Dailies.CanClaim(daily: { [string]: any }, defs: { Def }, slot: any): boolean
	if type(slot) ~= "number" or slot % 1 ~= 0 then
		return false
	end
	local def = defs[slot]
	return def ~= nil and Dailies.IsComplete(daily, def) and daily.Claimed[tostring(slot)] ~= true
end

-- Client-facing view of today's objectives.
function Dailies.View(daily: { [string]: any }, defs: { Def }, strataUnlocked: number)
	local out = {}
	for _, def in defs do
		local key = tostring(def.Slot)
		table.insert(out, {
			Slot = def.Slot,
			Text = def.Text,
			Target = def.Target,
			Progress = daily.Progress[key] or 0,
			Reward = Dailies.Reward(def, strataUnlocked),
			Claimed = daily.Claimed[key] == true,
		})
	end
	return out
end

return Dailies
