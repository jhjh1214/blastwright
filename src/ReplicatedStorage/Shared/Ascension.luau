--!strict
-- Ascension logic (opt-in Expedition difficulty). Pure (no Roblox APIs). State (save data `Ascension`):
-- { Unlocked = highest tier the player may pick (0 = none yet), Selected = the tier used for the next Expedition }.
local Ascension = {}

function Ascension.Default()
	return { Unlocked = 0, Selected = 0 }
end

function Ascension.MaxTier(cfg: any): number
	return #cfg.Tiers
end

-- Choose the tier for the next Expedition: any whole number from 0 (normal) up to the highest unlocked.
function Ascension.Select(state: any, level: any, cfg: any): boolean
	if type(level) ~= "number" or level ~= math.floor(level) or level < 0 or level > state.Unlocked or level > #cfg.Tiers then
		return false
	end
	state.Selected = level
	return true
end

-- The combined rules of a tier: every tier from 1 up to `level` applies.
function Ascension.Effects(level: number, cfg: any)
	local fx = { LurkerHP = 1, BossHP = 1, ChargeDelta = 0, HeartsDelta = 0, ClearBonus = 0, RewardMult = 1 }
	for i = 1, math.min(math.max(0, math.floor(level)), #cfg.Tiers) do
		local t = cfg.Tiers[i]
		fx.LurkerHP *= t.LurkerHP or 1
		fx.BossHP *= t.BossHP or 1
		fx.ChargeDelta += t.ChargeDelta or 0
		fx.HeartsDelta += t.HeartsDelta or 0
		fx.ClearBonus += t.ClearBonus or 0
		fx.RewardMult *= t.RewardMult
	end
	return fx
end

-- Starting charges after the tier's change, never below the minimum.
function Ascension.StartCharges(base: number, level: number, cfg: any): number
	return math.max(cfg.MinCharges, base + Ascension.Effects(level, cfg).ChargeDelta)
end

-- An Expedition at `level` was won. Unlocks the next tier when it was played at the highest unlocked one (and the tier
-- exists). Returns { Title = the tier's title (level >= 1), Unlocked = the newly unlocked tier or nil }.
function Ascension.OnWin(state: any, level: number, cfg: any): { Title: string?, Unlocked: number? }
	local result: { Title: string?, Unlocked: number? } = {}
	if level >= 1 and level <= #cfg.Tiers then
		result.Title = cfg.Tiers[level].Title
	end
	if level == state.Unlocked and state.Unlocked < #cfg.Tiers then
		state.Unlocked += 1
		result.Unlocked = state.Unlocked
	elseif level == 0 and state.Unlocked == 0 then
		state.Unlocked = 1 -- the first win at normal difficulty opens Ascension 1
		result.Unlocked = 1
	end
	return result
end

return Ascension
