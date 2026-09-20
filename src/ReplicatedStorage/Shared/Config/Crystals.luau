--!strict
-- Crystal definitions. Behavior drives ChainSim; Color is {R,G,B} 0-255 (kept Roblox-free for tests).
export type CrystalDef = {
	Name: string,
	Rarity: string,
	Description: string,
	Value: number,
	Behavior: string, -- Inert | Volatile | Amplifier | Prism | Unstable | Delayed
	Params: { [string]: number },
	Color: { number },
	Stratum: number, -- first stratum this can appear in
	Weight: number, -- spawn weight
}

local Defs: { [string]: CrystalDef } = {
	Glimmerstone = {
		Name = "Glimmerstone",
		Rarity = "Common",
		Description = "Plain ore. Pops for shards and does nothing else.",
		Value = 5,
		Behavior = "Inert",
		Params = {},
		Color = { 90, 200, 255 },
		Stratum = 1,
		Weight = 60,
	},
	Kindlequartz = {
		Name = "Kindlequartz",
		Rarity = "Uncommon",
		Description = "Volatile. Bursts and sets off everything around it.",
		Value = 8,
		Behavior = "Volatile",
		Params = { Radius = 1.5 },
		Color = { 255, 140, 50 },
		Stratum = 1,
		Weight = 20,
	},
	Resonite = {
		Name = "Resonite",
		Rarity = "Rare",
		Description = "Amplifier. Every crystal popped after it is worth more.",
		Value = 6,
		Behavior = "Amplifier",
		Params = { MultAdd = 0.5 },
		Color = { 190, 120, 255 },
		Stratum = 1,
		Weight = 8,
	},
	Lensglass = {
		Name = "Lensglass",
		Rarity = "Epic",
		Description = "Prism. Fires a beam along its whole row.",
		Value = 15,
		Behavior = "Prism",
		Params = { Range = 5 },
		Color = { 255, 240, 150 },
		Stratum = 2,
		Weight = 8,
	},
	Dreadgeode = {
		Name = "Dreadgeode",
		Rarity = "Uncommon",
		Description = "Unstable. Worthless, and halves your chain multiplier when it goes.",
		Value = 0,
		Behavior = "Unstable",
		Params = { MultScale = 0.5 },
		Color = { 220, 50, 80 },
		Stratum = 2,
		Weight = 10,
	},
	Slowburn = {
		Name = "Slowburn",
		Rarity = "Rare",
		Description = "Delayed. Lights a fuse when hit and pops a second later, cashing in your full multiplier, then blasts radius 2.",
		Value = 20,
		Behavior = "Delayed",
		Params = { Delay = 1.0, Radius = 2 },
		Color = { 255, 80, 170 },
		Stratum = 3,
		Weight = 8,
	},
}

return {
	Defs = Defs,
	Order = { "Glimmerstone", "Kindlequartz", "Resonite", "Lensglass", "Dreadgeode", "Slowburn" },
}
