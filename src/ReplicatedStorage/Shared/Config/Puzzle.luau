--!strict
-- The Daily Puzzle: one shared grid per day, one volley of Basic charges, scored against a greedy "par".
-- Rewards are placeholders until the balance pass (see docs/BALANCE_BACKLOG.md).
export type Medal = { Name: string, Ratio: number, Reward: number }

return {
	Stratum = 2, -- crystal pool (areas 1-2) so every player faces the same rules regardless of progress
	Charges = 3,
	MutationChance = 0.08,
	StreakBonusPerDay = 0.1, -- +10% reward per consecutive day
	MaxStreakDays = 7,
	-- Ascending. A medal needs score >= Ratio x par, where par is what a greedy solver scores on the same grid.
	Medals = {
		{ Name = "Bronze", Ratio = 0.5, Reward = 1500 },
		{ Name = "Silver", Ratio = 0.8, Reward = 3000 },
		{ Name = "Gold", Ratio = 1.0, Reward = 6000 },
		{ Name = "Perfect", Ratio = 1.25, Reward = 12000 },
	} :: { Medal },
}
