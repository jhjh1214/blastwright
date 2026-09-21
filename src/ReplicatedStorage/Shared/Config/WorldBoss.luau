--!strict
-- The Crystal Colossus: a server-wide boss that appears in the hub for a few minutes every half hour. Every normal volley any
-- player fires while it is up damages it (bigger chains hit much harder), and everyone who contributed shares the payout.
-- All numbers are placeholders for the balance pass (docs/BALANCE_BACKLOG.md).
return {
	Name = "Crystal Colossus",
	CycleSeconds = 1800, -- a new appearance every 30 minutes, aligned to the clock so every server agrees
	ActiveSeconds = 420, -- it stays 7 minutes
	BaseHP = 500,
	HPPerPlayer = 350,
	MinPlayers = 3, -- HP never scales below this many players
	ChainBonusPer = 20, -- damage = pops * (1 + pops / ChainBonusPer)
	-- Payout: needs at least MinDamage dealt to count as a participant. Shards scale with areas unlocked.
	MinDamage = 20,
	Rewards = {
		Participant = { { Kind = "Shards", Amount = 1500, Scaled = true } },
		Defeated = { { Kind = "Shards", Amount = 2500, Scaled = true } }, -- extra when the Colossus falls in time
		Top = { { Kind = "Tokens", Token = "Revive", Count = 1 }, { Kind = "Shards", Amount = 2500, Scaled = true } }, -- top 3 contributors
	},
	TopCount = 3,
}
