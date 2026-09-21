--!strict
-- Charge (blast) types. Shape drives ChainSim targeting.
export type ChargeDef = {
	Name: string,
	Description: string,
	Shape: string, -- Radius | Column | Cross
	Radius: number?,
	Range: number?,
	UnlockCost: number?, -- nil = owned from the start
}

local Defs: { [string]: ChargeDef } = {
	Basic = {
		Name = "Blasting Cap",
		Description = "A round blast. Hits everything within 1.5 cells.",
		Shape = "Radius",
		Radius = 1.5,
	},
	Shaft = {
		Name = "Shaft Charge",
		Description = "A vertical blast down the whole column, 4 cells each way.",
		Shape = "Column",
		Range = 4,
		UnlockCost = 2000,
	},
	Cross = {
		Name = "Cross Charge",
		Description = "Blasts the whole row and column through it, 3 cells each way.",
		Shape = "Cross",
		Range = 3,
		UnlockCost = 15000,
	},
}

return {
	Defs = Defs,
	Order = { "Basic", "Shaft", "Cross" },
}
