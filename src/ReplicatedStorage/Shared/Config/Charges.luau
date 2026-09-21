--!strict
-- Charge (blast) types. Shape drives ChainSim targeting; the optional fields below are the "shape extras" that the trait
-- tree (Config/Traits.luau, Shared/Loadout.luau) upgrades per charge type:
--   Radius (Radius/Ring), Range (Column/Cross arms), Width (extra lanes each side), Diagonal (Cross also fires diagonally),
--   Inner (Ring hole: skips cells this close), DirectMult (bonus for the crystals this charge hits directly).
export type ChargeDef = {
	Name: string,
	Description: string,
	Shape: string, -- Radius | Ring | Column | Cross
	Radius: number?,
	Range: number?,
	Width: number?,
	Diagonal: boolean?,
	Inner: number?,
	DirectMult: number?,
	UnlockCost: number?, -- nil = owned from the start
	Role: string, -- one line for the loadout screen: what it is good at
}

local Defs: { [string]: ChargeDef } = {
	Basic = {
		Name = "Blasting Cap",
		Description = "A round blast. Hits everything within 1.5 cells.",
		Role = "All-rounder: cheap, safe, and good at starting a chain in a cluster.",
		Shape = "Radius",
		Radius = 1.5,
	},
	Shaft = {
		Name = "Bore Charge",
		Description = "Drills the whole column, 4 cells each way. Upgrade it into a wide trench or a piercing lance.",
		Role = "Line breaker: runs down a lane and lights everything on it.",
		Shape = "Column",
		Range = 4,
		UnlockCost = 12000,
	},
	Cross = {
		Name = "Cross Charge",
		Description = "Fires along the row and column through it, 4 cells each way. Upgrade it into a star or a heavy cross.",
		Role = "Long reach: sets off far-apart crystals in two lines at once.",
		Shape = "Cross",
		Range = 4,
		UnlockCost = 60000,
	},
	Shock = {
		Name = "Shockwave Charge",
		Description = "A ripple that skips the middle: it hits a ring 1 to 2.5 cells away, so it jumps over what is right next to it.",
		Role = "Jumper: leaves the middle for a follow-up and reaches around obstacles.",
		Shape = "Ring",
		Radius = 2.5,
		Inner = 1,
		UnlockCost = 120000,
	},
}

return {
	Defs = Defs,
	Order = { "Basic", "Shaft", "Cross", "Shock" },
}
