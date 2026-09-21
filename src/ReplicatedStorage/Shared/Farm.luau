--!strict
-- Crystal Farm logic. Pure: no Roblox APIs; `now` is a Unix time passed in. Record: { Level = n, LastCollect = unixTime }.
local Farm = {}

local function levelDef(farm: any, cfg: any)
	if type(farm.Level) ~= "number" or farm.Level % 1 ~= 0 then
		return nil
	end
	return cfg.Levels[farm.Level]
end

-- Shards waiting in the store. Never negative, never more than CapHours of production.
function Farm.Pending(farm: any, now: number, cfg: any): number
	local def = levelDef(farm, cfg)
	local last = farm.LastCollect
	if not def or type(last) ~= "number" or last ~= last or now ~= now or now <= last then
		return 0
	end
	local hours = math.min((now - last) / 3600, cfg.CapHours)
	return math.floor(def.PerHour * hours)
end

-- Take everything in the store; the timer restarts. Returns the amount.
function Farm.Collect(farm: any, now: number, cfg: any): number
	local amount = Farm.Pending(farm, now, cfg)
	farm.LastCollect = now
	return amount
end

-- Buy the next level with `shards`. Pays out the store at the OLD rate first, then charges the cost.
-- Returns (true, paidOut) or (false, reason). Changes nothing on failure.
function Farm.Upgrade(farm: any, now: number, shards: number, cfg: any): (boolean, any)
	local nextDef = cfg.Levels[(farm.Level or 0) + 1]
	if not levelDef(farm, cfg) or not nextDef then
		return false, "max"
	end
	if shards < nextDef.Cost then
		return false, "cost"
	end
	local paid = Farm.Collect(farm, now, cfg)
	farm.Level += 1
	return true, paid
end

return Farm
