--!strict
-- Global gameplay tuning. Pure data: no Roblox types, so it can be loaded by the Luau CLI tests.
return {
	GridSize = 9,
	CellSize = 5, -- studs
	SlotSpacing = 70, -- studs between player caverns along X

	BaseCharges = 4, -- charges per seam before upgrades
	MaxVolleyCharges = 8, -- hard cap on charges in one Detonate call

	-- Chain timing (seconds)
	StepPerCell = 0.07,
	VolatileDelay = 0.10,
	PrismDelay = 0.06,

	MomentumPops = 10, -- chain length that refunds a charge (Momentum Coil lowers this)
	MutationChance = 0.04,
	MutationValueMult = 3,

	ClearBonusRate = 0.25,
	ClearBonusMinFraction = 0.5, -- fraction of valuable crystals popped to earn a clear bonus
	SeamRegenDelay = 3,

	-- Ascending by Pops. Bonus is a fraction added to the volley total.
	ChainTiers = {
		{ Name = "Rumble", Pops = 5, Bonus = 0.10 },
		{ Name = "Cascade", Pops = 10, Bonus = 0.25 },
		{ Name = "Avalanche", Pops = 20, Bonus = 0.50 },
		{ Name = "Cataclysm", Pops = 35, Bonus = 1.00 },
	},
}
