--!strict
-- Daily objective templates. Each day the server picks three distinct templates (seeded by the UTC day number)
-- and assigns them rising difficulty: slot 1 uses Targets[1], slot 2 Targets[2], slot 3 Targets[3].
-- Kind is what gets recorded: Pops (+n), Chain (max), Seams (+1 cleared), Shards (+n from blasting),
-- Tiers (+1 per volley of TierPops+ pops), Volleys (+1 per detonation),
-- Slays (+1 per Lurker slain), Critical (+1 per Critical Mass started).
export type Template = {
	Id: string,
	Kind: string,
	Targets: { number },
	Text: string, -- %d is replaced by the target
}

return {
	Templates = {
		{ Id = "Pops", Kind = "Pops", Targets = { 60, 110, 180 }, Text = "Pop %d crystals" },
		{ Id = "Chain", Kind = "Chain", Targets = { 10, 18, 28 }, Text = "Reach a chain of %d pops" },
		{ Id = "Seams", Kind = "Seams", Targets = { 1, 2, 3 }, Text = "Clear %d seams" },
		{ Id = "Shards", Kind = "Shards", Targets = { 400, 900, 1800 }, Text = "Earn %d shards from blasting" },
		{ Id = "Tiers", Kind = "Tiers", Targets = { 1, 2, 4 }, Text = "Land %d chains of 10+ pops" },
		{ Id = "Volleys", Kind = "Volleys", Targets = { 4, 8, 14 }, Text = "Detonate %d volleys" },
		{ Id = "Slays", Kind = "Slays", Targets = { 2, 4, 7 }, Text = "Slay %d Lurkers" },
		{ Id = "Critical", Kind = "Critical", Targets = { 1, 2, 3 }, Text = "Trigger Critical Mass %d times" },
	} :: { Template },
	SlotCount = 3,
	SlotRewards = { 600, 1250, 2250 }, -- shards by slot (difficulty), independent of which template was drawn
	TierPops = 10,
}
