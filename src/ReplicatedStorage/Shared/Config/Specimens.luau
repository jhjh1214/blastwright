--!strict
-- Specimens: cut and polished crystals that drop while you blast. Every crystal kind comes in six grades, so the Specimen
-- Cabinet (Codex tab) has one slot per kind and grade to fill. Big chains find better grades; a pity counter guarantees
-- Epic and Legendary finds eventually; a duplicate turns into shards ("dust"). Completing the cabinet earns titles.
-- All numbers are placeholders for the balance pass (docs/BALANCE_BACKLOG.md).
export type Rarity = { Id: string, Name: string, Weight: number, Dust: number, Color: { number } }

return {
	-- Lowest to highest. Weight = share of drops before luck; the top grades are very rare.
	Rarities = {
		{ Id = "Common", Name = "Rough", Weight = 600, Dust = 40, Color = { 190, 196, 210 } },
		{ Id = "Uncommon", Name = "Polished", Weight = 250, Dust = 120, Color = { 90, 210, 120 } },
		{ Id = "Rare", Name = "Faceted", Weight = 100, Dust = 400, Color = { 70, 150, 255 } },
		{ Id = "Epic", Name = "Flawless", Weight = 36, Dust = 1500, Color = { 190, 90, 255 } },
		{ Id = "Legendary", Name = "Radiant", Weight = 12, Dust = 6000, Color = { 255, 190, 40 } },
		{ Id = "Mythic", Name = "Celestial", Weight = 2, Dust = 25000, Color = { 255, 90, 170 } },
	} :: { Rarity },
	-- Chance that a volley drops a specimen: Base + pops * PerPop, at most MaxChance.
	Base = 0.01,
	PerPop = 0.004,
	MaxChance = 0.25,
	-- Chain size makes better grades likelier: a grade's weight is multiplied by (1 + luck * ChainLuck * pops / 10) for each step
	-- above Common (step 1 for Uncommon ... 5 for Mythic), so a 30-pop chain leans hard toward rare grades.
	ChainLuck = 0.12,
	-- Pity: after this many drops without an Epic or better, the next drop is at least Epic; after LegendaryPity without a
	-- Legendary or better, at least Legendary.
	EpicPity = 25,
	LegendaryPity = 90,
	-- Collection milestones (number of different specimens found): reached once each, paid automatically.
	Milestones = {
		{ Found = 7, Title = "Rockhound", Shards = 2000 },
		{ Found = 15, Title = "Gem Cutter", Shards = 8000 },
		{ Found = 28, Title = "Lapidarist", Shards = 30000 },
		{ Found = 42, Title = "Grand Curator", Shards = 120000 },
	},
}
