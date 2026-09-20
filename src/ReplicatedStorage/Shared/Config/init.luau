--!strict
-- Aggregates all config modules. `Context` is what ChainSim needs.
local Crystals = require(script.Crystals)
local Charges = require(script.Charges)
local Tuning = require(script.Tuning)

return {
	Crystals = Crystals,
	Charges = Charges,
	Upgrades = require(script.Upgrades),
	Strata = require(script.Strata),
	Rarities = require(script.Rarities),
	World = require(script.World),
	Tuning = Tuning,
	Context = {
		Crystals = Crystals.Defs,
		Charges = Charges.Defs,
		Tuning = Tuning,
	},
}
