--!strict
-- Goal (achievement) logic. Pure: no Roblox APIs. Progress is derived from the SERVER-shaped save table
-- (Stats, Progress, Codex, Caches); the only new state is Achievements.Claimed[goalId] = true.

export type View = { Id: string, Name: string, Description: string, Progress: number, Target: number, Reward: number, Complete: boolean, Claimed: boolean }

local Achievements = {}

local function count(t: { [any]: any }?): number
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

-- Current value of a stat, from a save-data table.
function Achievements.Value(data: any, stat: string): number
	if stat == "TotalPops" then
		return data.Stats.TotalPops
	elseif stat == "BestChain" then
		return data.Stats.BestChain
	elseif stat == "SeamsCleared" then
		return data.Stats.SeamsCleared
	elseif stat == "TotalShards" then
		return data.Stats.TotalShards
	elseif stat == "BestDepth" then
		return data.Stats.BestDepth
	elseif stat == "ExpeditionsWon" then
		return data.Stats.ExpeditionsWon
	elseif stat == "LurkersSlain" then
		return data.Stats.LurkersSlain
	elseif stat == "BossesSlain" then
		return data.Stats.BossesSlain
	elseif stat == "Strata" then
		return data.Progress.StrataUnlocked
	elseif stat == "Codex" then
		return count(data.Codex.Discovered)
	elseif stat == "Prismatic" then
		return count(data.Codex.Mutated)
	elseif stat == "Caches" then
		return count(data.Caches)
	end
	return 0
end

local function find(cfg: any, id: any): any?
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

function Achievements.Find(cfg: any, id: any): any?
	return find(cfg, id)
end

function Achievements.CanClaim(data: any, cfg: any, id: any): boolean
	local def = find(cfg, id)
	if def == nil or data.Achievements.Claimed[def.Id] == true then
		return false
	end
	return Achievements.Value(data, def.Stat) >= def.Target
end

-- Goals that are complete (or already claimed) but not yet in `seen`; marks them seen. Call once when a player joins and
-- ignore the result, so old completions are never announced, then again after gameplay events to announce new ones.
function Achievements.NewlyComplete(data: any, cfg: any, seen: { [string]: boolean }): { any }
	local out = {}
	for _, def in cfg.Defs do
		if not seen[def.Id] and (data.Achievements.Claimed[def.Id] == true or Achievements.Value(data, def.Stat) >= def.Target) then
			seen[def.Id] = true
			table.insert(out, def)
		end
	end
	return out
end

-- One row per goal, in config order, for the client.
function Achievements.View(data: any, cfg: any): { View }
	local out: { View } = {}
	for _, def in cfg.Defs do
		local value = Achievements.Value(data, def.Stat)
		table.insert(out, {
			Id = def.Id,
			Name = def.Name,
			Description = def.Description,
			Progress = math.min(value, def.Target),
			Target = def.Target,
			Reward = def.Reward,
			Complete = value >= def.Target,
			Claimed = data.Achievements.Claimed[def.Id] == true,
		})
	end
	return out
end

return Achievements
