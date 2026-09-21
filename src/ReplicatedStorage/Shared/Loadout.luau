--!strict
-- The trait tree logic. Pure (no Roblox APIs). State (save data `Traits`): { Owned = { [nodeId] = true } }.
-- `Loadout.Charges` turns the base charge definitions plus a player's owned traits into the definitions that the server's
-- simulation, the combat code and the client's preview ALL use, so what you see is what happens.
local Loadout = {}

function Loadout.Default()
	return { Owned = {} }
end

-- Can this node be bought right now? Returns ok and, when not, a short reason for the UI.
function Loadout.CanBuy(state: any, id: any, cfg: any, unlockedCharges: { [string]: boolean }, shards: number): (boolean, string)
	local node = type(id) == "string" and cfg.Nodes[id] or nil
	if not node then
		return false, "Unknown upgrade."
	end
	if state.Owned[id] then
		return false, "Already owned."
	end
	if not unlockedCharges[node.Branch] then
		return false, "Unlock the charge first."
	end
	if node.Requires and not state.Owned[node.Requires] then
		return false, "Needs " .. cfg.Nodes[node.Requires].Name .. " first."
	end
	if node.Group then
		for otherId, other in cfg.Nodes do
			if otherId ~= id and other.Group == node.Group and state.Owned[otherId] then
				return false, "You chose " .. other.Name .. " instead (respec the branch to switch)."
			end
		end
	end
	if shards < node.Cost then
		return false, "Not enough shards."
	end
	return true, ""
end

-- Buy a node (the caller takes the shards). Returns the cost, or nil if it cannot be bought.
function Loadout.Buy(state: any, id: any, cfg: any, unlockedCharges: { [string]: boolean }, shards: number): number?
	local ok = Loadout.CanBuy(state, id, cfg, unlockedCharges, shards)
	if not ok then
		return nil
	end
	state.Owned[id] = true
	return cfg.Nodes[id].Cost
end

-- Clear every node of one branch. Returns how many were removed (0 = nothing to do, so the caller charges nothing).
function Loadout.Respec(state: any, branch: any, cfg: any): number
	if type(branch) ~= "string" then
		return 0
	end
	local removed = 0
	for id, node in cfg.Nodes do
		if node.Branch == branch and state.Owned[id] then
			state.Owned[id] = nil
			removed += 1
		end
	end
	return removed
end

-- Base definitions + owned traits (+ the rig's blast radius bonus for round blasts) -> definitions for this player.
-- Never mutates the inputs. Nodes are applied in cfg.Order so the result never depends on table iteration order.
function Loadout.Charges(baseDefs: { [string]: any }, state: any, cfg: any, radiusBonus: number?): { [string]: any }
	local out: { [string]: any } = {}
	for id, def in baseDefs do
		local copy = {}
		for k, v in def do
			copy[k] = v
		end
		if copy.Shape == "Radius" and radiusBonus then
			copy.Radius = (copy.Radius or 0) + radiusBonus
		end
		out[id] = copy
	end
	for _, nodeId in cfg.Order do
		local node = cfg.Nodes[nodeId]
		if node and state.Owned[nodeId] then
			local def = out[node.Branch]
			if def then
				local fx = node.Effects
				def.Radius = (def.Radius or 0) + (fx.Radius or 0)
				def.Range = (def.Range or 0) + (fx.Range or 0)
				def.Width = (def.Width or 0) + (fx.Width or 0)
				if def.Shape == "Ring" then
					def.Inner = math.max(0, (def.Inner or 0) + (fx.Inner or 0))
				end
				if fx.Diagonal then
					def.Diagonal = true
				end
				if fx.DirectMult then
					def.DirectMult = (def.DirectMult or 1) + fx.DirectMult
				end
			end
		end
	end
	return out
end

-- What the loadout screen shows for one branch: its nodes in order with their state.
function Loadout.BranchView(state: any, branch: string, cfg: any, unlockedCharges: { [string]: boolean }, shards: number)
	local list = {}
	for _, id in cfg.Order do
		local node = cfg.Nodes[id]
		if node.Branch == branch then
			local ok, reason = Loadout.CanBuy(state, id, cfg, unlockedCharges, shards)
			table.insert(list, { Id = id, Name = node.Name, Description = node.Description, Cost = node.Cost, Tier = node.Tier, Owned = state.Owned[id] == true, CanBuy = ok, Reason = reason })
		end
	end
	return list
end

return Loadout
