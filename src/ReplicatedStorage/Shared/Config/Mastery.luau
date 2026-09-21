--!strict
-- Boss mastery: optional skill objectives per boss. Each one completed grants a one-time shard reward and a title the
-- player can wear above their head. Checks are evaluated against the metrics of the fight that just ended.
-- Check kinds: HeartsLostAtMost, VolleysAtMost, FinalPopsAtLeast, EndedWithHearts (exactly N hearts left).
export type Objective = {
	Id: string,
	Boss: string,
	Name: string,
	Description: string,
	Check: string,
	Value: number,
	Title: string,
	Reward: number,
}

local function o(id: string, boss: string, name: string, description: string, check: string, value: number, title: string, reward: number): Objective
	return { Id = id, Boss = boss, Name = name, Description = description, Check = check, Value = value, Title = title, Reward = reward }
end

return {
	Objectives = {
		o("TitanFlawless", "Titan", "Flawless", "Defeat the Crystal Titan without losing a heart.", "HeartsLostAtMost", 0, "Untouchable", 6000),
		o("TitanSwift", "Titan", "Swift Blast", "Defeat the Crystal Titan in 8 volleys or fewer.", "VolleysAtMost", 8, "Speed Blaster", 6000),
		o("TitanBigFinish", "Titan", "Big Finish", "Land the finishing chain with 20 or more pops.", "FinalPopsAtLeast", 20, "Chain Master", 8000),
		o("TitanIronWill", "Titan", "Iron Will", "Defeat the Crystal Titan with exactly 1 heart left.", "EndedWithHearts", 1, "Cataclysm", 10000),
	} :: { Objective },
}
