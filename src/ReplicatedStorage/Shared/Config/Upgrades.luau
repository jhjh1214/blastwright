--!strict
-- Rig upgrades (every player can buy all of them; the per-charge trait tree in Config/Traits.luau is where builds diverge).
-- Costs has one entry per level. Effects are applied in server Game.luau / client Preview.luau + Playback.luau.
-- Prices are meant to be reached over hours (docs/BALANCE_BACKLOG.md).
export type UpgradeDef = {
	Name: string,
	Description: string,
	Costs: { number },
	PerLevel: number,
}

local Defs: { [string]: UpgradeDef } = {
	ExtraCharge = {
		Name = "Deep Satchel",
		Description = "+1 charge every seam.",
		Costs = { 3000, 12000, 40000 },
		PerLevel = 1,
	},
	BlastRadius = {
		Name = "Fat Fuse",
		Description = "Blasting Caps reach 0.5 cells further.",
		Costs = { 5000, 20000, 60000 },
		PerLevel = 0.5,
	},
	Momentum = {
		Name = "Momentum Coil",
		Description = "A charge is refunded at a shorter chain (10 > 8 > 6).",
		Costs = { 12000, 45000 },
		PerLevel = 2,
	},
	Seismograph = {
		Name = "Seismograph",
		Description = "Preview the full chain, not just the direct hits.",
		Costs = { 20000 },
		PerLevel = 1,
	},
	Plating = {
		Name = "Reinforced Plating",
		Description = "+1 rig heart in Lurker and boss fights.",
		Costs = { 15000, 50000 },
		PerLevel = 1,
	},
	Scope = {
		Name = "Weak Point Scope",
		Description = "+15% damage to Lurkers and bosses.",
		Costs = { 18000, 55000, 140000 },
		PerLevel = 0.15,
	},
	Capacitor = {
		Name = "Overcharge Capacitor",
		Description = "Critical Mass starts 2 pops sooner.",
		Costs = { 40000, 120000 },
		PerLevel = 2,
	},
	Lens = {
		Name = "Prospector's Lens",
		Description = "+15% chance for crystals to spawn Prismatic.",
		Costs = { 12000, 36000, 100000 },
		PerLevel = 0.15,
	},
}

return {
	Defs = Defs,
	Order = { "ExtraCharge", "BlastRadius", "Momentum", "Seismograph", "Plating", "Scope", "Capacitor", "Lens" },
}
