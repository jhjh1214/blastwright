--!strict
-- Rig upgrades. Costs has one entry per level. Effects are applied in server Game.luau / client Preview.luau.
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
		Costs = { 150, 500, 1500 },
		PerLevel = 1,
	},
	BlastRadius = {
		Name = "Fat Fuse",
		Description = "Blasting Caps reach 0.5 cells further.",
		Costs = { 250, 800, 2500 },
		PerLevel = 0.5,
	},
	Momentum = {
		Name = "Momentum Coil",
		Description = "A charge is refunded at a shorter chain (10 > 8 > 6).",
		Costs = { 600, 2000 },
		PerLevel = 2,
	},
	Seismograph = {
		Name = "Seismograph",
		Description = "Preview the full chain, not just the direct hits.",
		Costs = { 900 },
		PerLevel = 1,
	},
}

return {
	Defs = Defs,
	Order = { "ExtraCharge", "BlastRadius", "Momentum", "Seismograph" },
}
