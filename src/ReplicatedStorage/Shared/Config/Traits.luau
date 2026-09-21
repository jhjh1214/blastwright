--!strict
-- The trait tree: every charge type has its own branch of upgrades, so players build different loadouts. A branch is
-- Tier 1 (a small boost), then a FORK at Tier 2 (pick ONE of two; nodes with the same Group exclude each other), then a
-- Tier 3 capstone that needs the Tier 2 node you took. Respeccing a branch (Respec cost) clears it so you can take the
-- other path. Effects (all additive, applied to the charge's definition by Shared/Loadout.luau):
--   Radius, Range, Width (extra lanes each side), Diagonal (Cross also fires diagonally), Inner (Ring hole size, may be
--   negative to fill the middle), DirectMult (extra multiplier on the crystals this charge hits directly).
-- A branch is only buyable once its charge is unlocked. Costs are placeholders for the balance pass.
export type Node = {
	Branch: string, -- the charge id this belongs to
	Tier: number,
	Name: string,
	Description: string,
	Cost: number,
	Requires: string?, -- a node of the same branch that must be owned first
	Group: string?, -- nodes sharing a Group are mutually exclusive
	Effects: { [string]: any },
}

return {
	Respec = 5000, -- shards to clear one branch (nothing is refunded)
	BranchOrder = { "Basic", "Shaft", "Cross", "Shock" },
	Nodes = {
		-- Blasting Cap: bigger, then either "hit hard" or "hit wide"
		CapPacked = { Branch = "Basic", Tier = 1, Name = "Packed Charge", Description = "Blast radius +0.5.", Cost = 8000, Effects = { Radius = 0.5 } },
		CapShaped = { Branch = "Basic", Tier = 2, Name = "Shaped Charge", Description = "Crystals the cap hits directly pay 1.5x.", Cost = 30000, Requires = "CapPacked", Group = "CapFork", Effects = { DirectMult = 0.5 } },
		CapWide = { Branch = "Basic", Tier = 2, Name = "Wide Blast", Description = "Blast radius +0.5 more.", Cost = 30000, Requires = "CapPacked", Group = "CapFork", Effects = { Radius = 0.5 } },
		CapDemolition = { Branch = "Basic", Tier = 3, Name = "Demolition Cap", Description = "Direct hits pay another +0.75x.", Cost = 90000, Requires = "CapShaped", Effects = { DirectMult = 0.75 } },
		CapMega = { Branch = "Basic", Tier = 3, Name = "Mega Cap", Description = "Blast radius +0.75.", Cost = 90000, Requires = "CapWide", Effects = { Radius = 0.75 } },

		-- Bore Charge: a lane, then either a piercing rail or a fat trench
		BoreBroad = { Branch = "Shaft", Tier = 1, Name = "Broad Bit", Description = "The bore cuts 3 lanes wide instead of 1.", Cost = 10000, Effects = { Width = 1 } },
		BoreRail = { Branch = "Shaft", Tier = 2, Name = "Rail Head", Description = "Crystals in the bore's lanes pay 1.6x.", Cost = 35000, Requires = "BoreBroad", Group = "BoreFork", Effects = { DirectMult = 0.6 } },
		BoreTrench = { Branch = "Shaft", Tier = 2, Name = "Trench Cutter", Description = "5 lanes wide.", Cost = 35000, Requires = "BoreBroad", Group = "BoreFork", Effects = { Width = 1 } },
		BoreLance = { Branch = "Shaft", Tier = 3, Name = "Deep Lance", Description = "Direct hits pay another +0.9x.", Cost = 100000, Requires = "BoreRail", Effects = { DirectMult = 0.9 } },
		BoreSeismic = { Branch = "Shaft", Tier = 3, Name = "Seismic Bit", Description = "Direct hits pay +0.5x across all 5 lanes.", Cost = 100000, Requires = "BoreTrench", Effects = { DirectMult = 0.5 } },

		-- Cross Charge: heavier arms, then either a diagonal star or a thick cross
		CrossHeavy = { Branch = "Cross", Tier = 1, Name = "Heavy Arms", Description = "Crystals the arms hit directly pay 1.25x.", Cost = 14000, Effects = { DirectMult = 0.25 } },
		CrossStar = { Branch = "Cross", Tier = 2, Name = "Star Burst", Description = "Also fires along the 4 diagonals: an 8-way star.", Cost = 45000, Requires = "CrossHeavy", Group = "CrossFork", Effects = { Diagonal = true } },
		CrossGrand = { Branch = "Cross", Tier = 2, Name = "Grand Cross", Description = "The arms are 3 lanes thick.", Cost = 45000, Requires = "CrossHeavy", Group = "CrossFork", Effects = { Width = 1 } },
		CrossNova = { Branch = "Cross", Tier = 3, Name = "Supernova", Description = "Direct hits pay another +0.6x.", Cost = 120000, Requires = "CrossStar", Effects = { DirectMult = 0.6 } },
		CrossColossus = { Branch = "Cross", Tier = 3, Name = "Colossus Cross", Description = "Direct hits pay another +0.6x.", Cost = 120000, Requires = "CrossGrand", Effects = { DirectMult = 0.6 } },

		-- Shockwave Charge: a wider ripple, then either an echoing ring or a filled core
		ShockTuned = { Branch = "Shock", Tier = 1, Name = "Tuned Coil", Description = "The ripple reaches 0.5 cells further.", Cost = 20000, Effects = { Radius = 0.5 } },
		ShockEcho = { Branch = "Shock", Tier = 2, Name = "Echo Ring", Description = "A thicker ring: reaches 0.5 further and the hole grows by 0.5.", Cost = 60000, Requires = "ShockTuned", Group = "ShockFork", Effects = { Radius = 0.5, Inner = 0.5 } },
		ShockCore = { Branch = "Shock", Tier = 2, Name = "Shock Core", Description = "Fills the hole: it hits the middle too, as a full disc.", Cost = 60000, Requires = "ShockTuned", Group = "ShockFork", Effects = { Inner = -1 } },
		ShockResonant = { Branch = "Shock", Tier = 3, Name = "Resonant Ring", Description = "Direct hits pay 1.75x.", Cost = 150000, Requires = "ShockEcho", Effects = { DirectMult = 0.75 } },
		ShockShatter = { Branch = "Shock", Tier = 3, Name = "Shatter Core", Description = "Reaches 0.5 further and direct hits pay 1.4x.", Cost = 150000, Requires = "ShockCore", Effects = { Radius = 0.5, DirectMult = 0.4 } },
	} :: { [string]: Node },
	-- Display order inside a branch. Must list every node exactly once (a test checks it).
	Order = {
		"CapPacked", "CapShaped", "CapWide", "CapDemolition", "CapMega",
		"BoreBroad", "BoreRail", "BoreTrench", "BoreLance", "BoreSeismic",
		"CrossHeavy", "CrossStar", "CrossGrand", "CrossNova", "CrossColossus",
		"ShockTuned", "ShockEcho", "ShockCore", "ShockResonant", "ShockShatter",
	},
}
