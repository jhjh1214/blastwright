--!strict
-- Expeditions: an optional roguelite dive. A run is Floors grids in a row; charges carry over, and between floors the
-- player picks one of three cards (a Route plus a Relic) or banks the haul and leaves. Reaching the end pays a bonus;
-- a collapse (too little cleared with no charges left) keeps only SalvageFraction of the haul.
-- Relic Modifiers feed ChainSim (AmplifierMult, UnstableShield, VolatileRadiusBonus, RelayValueMult, ValueMult) or the
-- run itself (MomentumPopsDelta, MutationChanceMult, ExtraCharges). Every descent offers each route exactly once.
export type Route = { Name: string, Description: string, ChargeDelta: number?, Refill: boolean?, ValueMult: number? }
export type Relic = { Name: string, Description: string, Modifiers: { [string]: any } }

return {
	Floors = 8,
	ClearToAdvance = 0.5, -- fraction of valuable crystals cleared that lets you survive a floor with no charges left
	SalvageFraction = 0.4, -- share of the haul kept after a collapse
	DepthBonusPerFloor = 0.15, -- banking pays this much extra per floor cleared
	VictoryBonus = 1.5, -- extra multiplier for clearing the final floor

	Routes = {
		Steady = { Name = "Steady Vein", Description = "A normal floor. +1 charge.", ChargeDelta = 1, ValueMult = 1 },
		Rich = { Name = "Rich Vein", Description = "Payouts x2 on this floor, but -1 charge.", ChargeDelta = -1, ValueMult = 2 },
		Rest = { Name = "Rest Stop", Description = "Refill your charges to full, then a normal floor.", Refill = true, ValueMult = 1 },
	} :: { [string]: Route },

	Relics = {
		ResonantCore = { Name = "Resonant Core", Description = "Resonite adds double to your multiplier.", Modifiers = { AmplifierMult = 2 } },
		SteadyHands = { Name = "Steady Hands", Description = "Dreadgeodes no longer halve your multiplier.", Modifiers = { UnstableShield = true } },
		WideBursts = { Name = "Wide Bursts", Description = "Kindlequartz blasts reach half a cell further.", Modifiers = { VolatileRadiusBonus = 0.5 } },
		EchoChamber = { Name = "Echo Chamber", Description = "Echostones are worth 3x.", Modifiers = { RelayValueMult = 3 } },
		MomentumCharm = { Name = "Momentum Charm", Description = "A charge is refunded 3 pops sooner.", Modifiers = { MomentumPopsDelta = -3 } },
		DeepPockets = { Name = "Deep Pockets", Description = "+1 charge now, kept for the rest of the run.", Modifiers = { ExtraCharges = 1 } },
		Prospector = { Name = "Prospector", Description = "All crystals are worth 1.25x.", Modifiers = { ValueMult = 1.25 } },
		LuckyPrisms = { Name = "Lucky Prisms", Description = "Crystals are 3x as likely to be Prismatic.", Modifiers = { MutationChanceMult = 3 } },
	} :: { [string]: Relic },
}
