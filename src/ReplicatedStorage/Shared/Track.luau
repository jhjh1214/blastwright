--!strict
-- The Blastwright Track logic. Pure (no Roblox APIs): the server adds XP and pays rewards, the client only shows.
-- State (save data `Track`): { Xp = total xp, Claimed = { ["3f"] = true, ["3p"] = true } } (level + "f" free / "p" premium).
local Track = {}

function Track.Default()
	return { Xp = 0, Claimed = {} }
end

-- XP needed to go from `level` to the next one.
function Track.XpForLevel(level: number, cfg: any): number
	return cfg.XpBase + cfg.XpStep * (level - 1)
end

-- Level (starting at 1) for a total XP, and the XP inside that level and the size of the level.
function Track.Progress(xp: number, cfg: any): (number, number, number)
	local level, left = 1, math.max(0, xp)
	while true do
		local need = Track.XpForLevel(level, cfg)
		if left < need then
			return level, left, need
		end
		left -= need
		level += 1
		if level > 100000 then
			return level, 0, need
		end
	end
end

-- Levels reached = the level you are on minus one (level 1 needs no xp, but its rewards need the first XP step).
function Track.LevelsReached(xp: number, cfg: any): number
	local level = Track.Progress(xp, cfg)
	return level - 1
end

-- Add XP. Returns the levels reached before and after (so the caller can announce level-ups).
function Track.Add(state: any, amount: number, cfg: any): (number, number)
	local before = Track.LevelsReached(state.Xp, cfg)
	if amount == amount and amount > 0 and amount < 1e9 then
		state.Xp += math.floor(amount)
	end
	return before, Track.LevelsReached(state.Xp, cfg)
end

-- XP for one volley.
function Track.VolleyXp(pops: number, cfg: any): number
	local x = cfg.Xp
	return x.VolleyBase + math.min(x.PopsCap, math.floor(math.max(0, pops) / 10) * x.PerTenPops)
end

local function key(level: number, premium: boolean): string
	return level .. (premium and "p" or "f")
end

-- Can this reward be claimed? Free: level reached. Premium: level reached AND the pass owned. Never twice. Levels beyond the
-- configured ones have only a free reward.
function Track.CanClaim(state: any, level: any, premium: any, owned: boolean, cfg: any): boolean
	if type(level) ~= "number" or level ~= math.floor(level) or level < 1 or type(premium) ~= "boolean" then
		return false
	end
	if level > Track.LevelsReached(state.Xp, cfg) then
		return false
	end
	if premium and (not owned or level > cfg.MaxLevel) then
		return false
	end
	return not state.Claimed[key(level, premium)]
end

-- Claim: returns the grants to pay, or nil when it cannot be claimed.
function Track.Claim(state: any, level: any, premium: any, owned: boolean, cfg: any): { any }?
	if not Track.CanClaim(state, level, premium, owned, cfg) then
		return nil
	end
	state.Claimed[key(level, premium)] = true
	if level > cfg.MaxLevel then
		return cfg.BonusPerLevelAfterMax
	end
	local entry = cfg.Levels[level]
	return premium and entry.Premium or entry.Free
end

-- What the client lists: a window of levels around your progress with their state. `first` is the first level to show.
function Track.View(state: any, owned: boolean, cfg: any, first: number, count: number)
	local reached = Track.LevelsReached(state.Xp, cfg)
	local list = {}
	for level = first, first + count - 1 do
		local entry = cfg.Levels[level]
		table.insert(list, {
			Level = level,
			Reached = level <= reached,
			Free = entry and entry.Free or cfg.BonusPerLevelAfterMax,
			Premium = entry and entry.Premium or nil,
			FreeClaimed = state.Claimed[key(level, false)] == true,
			PremiumClaimed = state.Claimed[key(level, true)] == true,
			CanFree = Track.CanClaim(state, level, false, owned, cfg),
			CanPremium = Track.CanClaim(state, level, true, owned, cfg),
		})
	end
	return list
end

-- How many rewards can be claimed right now (for a badge).
function Track.ClaimableCount(state: any, owned: boolean, cfg: any): number
	local n = 0
	local reached = math.min(Track.LevelsReached(state.Xp, cfg), cfg.MaxLevel + 50)
	for level = 1, reached do
		if Track.CanClaim(state, level, false, owned, cfg) then
			n += 1
		end
		if owned and level <= cfg.MaxLevel and Track.CanClaim(state, level, true, owned, cfg) then
			n += 1
		end
	end
	return n
end

return Track
