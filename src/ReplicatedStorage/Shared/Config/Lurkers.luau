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
	Behavior: string, -- Eat | Dash | Steal | Drain | Smash
	Params: { [string]: number },
}

return {
	Hearts = 3, -- rig hearts per seam (an Expedition carries them between floors)
	Spawn = { BaseChance = 0.10, PerStratum = 0.05, PerFloor = 0.04, Cap = 0.6, FirstFightChance = 0.6 }, -- chance a seam hides a Lurker (FirstFightChance: before the first kill)
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
			Bounty = 250,
			Behavior = "Eat",
			Params = { PerTurn = 2 },
		},
		Skitter = {
			Name = "Skitter",
			Description = "Fast: it runs two cells a turn to gobble a crystal. Small and fragile: bait it into a blast.",
			HP = 3,
			Stratum = 1,
			Bounty = 150,
			Behavior = "Dash",
			Params = { PerTurn = 1, Steps = 2 },
		},
		Leech = {
			Name = "Leech",
			Description = "Steals 15% of every volley's payout while it lives. Kill it before it drains the haul.",
			HP = 7,
			Stratum = 2,
			Bounty = 500,
			Behavior = "Steal",
			Params = { Fraction = 0.15 },
		},
		Sapper = {
			Name = "Sapper",
			Description = "Drains one charge from your rig every turn. Weak to Shaft charges.",
			HP = 8,
			Stratum = 2,
			Weak = "Shaft",
			Bounty = 600,
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
			Bounty = 1200,
			Behavior = "Smash",
			Params = { EveryTurns = 2 },
		},
	} :: { [string]: Def },
	Order = { "Gnasher", "Skitter", "Leech", "Sapper", "Brute" },
}
