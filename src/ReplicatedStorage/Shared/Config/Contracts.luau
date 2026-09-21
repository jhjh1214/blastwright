--!strict
-- Notice Board contracts: each day three offers (Easy / Standard / Hard), the same on every server. A player accepts ONE at
-- a time; only progress made after accepting counts. Kinds recorded by the server: Slay (Param = lurker id, +1 per kill),
-- Chain (max pops in one volley), Critical (+1 per Critical Mass), Boss (+1 per boss slain), Floor (deepest Expedition
-- floor cleared, max). Rewards are Grants (Shared/Grants.luau): shards scale with areas unlocked; the higher tiers add tokens.
export type Template = { Id: string, Kind: string, Param: string?, Targets: { number }, Text: string }

return {
	Templates = {
		{ Id = "HuntGnasher", Kind = "Slay", Param = "Gnasher", Targets = { 3, 6, 10 }, Text = "Slay %d Gnashers" },
		{ Id = "HuntSkitter", Kind = "Slay", Param = "Skitter", Targets = { 3, 6, 10 }, Text = "Slay %d Skitters" },
		{ Id = "HuntLeech", Kind = "Slay", Param = "Leech", Targets = { 2, 4, 7 }, Text = "Slay %d Leeches" },
		{ Id = "HuntSapper", Kind = "Slay", Param = "Sapper", Targets = { 2, 4, 7 }, Text = "Slay %d Sappers" },
		{ Id = "HuntBrute", Kind = "Slay", Param = "Brute", Targets = { 1, 2, 4 }, Text = "Slay %d Brutes" },
		{ Id = "BigChain", Kind = "Chain", Targets = { 14, 24, 36 }, Text = "Set off a chain of %d pops" },
		{ Id = "CriticalMass", Kind = "Critical", Targets = { 1, 3, 5 }, Text = "Trigger Critical Mass %d times" },
		{ Id = "BossBounty", Kind = "Boss", Targets = { 1, 2, 3 }, Text = "Defeat %d Expedition bosses" },
		{ Id = "DeepDive", Kind = "Floor", Targets = { 3, 5, 8 }, Text = "Clear floor %d of an Expedition" },
	} :: { Template },
	Tiers = { "Easy", "Standard", "Hard" },
	-- Grants per tier (Shards scaled by areas unlocked).
	Rewards = {
		{ { Kind = "Shards", Amount = 900, Scaled = true } },
		{ { Kind = "Shards", Amount = 2000, Scaled = true }, { Kind = "Tokens", Token = "Charge", Count = 2 } },
		{ { Kind = "Shards", Amount = 4200, Scaled = true }, { Kind = "Tokens", Token = "Revive", Count = 1 } },
	},
}
