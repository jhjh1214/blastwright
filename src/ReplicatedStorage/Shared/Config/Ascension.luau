--!strict
-- Ascension: opt-in Expedition difficulty tiers. Winning an Expedition at your highest unlocked tier unlocks the next one and
-- earns that tier's title. Each tier ADDS its rules on top of the tiers below it and pays a bigger Expedition haul, so a
-- veteran can keep pushing the same eight floors for harder, better-paid runs. Choosing a lower tier is always allowed.
-- Fields per tier (all optional): LurkerHP and BossHP multiply monster health, ChargeDelta changes the starting charges,
-- HeartsDelta changes rig hearts, ClearBonus raises the share of a floor you must clear to survive with no charges,
-- RewardMult multiplies the banked haul. Numbers are placeholders for the balance pass.
export type Tier = { Name: string, Description: string, Title: string, LurkerHP: number?, BossHP: number?, ChargeDelta: number?, HeartsDelta: number?, ClearBonus: number?, RewardMult: number }

return {
	MinCharges = 2, -- starting charges never drop below this
	Tiers = {
		{ Name = "Thick Hide", Description = "Lurkers have 25% more health.", Title = "Ascendant I", LurkerHP = 1.25, RewardMult = 1.15 },
		{ Name = "Lean Rig", Description = "One fewer starting charge.", Title = "Ascendant II", ChargeDelta = -1, RewardMult = 1.15 },
		{ Name = "Ironclad Bosses", Description = "Bosses have 30% more health.", Title = "Ascendant III", BossHP = 1.3, RewardMult = 1.2 },
		{ Name = "Frail Rig", Description = "One fewer rig heart.", Title = "Ascendant IV", HeartsDelta = -1, RewardMult = 1.2 },
		{ Name = "Crumbling Mine", Description = "You must clear 15% more of a floor to survive without charges; Lurkers +25% and bosses +20% health.", Title = "Ascendant V", ClearBonus = 0.15, LurkerHP = 1.25, BossHP = 1.2, RewardMult = 1.25 },
	} :: { Tier },
}
