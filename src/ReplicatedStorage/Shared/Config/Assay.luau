--!strict
-- Assay Office: every crystal kind keeps its own pop count; each count milestone can be claimed once for shards.
-- Reaching Master with every kind earns a title. Numbers are placeholders for the balance pass.
return {
	Tiers = {
		{ Id = "Apprentice", Pops = 50, Reward = 400 },
		{ Id = "Journeyman", Pops = 250, Reward = 1200 },
		{ Id = "Master", Pops = 1000, Reward = 3500 },
		{ Id = "Grandmaster", Pops = 4000, Reward = 10000 },
	},
	TitleTier = 3, -- index of the tier every kind must reach for the title
	Title = "Master Assayer",
}
