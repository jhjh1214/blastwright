--!strict
-- Notice Board contract logic. Pure (no Roblox APIs): the server owns state and rewards, the client only displays.
-- State (save data `Contract`): { Day = number, Active = tier (1..3) or 0, Progress = number, Done = { ["1"] = true } }.
-- Keys are strings because DataStore cannot store gapped numeric keys reliably.

export type Offer = { Tier: number, Id: string, Kind: string, Param: string?, Target: number, Text: string, TierName: string }

local Contracts = {}

-- Park-Miller PRNG: exact in Luau doubles.
local function makeRng(seed: number)
	local state = seed % 2147483646 + 1
	return function(): number
		state = state * 48271 % 2147483647
		return state / 2147483647
	end
end

-- The three offers for a day: distinct templates, one per tier. Same day => same offers everywhere.
function Contracts.ForDay(day: number, cfg: any): { Offer }
	local rng = makeRng(day * 7919 + 101)
	local order = {}
	for i = 1, #cfg.Templates do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = math.floor(rng() * i) + 1
		order[i], order[j] = order[j], order[i]
	end
	local offers: { Offer } = {}
	for tier = 1, #cfg.Tiers do
		local t = cfg.Templates[order[tier]]
		local target = t.Targets[math.min(tier, #t.Targets)]
		table.insert(offers, { Tier = tier, Id = t.Id, Kind = t.Kind, Param = t.Param, Target = target, Text = t.Text:format(target), TierName = cfg.Tiers[tier] })
	end
	return offers
end

function Contracts.Default()
	return { Day = 0, Active = 0, Progress = 0, Done = {} }
end

-- A new day clears everything (an unfinished contract is lost, like the dailies).
function Contracts.Ensure(state: any, day: number)
	if state.Day ~= day then
		state.Day, state.Active, state.Progress, state.Done = day, 0, 0, {}
	end
end

-- Take a contract. Only one at a time, only a real offer, never one already finished today.
function Contracts.Accept(state: any, tier: any, offers: { Offer }): boolean
	if type(tier) ~= "number" or tier ~= math.floor(tier) or offers[tier] == nil then
		return false
	end
	if state.Active ~= 0 or state.Done[tostring(tier)] then
		return false
	end
	state.Active, state.Progress = tier, 0
	return true
end

-- Give the active contract up (progress is lost; it can be taken again today).
function Contracts.Abandon(state: any): boolean
	if state.Active == 0 then
		return false
	end
	state.Active, state.Progress = 0, 0
	return true
end

-- Something happened in play. Slay only counts for the matching Param; Chain and Floor keep the best; the rest add up.
function Contracts.Record(state: any, offers: { Offer }, kind: string, param: string?, amount: number)
	local offer = offers[state.Active]
	if not offer or offer.Kind ~= kind or amount ~= amount or amount <= 0 then
		return
	end
	if offer.Param ~= nil and offer.Param ~= param then
		return
	end
	if kind == "Chain" or kind == "Floor" then
		state.Progress = math.min(offer.Target, math.max(state.Progress, amount))
	else
		state.Progress = math.min(offer.Target, state.Progress + amount)
	end
end

function Contracts.IsComplete(state: any, offers: { Offer }): boolean
	local offer = offers[state.Active]
	return offer ~= nil and state.Progress >= offer.Target
end

-- Finish the active contract: returns its tier (so the caller can pay Rewards[tier]) or nil when it is not complete.
function Contracts.Claim(state: any, offers: { Offer }): number?
	if not Contracts.IsComplete(state, offers) then
		return nil
	end
	local tier = state.Active
	state.Done[tostring(tier)] = true
	state.Active, state.Progress = 0, 0
	return tier
end

-- What the client shows.
function Contracts.View(state: any, offers: { Offer })
	local list = {}
	for _, o in offers do
		table.insert(list, {
			Tier = o.Tier, TierName = o.TierName, Text = o.Text, Target = o.Target,
			Active = state.Active == o.Tier, Done = state.Done[tostring(o.Tier)] == true,
			Progress = state.Active == o.Tier and state.Progress or 0,
		})
	end
	return list
end

return Contracts
