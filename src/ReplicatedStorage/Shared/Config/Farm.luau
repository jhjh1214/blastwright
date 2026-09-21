--!strict
-- The Crystal Farm: a passive income building in the hub. It fills a store over real time (also while offline, up to
-- CapHours) and the player collects it. Costs and rates are placeholders until the balance pass.
export type Level = { PerHour: number, Cost: number } -- Cost = shards to reach this level (level 1 is free)

return {
	CapHours = 8,
	Levels = {
		{ PerHour = 300, Cost = 0 },
		{ PerHour = 700, Cost = 4000 },
		{ PerHour = 1500, Cost = 12000 },
		{ PerHour = 3200, Cost = 35000 },
		{ PerHour = 7000, Cost = 100000 },
		{ PerHour = 15000, Cost = 280000 },
	} :: { Level },
}
