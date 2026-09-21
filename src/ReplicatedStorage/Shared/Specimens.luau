--!strict
-- Specimen drops and the collection cabinet. Pure (no Roblox APIs): the server rolls and records, the client only shows.
-- State (save data `Specimens`): { Found = { ["Kind:RarityId"] = count }, Pity = { Epic = n, Legendary = n }, Total = n,
-- Awarded = { [milestoneTitle] = true } }.
local Specimens = {}

function Specimens.Default()
	return { Found = {}, Pity = { Epic = 0, Legendary = 0 }, Total = 0, Awarded = {} }
end

function Specimens.Id(kind: string, rarityId: string): string
	return kind .. ":" .. rarityId
end

local function rarityIndex(cfg: any, id: string): number
	for i, r in cfg.Rarities do
		if r.Id == id then
			return i
		end
	end
	return 1
end

-- Chance that a volley of `pops` drops something (0 for an empty volley).
function Specimens.DropChance(pops: number, cfg: any): number
	if pops ~= pops or pops <= 0 then
		return 0
	end
	return math.min(cfg.MaxChance, cfg.Base + pops * cfg.PerPop)
end

-- Pick a grade. rng() returns 0..1. Better grades gain weight with chain size and luck; pity can force a minimum grade.
function Specimens.RollRarity(rng: () -> number, pops: number, luck: number, pity: any, cfg: any): string
	local floor = 1
	if (pity.Legendary or 0) >= cfg.LegendaryPity then
		floor = rarityIndex(cfg, "Legendary")
	elseif (pity.Epic or 0) >= cfg.EpicPity then
		floor = rarityIndex(cfg, "Epic")
	end
	local boost = math.max(0, luck) * cfg.ChainLuck * math.min(pops, 60) / 10
	local weights, total = {}, 0
	for i, r in cfg.Rarities do
		local w = 0
		if i >= floor then
			w = r.Weight * (1 + boost * (i - 1))
		end
		weights[i] = w
		total += w
	end
	local pick = rng() * total
	for i, w in weights do
		pick -= w
		if pick < 0 then
			return cfg.Rarities[i].Id
		end
	end
	return cfg.Rarities[#cfg.Rarities].Id
end

-- Roll a volley. kinds = the crystal kinds that popped (a specimen is cut from one of them). Returns { Kind, Rarity, Id } or nil.
function Specimens.Roll(rng: () -> number, kinds: { string }, pops: number, luck: number, state: any, cfg: any): { Kind: string, Rarity: string, Id: string }?
	if #kinds == 0 or rng() >= Specimens.DropChance(pops, cfg) then
		return nil
	end
	local kind = kinds[math.floor(rng() * #kinds) + 1]
	local rarity = Specimens.RollRarity(rng, pops, luck, state.Pity, cfg)
	return { Kind = kind, Rarity = rarity, Id = Specimens.Id(kind, rarity) }
end

-- Put a drop in the cabinet. Returns { New, Count, Dust }: Dust is the shards a duplicate is worth (0 for a first find).
-- Also moves the pity counters (a top grade resets them).
function Specimens.Record(state: any, drop: { Kind: string, Rarity: string, Id: string }, cfg: any): { New: boolean, Count: number, Dust: number }
	local before = state.Found[drop.Id] or 0
	state.Found[drop.Id] = before + 1
	state.Total += 1
	local idx = rarityIndex(cfg, drop.Rarity)
	state.Pity.Epic = idx >= rarityIndex(cfg, "Epic") and 0 or (state.Pity.Epic or 0) + 1
	state.Pity.Legendary = idx >= rarityIndex(cfg, "Legendary") and 0 or (state.Pity.Legendary or 0) + 1
	return { New = before == 0, Count = before + 1, Dust = before == 0 and 0 or cfg.Rarities[idx].Dust }
end

-- How many different specimens are in the cabinet.
function Specimens.FoundCount(state: any): number
	local n = 0
	for _, count in state.Found do
		if count > 0 then
			n += 1
		end
	end
	return n
end

-- Milestones reached but not yet paid. Marks them paid so each pays once. Returns the list (in config order).
function Specimens.NewMilestones(state: any, cfg: any): { any }
	local found = Specimens.FoundCount(state)
	local reached = {}
	for _, m in cfg.Milestones do
		if found >= m.Found and not state.Awarded[m.Title] then
			state.Awarded[m.Title] = true
			table.insert(reached, m)
		end
	end
	return reached
end

-- What the cabinet shows per crystal kind: which grades are found (in rarity order) and how many times.
function Specimens.View(state: any, kinds: { string }, cfg: any)
	local list = {}
	for _, kind in kinds do
		local grades, have = {}, 0
		for _, r in cfg.Rarities do
			local count = state.Found[Specimens.Id(kind, r.Id)] or 0
			if count > 0 then
				have += 1
			end
			table.insert(grades, { Rarity = r.Id, Name = r.Name, Count = count })
		end
		table.insert(list, { Kind = kind, Grades = grades, Have = have, Of = #cfg.Rarities })
	end
	return list
end

return Specimens
