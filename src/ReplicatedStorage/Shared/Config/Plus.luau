--!strict
-- Blastwright Plus: a permanent gamepass that is about comfort and recognition, never about power or gating content.
-- Perks: the "Blastwright Plus" title, and a small daily supply drop (support tokens). Every claim is once per UTC day.
return {
	Pass = "BlastwrightPlus", -- key in Config/Products.luau Gamepasses
	Title = "Blastwright Plus",
	DailyGift = {
		{ Kind = "Tokens", Token = "Charge", Count = 3 },
		{ Kind = "Tokens", Token = "Revive", Count = 1 },
	},
}
