--!strict
-- Live-event schedule. Pure: no Roblox APIs. Given the current Unix time, which events are active, and what do they
-- change? The server applies the effects; the client only shows the banner.

export type Active = { Id: string, Name: string, Description: string, EndsIn: number, Effects: { [string]: number } }

local Events = {}

local SECONDS_PER_DAY = 86400
local SECONDS_PER_HOUR = 3600

-- Monday = 0 ... Sunday = 6, in UTC. The Unix epoch (day 0) was a Thursday, so day 4 is the first Monday.
function Events.DayOfWeek(now: number): number
	return ((now // SECONDS_PER_DAY) + 3) % 7
end

function Events.Active(now: number, cfg: any): { Active }
	local dow = Events.DayOfWeek(now)
	local intoDay = now % SECONDS_PER_DAY
	local dayStart = now - intoDay
	local out: { Active } = {}
	for _, def in cfg.Defs do
		local onToday = false
		for _, w in def.Weekdays do
			if w == dow then
				onToday = true
			end
		end
		if onToday and intoDay >= def.StartHour * SECONDS_PER_HOUR and intoDay < def.EndHour * SECONDS_PER_HOUR then
			table.insert(out, {
				Id = def.Id,
				Name = def.Name,
				Description = def.Description,
				EndsIn = dayStart + def.EndHour * SECONDS_PER_HOUR - now,
				Effects = def.Effects,
			})
		end
	end
	return out
end

-- Rates multiply, charge bonuses add. With nothing active every value is neutral.
function Events.Combine(active: { any }): { MutationMult: number, ShardMult: number, ChargeBonus: number, LurkerMult: number, DamageMult: number, BountyMult: number }
	local result = { MutationMult = 1, ShardMult = 1, ChargeBonus = 0, LurkerMult = 1, DamageMult = 1, BountyMult = 1 }
	for _, e in active do
		local fx = e.Effects
		result.MutationMult *= fx.MutationMult or 1
		result.ShardMult *= fx.ShardMult or 1
		result.ChargeBonus += fx.ChargeBonus or 0
		result.LurkerMult *= fx.LurkerMult or 1
		result.DamageMult *= fx.DamageMult or 1
		result.BountyMult *= fx.BountyMult or 1
	end
	return result
end

return Events
