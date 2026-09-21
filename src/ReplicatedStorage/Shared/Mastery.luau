--!strict
-- Boss mastery and the collection log. Pure: no Roblox APIs. Save records (see Schema):
--   Mastery = { Done = { [objectiveId] = true }, Title = "" }   Collection = { Lurkers = { [kind] = kills }, Bosses = { [kind] = kills }, Relics = { [id] = true } }
-- Only the server calls the mutating functions.
export type Metrics = { HeartsLost: number, Volleys: number, FinalPops: number, HeartsLeft: number }

local Mastery = {}

local function passes(check: string, value: number, m: Metrics): boolean
	if check == "HeartsLostAtMost" then
		return m.HeartsLost <= value
	elseif check == "VolleysAtMost" then
		return m.Volleys <= value
	elseif check == "FinalPopsAtLeast" then
		return m.FinalPops >= value
	elseif check == "EndedWithHearts" then
		return m.HeartsLeft == value
	end
	return false
end

-- Objectives of this boss the fight satisfied that were not already done, in config order.
function Mastery.Evaluate(boss: string, metrics: Metrics, done: { [string]: boolean }, cfg: any): { any }
	local out = {}
	for _, obj in cfg.Objectives do
		if obj.Boss == boss and not done[obj.Id] and passes(obj.Check, obj.Value, metrics) then
			table.insert(out, obj)
		end
	end
	return out
end

-- Mark objectives done. Returns the total shard reward.
function Mastery.Grant(mastery: any, objectives: { any }): number
	local total = 0
	for _, obj in objectives do
		if not mastery.Done[obj.Id] then
			mastery.Done[obj.Id] = true
			total += obj.Reward
		end
	end
	return total
end

-- Titles the player has earned (config order).
function Mastery.Titles(mastery: any, cfg: any): { string }
	local out = {}
	for _, obj in cfg.Objectives do
		if mastery.Done[obj.Id] then
			table.insert(out, obj.Title)
		end
	end
	local extra = {}
	for title, owned in mastery.Extra or {} do -- titles from purchases
		if owned == true then
			table.insert(extra, title)
		end
	end
	table.sort(extra)
	for _, title in extra do
		table.insert(out, title)
	end
	return out
end

-- Wear a title ("" removes it). Only earned titles can be worn. Returns whether it changed.
function Mastery.Equip(mastery: any, title: any, cfg: any): boolean
	if type(title) ~= "string" then
		return false
	end
	if title == "" then
		mastery.Title = ""
		return true
	end
	for _, owned in Mastery.Titles(mastery, cfg) do
		if owned == title then
			mastery.Title = title
			return true
		end
	end
	return false
end

-- Everything the Codex tab shows for mastery.
function Mastery.View(mastery: any, cfg: any)
	local out = {}
	for _, obj in cfg.Objectives do
		table.insert(out, { Id = obj.Id, Boss = obj.Boss, Name = obj.Name, Description = obj.Description, Title = obj.Title, Reward = obj.Reward, Done = mastery.Done[obj.Id] == true })
	end
	return out
end

-- Collection log ---------------------------------------------------------------------------------------------------

function Mastery.RecordLurker(col: any, kind: string)
	col.Lurkers[kind] = (col.Lurkers[kind] or 0) + 1
end

function Mastery.RecordBoss(col: any, kind: string)
	col.Bosses[kind] = (col.Bosses[kind] or 0) + 1
end

function Mastery.RecordRelic(col: any, relicId: string)
	col.Relics[relicId] = true
end

-- Rows for the Codex: every known entry with whether it was found and how many times.
function Mastery.CollectionView(col: any, lurkerCfg: any, bossCfg: any, expeditionCfg: any)
	local lurkers, bosses, relics = {}, {}, {}
	for _, id in lurkerCfg.Order do
		local n = col.Lurkers[id] or 0
		table.insert(lurkers, { Id = id, Name = lurkerCfg.Defs[id].Name, Description = lurkerCfg.Defs[id].Description, Kills = n, Found = n > 0 })
	end
	local bossIds = {}
	for id in bossCfg.Defs do
		table.insert(bossIds, id)
	end
	table.sort(bossIds)
	for _, id in bossIds do
		local n = col.Bosses[id] or 0
		table.insert(bosses, { Id = id, Name = bossCfg.Defs[id].Name, Description = bossCfg.Defs[id].Description, Kills = n, Found = n > 0 })
	end
	local relicIds = {}
	for id in expeditionCfg.Relics do
		table.insert(relicIds, id)
	end
	table.sort(relicIds)
	local foundRelics = 0
	for _, id in relicIds do
		local found = col.Relics[id] == true
		if found then
			foundRelics += 1
		end
		table.insert(relics, { Id = id, Name = expeditionCfg.Relics[id].Name, Family = expeditionCfg.Relics[id].Family, Description = expeditionCfg.Relics[id].Description, Found = found })
	end
	return { Lurkers = lurkers, Bosses = bosses, Relics = relics, RelicsFound = foundRelics, RelicsTotal = #relicIds }
end

return Mastery
