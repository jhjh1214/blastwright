--!strict
-- Lurkers: monsters hidden under crystals. Popping their crystal wakes them; they then act once after every volley you
-- fire until you kill them with charges (or they wear you down). Numbers are placeholders for the balance pass.
export type Def = {
	Name: string,
	Description: string,
	HP: number,
	Stratum: number, -- earliest area this kind appears in
	Armor: number?, -- subtracted from each direct hit (never below 1)
	Weak: string?, -- charge kind that does double damage
	Bounty: number,
	Behavior: string, -- Eat | Drain | Smash
	Params: { [string]: number },
}

return {
	Hearts = 3, -- rig hearts per seam (an Expedition carries them between floors)
	Spawn = { BaseChance = 0.10, PerStratum = 0.05, PerFloor = 0.04, Cap = 0.6 }, -- chance a seam hides a Lurker
	Damage = {
		Direct = { Basic = 2, Shaft = 3, Cross = 3 }, -- per charge whose blast covers the Lurker's cell
		Splash = 1, -- per crystal popped next to it ...
		SplashCap = 3, -- ... up to this many per volley
	},
	Defeat = { RepairFraction = 0.15 }, -- share of the seam's earnings lost when the rig is knocked out on a normal seam
	Defs = {
		Gnasher = {
			Name = "Gnasher",
			Description = "Eats the crystals next to it. Kill it before it eats your payout.",
			HP = 6,
			Stratum = 1,
			Bounty = 400,
			Behavior = "Eat",
			Params = { PerTurn = 2 },
		},
		Sapper = {
			Name = "Sapper",
			Description = "Drains one charge from your rig every turn. Weak to Shaft charges.",
			HP = 8,
			Stratum = 2,
			Weak = "Shaft",
			Bounty = 1000,
			Behavior = "Drain",
			Params = { Amount = 1 },
		},
		Brute = {
			Name = "Brute",
			Description = "Armored. Smashes your rig every other turn (watch for the warning). Weak to Cross charges.",
			HP = 14,
			Stratum = 3,
			Armor = 1,
			Weak = "Cross",
			Bounty = 3000,
			Behavior = "Smash",
			Params = { EveryTurns = 2 },
		},
	} :: { [string]: Def },
	Order = { "Gnasher", "Sapper", "Brute" },
}
