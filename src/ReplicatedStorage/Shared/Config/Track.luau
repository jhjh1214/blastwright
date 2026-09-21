--!strict
-- The Blastwright Track: a permanent 30-level reward track. Everything you do earns Track XP; every level has a FREE reward
-- for everyone and a PREMIUM reward for owners of the Track Premium pass. There is no season timer and nothing expires, so
-- no one is ever rushed, and premium can be bought at any time to collect the premium rewards for levels already reached.
-- After the last level, each further level pays a small free reward. All numbers are placeholders for the balance pass.
export type Level = { Free: { { [string]: any } }, Premium: { { [string]: any } } }

local function shards(n: number): { [string]: any }
	return { Kind = "Shards", Amount = n, Scaled = true }
end
local function tokens(token: string, n: number): { [string]: any }
	return { Kind = "Tokens", Token = token, Count = n }
end
local function boost(kind: string, minutes: number): { [string]: any }
	return { Kind = "Boost", Boost = kind, Mult = 2, Seconds = minutes * 60 }
end

return {
	MaxLevel = 30,
	-- XP needed to go from level L to L+1: Base + Step * (L - 1)
	XpBase = 120,
	XpStep = 30,
	-- Track XP sources (server-side only).
	Xp = {
		VolleyBase = 1, -- per volley
		PerTenPops = 1, -- per 10 pops in the volley (rounded down), max PopsCap
		PopsCap = 8,
		Lurker = 10,
		Boss = 60,
		Floor = 15,
		ExpeditionWin = 100,
		Contract = 40,
		Streak = 25,
		WorldBoss = 50,
		Specimen = { 5, 8, 15, 30, 60, 120 }, -- by grade, Common to Mythic
	},
	BonusPerLevelAfterMax = { { Kind = "Shards", Amount = 1500, Scaled = true } },
	Levels = {
		{ Free = { shards(500) }, Premium = { tokens("Charge", 3) } },
		{ Free = { tokens("Charge", 2) }, Premium = { shards(1500) } },
		{ Free = { shards(800) }, Premium = { boost("Shards", 15) } },
		{ Free = { boost("Shards", 10) }, Premium = { tokens("Revive", 1) } },
		{ Free = { shards(1200) }, Premium = { shards(3000) } },
		{ Free = { tokens("Revive", 1) }, Premium = { boost("Luck", 20) } },
		{ Free = { shards(1500) }, Premium = { tokens("Charge", 5) } },
		{ Free = { boost("Luck", 10) }, Premium = { shards(5000) } },
		{ Free = { shards(2000) }, Premium = { tokens("Revive", 2) } },
		{ Free = { { Kind = "Title", Title = "Track Runner" } }, Premium = { { Kind = "Title", Title = "Track Elite" }, shards(6000) } },
		{ Free = { shards(2500) }, Premium = { boost("Shards", 30) } },
		{ Free = { tokens("Charge", 3) }, Premium = { shards(8000) } },
		{ Free = { shards(3000) }, Premium = { tokens("Revive", 2), tokens("Charge", 5) } },
		{ Free = { boost("Shards", 15) }, Premium = { boost("Luck", 30) } },
		{ Free = { shards(4000) }, Premium = { { Kind = "Finisher", Id = "Celestial" } } },
		{ Free = { tokens("Revive", 1) }, Premium = { shards(12000) } },
		{ Free = { shards(4500) }, Premium = { boost("Shards", 45) } },
		{ Free = { tokens("Charge", 4) }, Premium = { tokens("Revive", 3) } },
		{ Free = { shards(5000) }, Premium = { shards(15000) } },
		{ Free = { boost("Luck", 15) }, Premium = { { Kind = "Cosmetic", Id = "Void" } } },
		{ Free = { shards(6000) }, Premium = { boost("Shards", 60) } },
		{ Free = { tokens("Revive", 2) }, Premium = { shards(20000) } },
		{ Free = { shards(7000) }, Premium = { tokens("Charge", 8), tokens("Revive", 3) } },
		{ Free = { boost("Shards", 20) }, Premium = { boost("Luck", 45) } },
		{ Free = { shards(8000) }, Premium = { { Kind = "Finisher", Id = "Inferno" } } },
		{ Free = { tokens("Charge", 5) }, Premium = { shards(30000) } },
		{ Free = { shards(9000) }, Premium = { tokens("Revive", 4) } },
		{ Free = { boost("Luck", 20) }, Premium = { boost("Shards", 90) } },
		{ Free = { shards(12000) }, Premium = { shards(45000), { Kind = "Cosmetic", Id = "Toxic" } } },
		{ Free = { { Kind = "Title", Title = "Track Master" }, shards(20000) }, Premium = { { Kind = "Title", Title = "Track Legend" }, { Kind = "Finisher", Id = "Void" }, shards(60000) } },
	} :: { Level },
}
