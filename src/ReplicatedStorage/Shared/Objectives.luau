--!strict
-- What should the player do next? Pure decision logic (no Roblox APIs) so it can be unit-tested.
-- The client's Guide module turns the result into an objective card, a world marker and arrows.
-- data is the server's Sync snapshot; cfg = { Strata, Upgrades (defs), World, Tuning }.

export type Target = { X: number, Z: number }
export type Objective = {
	Id: string,
	Text: string,
	Target: Target?,
	TargetLabel: string?,
	Highlight: string?, -- name of a HUD button to pulse ("Forge")
}

local Objectives = {}

local BEGINNER_POPS = 40 -- in-blast hints stop once the player has popped this many crystals
local EXPEDITION_HINT_POPS = 30 -- the Expedition suggestion starts once the player knows the basics

local function commas(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function count(t: { [any]: any }?): number
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

-- Where a site's blast station stands (matches Geometry.Station, kept here so this file stays Roblox-free).
local function station(site: any, cfg: any): Target
	return { X = site.X, Z = site.Z - (cfg.Tuning.GridSize * cfg.Tuning.CellSize) / 2 - 7 }
end

-- Nearest site of the given stratum to (px, pz).
function Objectives.NearestSite(cfg: any, px: number, pz: number, stratum: number): any?
	local best, bestD = nil, math.huge
	for _, site in cfg.World.Sites do
		if site.Stratum == stratum then
			local d = (site.X - px) ^ 2 + (site.Z - pz) ^ 2
			if d < bestD then
				best, bestD = site, d
			end
		end
	end
	return best
end

function Objectives.Roam(data: any, px: number, pz: number, cfg: any): Objective
	local stats = data.Stats or {}
	local pops = stats.TotalPops or 0
	local shards = data.Shards or 0
	local unlocked = data.StrataUnlocked or 1

	if pops == 0 then
		local site = Objectives.NearestSite(cfg, px, pz, 1)
		return {
			Id = "GoBlast",
			Text = "Walk to a glowing blast pad and use its station to start blasting.",
			Target = site and station(site, cfg) or nil,
			TargetLabel = "Blast pad",
		}
	end

	for _, list in { data.Dailies or {}, data.Weeklies or {} } do
		for _, challenge in list do
			if challenge.Progress >= challenge.Target and not challenge.Claimed then
				return { Id = "ClaimDaily", Text = "A challenge is complete! Open the Menu to claim your reward.", Highlight = "Forge" }
			end
		end
	end

	for _, goal in data.Goals or {} do
		if goal.Complete and not goal.Claimed then
			return { Id = "ClaimGoal", Text = "A goal is complete! Open the Menu to claim your reward.", Highlight = "Forge" }
		end
	end

	local levels, cheapest = 0, math.huge
	for _, lvl in data.Upgrades or {} do
		levels += lvl
	end
	for _, def in cfg.Upgrades do
		cheapest = math.min(cheapest, def.Costs[1])
	end
	if levels == 0 and shards >= cheapest then
		return { Id = "FirstUpgrade", Text = "You can afford an upgrade! Open the Forge.", Highlight = "Forge" }
	end

	local nextStratum: any = cfg.Strata[unlocked + 1]
	-- The game past plain blasting: once the basics are known, point at Expeditions, then at the first boss. (An affordable
	-- area unlock still comes first: it is the bigger step.)
	if pops >= EXPEDITION_HINT_POPS and not (nextStratum and shards >= nextStratum.Cost) then
		local depth = stats.BestDepth or 0
		local site = Objectives.NearestSite(cfg, px, pz, 1)
		if depth == 0 then
			return {
				Id = "TryExpedition",
				Text = "Ready for a challenge? At a blast pad, HOLD F for an Expedition: monsters, relics and a boss.",
				Target = site and station(site, cfg) or nil,
				TargetLabel = "Blast pad",
			}
		elseif (stats.BossesSlain or 0) == 0 then
			return {
				Id = "FaceTitan",
				Text = depth < 4 and ("Dive deeper: reach floor 4 of an Expedition (best so far: %d) to face the Crystal Titan."):format(depth) or "You have reached the Crystal Titan! Beat it on floor 4 of an Expedition.",
				Target = site and station(site, cfg) or nil,
				TargetLabel = "Blast pad",
			}
		end
	end
	if nextStratum then
		if shards >= nextStratum.Cost then
			return {
				Id = "UnlockArea",
				Text = ("Unlock %s in the Forge (%s shards)."):format(nextStratum.Name, commas(nextStratum.Cost)),
				Highlight = "Forge",
			}
		end
		local site = Objectives.NearestSite(cfg, px, pz, unlocked)
		return {
			Id = "Earn",
			Text = ("Earn %s more shards to unlock %s."):format(commas(nextStratum.Cost - shards), tostring(nextStratum.Name)),
			Target = site and station(site, cfg) or nil,
			TargetLabel = "Blast pad",
		}
	end

	return {
		Id = "Explore",
		Text = ("Explore off the roads for hidden geode caches (%d/%d)."):format(count(data.Caches), #cfg.World.Caches),
	}
end

-- In-blast hint, or nil once the player is experienced.
function Objectives.Blast(data: any, placed: number): Objective?
	if data.Monster then
		return { Id = "Fight", Text = ("A %s! Aim charges so their blast covers it (see its health bar). Chains near it hurt it too."):format(tostring(data.Monster.Name)) }
	end
	local pops = (data.Stats or {}).TotalPops or 0
	if pops >= BEGINNER_POPS then
		return nil
	end
	if placed == 0 then
		return { Id = "Plant", Text = "Tap the grid to plant a charge." }
	end
	return { Id = "Detonate", Text = "Press DETONATE (or Space) to set it off." }
end

return Objectives
