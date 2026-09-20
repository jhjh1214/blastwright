--!strict
-- Cosmetic ownership and equipping. Pure: no Roblox APIs. `data` is the SERVER save table; the client only ever
-- receives the resolved View. Ownership is derived from claimed goals and purchases, so it cannot drift out of sync.

local Cosmetics = {}

function Cosmetics.Find(cfg: any, id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	for _, def in cfg.Defs do
		if def.Id == id then
			return def
		end
	end
	return nil
end

function Cosmetics.IsOwned(data: any, cfg: any, id: any): boolean
	local def = Cosmetics.Find(cfg, id)
	if def == nil then
		return false
	end
	if def.UnlockGoal == nil and not def.Shop then
		return true -- the free default
	end
	if def.UnlockGoal ~= nil and data.Achievements.Claimed[def.UnlockGoal] == true then
		return true
	end
	return data.Cosmetics.Owned[def.Id] == true
end

function Cosmetics.CanEquip(data: any, cfg: any, id: any): boolean
	return Cosmetics.IsOwned(data, cfg, id)
end

-- The style to actually use: the equipped one if it is still valid and owned, else the default.
function Cosmetics.Active(data: any, cfg: any): any
	local id = data.Cosmetics.Equipped.BlastColor
	if Cosmetics.IsOwned(data, cfg, id) then
		return Cosmetics.Find(cfg, id) :: any
	end
	return Cosmetics.Find(cfg, cfg.DefaultId) :: any
end

-- One row per style for the client, including a hint for how to get locked ones.
function Cosmetics.View(data: any, cfg: any, achievementsCfg: any)
	local activeId = Cosmetics.Active(data, cfg).Id
	local out = {}
	for _, def in cfg.Defs do
		local owned = Cosmetics.IsOwned(data, cfg, def.Id)
		local hint = ""
		if not owned then
			if def.UnlockGoal ~= nil then
				local goalName: string? = nil
				for _, goal in achievementsCfg.Defs do
					if goal.Id == def.UnlockGoal then
						goalName = goal.Name
					end
				end
				hint = goalName and ("Claim the goal: " .. goalName) or "Locked"
			elseif def.Shop then
				hint = "Shop item"
			end
		end
		table.insert(out, {
			Id = def.Id,
			Name = def.Name,
			Color = def.Color,
			Owned = owned,
			Equipped = owned and def.Id == activeId,
			Unlock = hint,
		})
	end
	return out
end

return Cosmetics
