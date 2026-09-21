--!strict
-- Weekly challenge templates: same shape and recording kinds as Config/Dailies.luau, but a week long (Monday 00:00 UTC
-- to the next Monday), with much larger targets and rewards. Three distinct challenges per week, rising by slot.
-- Kinds must be ones the server records: Pops, Chain, Seams, Shards, Tiers, Volleys, Slays, Critical. A test enforces that every weekly
-- target exceeds the matching daily target.
export type Template = {
	Id: string,
	Kind: string,
	Targets: { number },
	Text: string, -- %d is replaced by the target
}

return {
	Templates = {
		{ Id = "Pops", Kind = "Pops", Targets = { 400, 900, 2000 }, Text = "Pop %d crystals this week" },
		{ Id = "Chain", Kind = "Chain", Targets = { 18, 28, 40 }, Text = "Reach a chain of %d pops" },
		{ Id = "Seams", Kind = "Seams", Targets = { 6, 14, 30 }, Text = "Clear %d seams this week" },
		{ Id = "Shards", Kind = "Shards", Targets = { 3000, 9000, 25000 }, Text = "Earn %d shards from blasting this week" },
		{ Id = "Tiers", Kind = "Tiers", Targets = { 5, 12, 25 }, Text = "Land %d chains of 10+ pops this week" },
		{ Id = "Volleys", Kind = "Volleys", Targets = { 20, 45, 90 }, Text = "Detonate %d volleys this week" },
		{ Id = "Slays", Kind = "Slays", Targets = { 12, 28, 60 }, Text = "Slay %d Lurkers this week" },
		{ Id = "Critical", Kind = "Critical", Targets = { 5, 12, 25 }, Text = "Trigger Critical Mass %d times this week" },
	} :: { Template },
	SlotCount = 3,
	SlotRewards = { 3000, 7000, 15000 },
	TierPops = 10,
}
