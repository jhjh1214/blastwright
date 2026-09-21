--!strict
-- The free daily reward: log in and claim once per UTC day. Consecutive days build a streak; the reward follows a 7-day cycle
-- (day 7 is the big one). Miss a day and the streak restarts at day 1 (Blastwright Plus members keep it through ONE missed day).
-- Numbers are placeholders for the balance pass.
return {
	Days = {
		{ { Kind = "Shards", Amount = 1000, Scaled = true } },
		{ { Kind = "Tokens", Token = "Charge", Count = 2 } },
		{ { Kind = "Shards", Amount = 2000, Scaled = true } },
		{ { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 900 } },
		{ { Kind = "Shards", Amount = 3500, Scaled = true }, { Kind = "Tokens", Token = "Revive", Count = 1 } },
		{ { Kind = "Boost", Boost = "Luck", Mult = 2, Seconds = 900 } },
		{ { Kind = "Shards", Amount = 8000, Scaled = true }, { Kind = "Tokens", Token = "Revive", Count = 2 }, { Kind = "Tokens", Token = "Charge", Count = 5 } },
	},
}
