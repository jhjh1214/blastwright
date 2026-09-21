--!strict
-- Expeditions: an optional roguelite dive. A run is Floors rooms in a row; charges carry over, and between rooms the
-- player picks one of three cards (a Route = how risky, a Room = what the next floor is, and a Relic = a rule-changing
-- pickup) or banks the haul and leaves. Reaching the end pays a bonus; a collapse (too little cleared with no charges
-- left, or a knocked-out rig) keeps only SalvageFraction of the haul.
-- Relic Modifiers feed ChainSim (AmplifierMult, UnstableShield, VolatileRadiusBonus, RelayValueMult, ValueMult), the run
-- (MomentumPopsDelta, MutationChanceMult, ExtraCharges, HeartsBonus) or combat (DamageMult, LastStandMult, KillRefund,
-- CriticalPopsDelta, HeartOnCritical, BountyMult, MonsterHPMult). Every descent offers each route exactly once.
export type Route = { Name: string, Description: string, ChargeDelta: number?, Refill: boolean?, ValueMult: number? }
export type Relic = { Name: string, Family: string, Description: string, Modifiers: { [string]: any } }
export type Room = {
	Name: string,
	Description: string,
	Weight: number,
	MinFloor: number,
	Lurker: boolean?, -- a Lurker is already awake when the floor starts
	HPMult: number?, -- scales that Lurker's health
	BountyMult: number?,
	RelicReward: boolean?, -- killing the Lurker grants a relic
	NoLurker: boolean?, -- nothing hides in this floor
	ValueMult: number?,
	MutationMult: number?,
	Chaos: boolean?, -- a random Chaos event is rolled when you choose it
}
export type ChaosEvent = { Name: string, Description: string, ValueMult: number?, ChargeDelta: number?, MutationMult: number?, Lurker: boolean?, BountyMult: number? }

return {
	Floors = 8,
	ClearToAdvance = 0.5, -- fraction of valuable crystals cleared that lets you survive a floor with no charges left
	SalvageFraction = 0.4, -- share of the haul kept after a collapse
	DepthBonusPerFloor = 0.15, -- banking pays this much extra per floor cleared
	VictoryBonus = 1.5, -- extra multiplier for clearing the final floor
	BossFloors = { [4] = true, [8] = true }, -- must match Config/Bosses.BossFloors (a test checks it)

	Routes = {
		Steady = { Name = "Safe Path", Description = "A normal floor. +1 charge.", ChargeDelta = 1, ValueMult = 1 },
		Rich = { Name = "Greed Path", Description = "Payouts x2 on this floor, but -1 charge.", ChargeDelta = -1, ValueMult = 2 },
		Rest = { Name = "Rest Stop", Description = "Refill your charges to full, then a normal floor.", Refill = true, ValueMult = 1 },
	} :: { [string]: Route },

	-- What the next floor is. Weighted draw, no repeats within one set of cards.
	Rooms = {
		Mining = { Name = "Mining Vein", Description = "A plain seam. Blast for shards.", Weight = 4, MinFloor = 1 },
		Combat = { Name = "Lurker Nest", Description = "A Lurker is already awake. Kill it for a bounty.", Weight = 3, MinFloor = 2, Lurker = true },
		Elite = { Name = "Elite Lurker", Description = "A tougher Lurker: double bounty and a guaranteed relic.", Weight = 2, MinFloor = 3, Lurker = true, HPMult = 1.75, BountyMult = 2, RelicReward = true },
		Treasure = { Name = "Treasure Vault", Description = "Payouts x2 and rare crystals 3x likelier. Nothing hides here.", Weight = 2, MinFloor = 2, NoLurker = true, ValueMult = 2, MutationMult = 3 },
		Chaos = { Name = "Chaos Rift", Description = "Something strange happens. Big upside, big risk.", Weight = 1, MinFloor = 3, Chaos = true },
	} :: { [string]: Room },

	ChaosEvents = {
		Frenzy = { Name = "Crystal Frenzy", Description = "Payouts x3, but you lose 2 charges.", ValueMult = 3, ChargeDelta = -2 },
		Storm = { Name = "Prism Storm", Description = "Rare crystals are 10x likelier.", MutationMult = 10 },
		Bloodrush = { Name = "Blood Rush", Description = "A Lurker is awake and its bounty is tripled, payouts x1.5.", Lurker = true, BountyMult = 3, ValueMult = 1.5 },
	} :: { [string]: ChaosEvent },

	Relics = {
		-- Echo: chains and relays
		ResonantCore = { Name = "Resonant Core", Family = "Echo", Description = "Resonite adds double to your multiplier.", Modifiers = { AmplifierMult = 2 } },
		EchoChamber = { Name = "Echo Chamber", Family = "Echo", Description = "Echostones are worth 3x.", Modifiers = { RelayValueMult = 3 } },
		-- Explosion: blasts and damage
		WideBursts = { Name = "Wide Bursts", Family = "Explosion", Description = "Kindlequartz blasts reach half a cell further.", Modifiers = { VolatileRadiusBonus = 0.5 } },
		ShockwaveCore = { Name = "Shockwave Core", Family = "Explosion", Description = "All damage to Lurkers and bosses +30%.", Modifiers = { DamageMult = 1.3 } },
		SteadyHands = { Name = "Steady Hands", Family = "Explosion", Description = "Dreadgeodes no longer halve your multiplier.", Modifiers = { UnstableShield = true } },
		-- Combo: long chains
		MomentumCharm = { Name = "Momentum Charm", Family = "Combo", Description = "A charge is refunded 3 pops sooner.", Modifiers = { MomentumPopsDelta = -3 } },
		FocusedLens = { Name = "Focused Lens", Family = "Combo", Description = "CRITICAL MASS starts 4 pops sooner.", Modifiers = { CriticalPopsDelta = -4 } },
		SecondWind = { Name = "Second Wind", Family = "Combo", Description = "Killing a Lurker refunds a charge.", Modifiers = { KillRefund = 1 } },
		-- Risk: dangerous trades
		LastStand = { Name = "Last Stand", Family = "Risk", Description = "At 1 heart your damage is x1.75.", Modifiers = { LastStandMult = 1.75 } },
		BountyHunter = { Name = "Bounty Hunter", Family = "Risk", Description = "Lurker and boss bounties x2, but Lurkers have 25% more health.", Modifiers = { BountyMult = 2, MonsterHPMult = 1.25 } },
		LuckyPrisms = { Name = "Lucky Prisms", Family = "Risk", Description = "Crystals are 3x as likely to be Prismatic.", Modifiers = { MutationChanceMult = 3 } },
		Prospector = { Name = "Prospector", Family = "Risk", Description = "All crystals are worth 1.25x.", Modifiers = { ValueMult = 1.25 } },
		-- Survival
		DeepPockets = { Name = "Deep Pockets", Family = "Explosion", Description = "+1 charge now, kept for the rest of the run.", Modifiers = { ExtraCharges = 1 } },
		IronRig = { Name = "Iron Rig", Family = "Risk", Description = "+1 rig heart for the run.", Modifiers = { HeartsBonus = 1 } },
		VampiricSparks = { Name = "Vampiric Sparks", Family = "Combo", Description = "Starting CRITICAL MASS heals a heart.", Modifiers = { HeartOnCritical = 1 } },
	} :: { [string]: Relic },
}
