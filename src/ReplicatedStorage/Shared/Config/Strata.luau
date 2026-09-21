--!strict
-- Mine strata. Index = stratum number. Crystals unlock by CrystalDef.Stratum. Costs are meant to be reached over hours,
-- not one Expedition (see docs/BALANCE_BACKLOG.md).
return {
	{ Name = "Glimmer Shallows", Cost = 0, Description = "Ore, Kindlequartz and Resonite. Learn to plan a chain." },
	{ Name = "Prism Veins", Cost = 30000, Description = "Adds Lensglass beams and Dreadgeode hazards." },
	{ Name = "Ember Hollows", Cost = 100000, Description = "Adds Slowburn: slow fuses that pop last, so your multiplier peaks first." },
	{ Name = "Echo Caverns", Cost = 300000, Description = "Adds Echostone relays: pop one and every other Echostone goes off, so chains can jump across the grid." },
}
