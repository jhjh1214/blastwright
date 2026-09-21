--!strict
-- The Crystal Farm: a passive income building in the hub. It fills a store over real time (also while offline, up to
-- CapHours) and the player collects it. Costs and rates are placeholders until the balance pass; kept modest so offline
-- income never replaces playing.
export type Level = { PerHour: number, Cost: number } -- Cost = shards to reach this level (level 1 is free)

return {
	CapHours = 6,
	Levels = {
		{ PerHour = 150, Cost = 0 },
		{ PerHour = 350, Cost = 8000 },
		{ PerHour = 700, Cost = 25000 },
		{ PerHour = 1300, Cost = 70000 },
		{ PerHour = 2200, Cost = 180000 },
		{ PerHour = 3500, Cost = 400000 },
	} :: { Level },
}
