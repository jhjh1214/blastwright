--!strict
-- Chain power: better chains hit monsters and bosses harder, and a huge chain starts CRITICAL MASS for a few volleys.
-- Pure: no Roblox APIs. cfg = Config.Bosses.Power. State lives on the server seam as { Left = volleysRemaining }.
local Power = {}

-- The damage multiplier for a chain of `pops` (1 when it is too small to count) and the name of its tier.
function Power.Tier(pops: number, cfg: any): (number, string?)
	local mult, name = 1, nil
	for _, tier in cfg.Tiers do
		if pops >= tier.Pops then
			mult, name = tier.Damage, tier.Name
		end
	end
	return mult, name
end

function Power.StartsCritical(pops: number, cfg: any, popsDelta: number?): boolean
	return pops >= math.max(1, cfg.CriticalPops + (popsDelta or 0))
end

-- Total damage multiplier for a volley: its own tier times Critical Mass if it is already running.
function Power.Multiplier(pops: number, criticalLeft: number, cfg: any): number
	local mult = Power.Tier(pops, cfg)
	if criticalLeft > 0 then
		mult *= cfg.CriticalDamage
	end
	return mult
end

-- Advance Critical Mass after a volley resolved. Returns the new volleys-left and whether it just (re)started.
function Power.Advance(criticalLeft: number, pops: number, cfg: any, popsDelta: number?): (number, boolean)
	if Power.StartsCritical(pops, cfg, popsDelta) then
		return cfg.CriticalVolleys, criticalLeft <= 0
	end
	return math.max(0, criticalLeft - 1), false
end

return Power
