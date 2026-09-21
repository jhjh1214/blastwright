--!strict
-- Goals: permanent milestones that pay shards once. Progress is derived from stats the save already keeps, so
-- adding a goal is a data change. Within one Stat, targets and rewards must rise (tests enforce this and that every
-- target is reachable). Stats: TotalPops, BestChain, SeamsCleared, TotalShards, Caches, Codex, Prismatic, Strata.
export type Def = { Id: string, Name: string, Description: string, Stat: string, Target: number, Reward: number }

local function goal(id: string, name: string, description: string, stat: string, target: number, reward: number): Def
	return { Id = id, Name = name, Description = description, Stat = stat, Target = target, Reward = reward }
end

return {
	Defs = {
		goal("Pops1", "Pebble Popper", "Pop 100 crystals.", "TotalPops", 100, 500),
		goal("Pops2", "Crystal Crusher", "Pop 1,000 crystals.", "TotalPops", 1000, 2500),
		goal("Pops3", "Cavern Cleaner", "Pop 10,000 crystals.", "TotalPops", 10000, 15000),

		goal("Chain1", "Cascade", "Set off a chain of 10 pops.", "BestChain", 10, 750),
		goal("Chain2", "Avalanche", "Set off a chain of 20 pops.", "BestChain", 20, 3000),
		goal("Chain3", "Cataclysm", "Set off a chain of 35 pops.", "BestChain", 35, 12500),

		goal("Seams1", "Seam Starter", "Clear 5 seams.", "SeamsCleared", 5, 1000),
		goal("Seams2", "Seam Sweeper", "Clear 25 seams.", "SeamsCleared", 25, 5000),
		goal("Seams3", "Seam Master", "Clear 100 seams.", "SeamsCleared", 100, 25000),

		goal("Earn1", "First Fortune", "Earn 2,000 shards from blasting.", "TotalShards", 2000, 1000),
		goal("Earn2", "Shard Baron", "Earn 50,000 shards from blasting.", "TotalShards", 50000, 12500),
		goal("Earn3", "Shard Tycoon", "Earn 500,000 shards from blasting.", "TotalShards", 500000, 100000),

		goal("Cache1", "Treasure Spotter", "Crack open 5 geode caches.", "Caches", 5, 1500),
		goal("Cache2", "Treasure Hunter", "Crack open 10 geode caches.", "Caches", 10, 4000),
		goal("Cache3", "Geode Completionist", "Crack open all 22 geode caches.", "Caches", 22, 12500),

		goal("Codex1", "Curious Miner", "Discover 3 kinds of crystal.", "Codex", 3, 750),
		goal("Codex2", "Crystal Scholar", "Discover every kind of crystal.", "Codex", 7, 5000),

		goal("Prism1", "Lucky Find", "Find a Prismatic crystal.", "Prismatic", 1, 1500),
		goal("Prism2", "Prismatic Collector", "Find Prismatic versions of 3 kinds.", "Prismatic", 3, 4500),
		goal("Prism3", "Prismatic Master", "Find Prismatic versions of 5 kinds.", "Prismatic", 5, 15000),

		goal("Area1", "Going Deeper", "Unlock the second mine area.", "Strata", 2, 2500),
		goal("Area2", "Into the Embers", "Unlock the third mine area.", "Strata", 3, 10000),
		goal("Area3", "Echoes Below", "Unlock the fourth mine area.", "Strata", 4, 17500),
	} :: { Def },
}
