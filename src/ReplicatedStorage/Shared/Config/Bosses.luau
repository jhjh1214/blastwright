--!strict
-- Chain power (how good chains make combat stronger) and the bosses. Numbers are placeholders for the balance pass.
return {
	Power = {
		-- Ascending by Pops. Multiplies the damage of THAT volley against monsters and bosses.
		Tiers = {
			{ Name = "Strong", Pops = 6, Damage = 1.25 },
			{ Name = "Overcharge", Pops = 10, Damage = 1.5 },
			{ Name = "Critical", Pops = 15, Damage = 2 },
		},
		CriticalPops = 15, -- a chain this long starts CRITICAL MASS
		CriticalVolleys = 2, -- Critical Mass lasts for this many following volleys
		CriticalDamage = 1.5, -- extra damage multiplier while it lasts
		CriticalPayout = 1.25, -- extra shard multiplier while it lasts
	},

	-- Expedition floors that are boss fights (the first arrives early: a few floors in).
	BossFloors = { [4] = "Titan", [8] = "Titan" },

	Defs = {
		Titan = {
			Name = "Crystal Titan",
			Description = "A colossus grown into the mine. Break its armor nodes, then out-chain it.",
			MaxHP = 30,
			Bounty = 6000, -- shards added to the haul when it falls
			Core = { X = 5, Z = 5 }, -- the 3x3 body in the middle of the grid; charges must reach it
			Nodes = 4, -- armor nodes (crystals) that must be popped in phase 1
			ArmorBreakDamage = 6,
			Direct = { Basic = 4, Shaft = 5, Cross = 5 }, -- per charge whose blast reaches the core
			Splash = 1, -- per crystal popped near the core ...
			SplashCap = 6, -- ... up to this many
			PopsPerBonus = 4, -- +1 damage per this many pops in the chain
			-- The phase changes when HP falls to these fractions.
			AttackEnd = 0.65,
			WeakEnd = 0.35,
			FinisherAt = 0.15,
			Weak = { Count = 2, MinDist = 4, One = 8, Both = 24, PopsPerMiss = 6 }, -- weak-point phase damage
			Finisher = { Pops = 12, Tries = 3, HealOnFail = 4 }, -- one big chain (or Critical Mass) ends it
			Dodge = { Cooldown = 2 }, -- volleys before the dodge is ready again
			AttackEvery = 2, -- the attack phase marks a line every this many turns (enrage: every turn)
			CutPops = 3, -- popping this many crystals on the marked cells cuts the attack (no damage, no dodge used)
			EnrageLines = 2, -- telegraphed attack lines in the enrage phase
			PhaseRefund = 1, -- charges refunded when a phase is broken

			-- Real-time attacks (Shared/BossRT.luau): the boss winds up attacks on a clock, telegraphs them on the grid, and each
			-- is answered by the crystal system (see docs/MONSTERS.md).
			RT = {
				FirstAttackDelay = 3,
				Interval = { Attack = 6.5, Weak = 5.5, Enrage = 4, Finisher = 5 }, -- seconds between attack wind-ups
				MaxThreats = { Attack = 1, Weak = 1, Enrage = 2, Finisher = 1 }, -- attacks in the air at once
				Attacks = {
					Attack = { "Slam" },
					Weak = { "Slam", "Meteor" },
					Enrage = { "Slam", "Meteor", "Corruption" },
					Finisher = { "Slam", "Corruption" },
				},
				Slam = { Delay = 2.6 },
				Meteor = { Delay = 3.2, Zones = 3 },
				Corruption = { Delay = 4.5, Marks = 4 },
				ShieldSeconds = 1.2, -- Dodge: how long the shield lasts
				DodgeCooldown = 7, -- seconds until Dodge is ready again
			},
		},
	},
}
