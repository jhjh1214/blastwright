--!strict
-- Monetization catalogue. Every Id is nil on purpose: IDs only exist after the developer creates the product
-- in the Roblox Creator Dashboard (see docs/MONETIZATION.md and docs/MANUAL_ACTIONS.md), then pastes them here.
-- While an Id is nil the shop shows the item as "not for sale yet" and nothing else changes.
-- Never invent an ID.
export type DeveloperProduct = { Id: number?, Name: string, Description: string, Amount: number }
export type Gamepass = { Id: number?, Name: string, Description: string }
export type CosmeticProduct = { Id: number?, Name: string, Description: string, Cosmetic: string }
-- A general offer: a list of Grants (see Shared/Grants.luau). Tier and PriceHint are for the shop layout and for the
-- developer when creating the product: the real price is whatever is set in the Creator Dashboard (never read by code).
export type Offer = { Id: number?, Name: string, Description: string, Category: string, Tier: string, PriceHint: number, Grants: { { [string]: any } } }

return {
	-- Consumables (Developer Products). Amount is shards per stratum unlocked, so a pack stays worth buying later.
	DeveloperProducts = {
		ShardPouch = { Id = nil, Name = "Shard Pouch", Description = "A small pouch of shards.", Amount = 2500 },
		ShardSatchel = { Id = nil, Name = "Shard Satchel", Description = "A satchel of shards.", Amount = 12500 },
		ShardChest = { Id = nil, Name = "Shard Chest", Description = "A heavy chest of shards.", Amount = 40000 },
		ShardVault = { Id = nil, Name = "Shard Vault", Description = "A whole vault of shards.", Amount = 150000 },
	} :: { [string]: DeveloperProduct },
	DeveloperProductOrder = { "ShardPouch", "ShardSatchel", "ShardChest", "ShardVault" },

	-- One-off cosmetic unlocks (Developer Products that grant a Shop style from Config/Cosmetics.luau). The smallest tier.
	CosmeticProducts = {
		NeonPinkStyle = { Id = nil, Name = "Neon Pink Blasts", Description = "A hot pink blast color for your charges.", Cosmetic = "NeonPink" },
		VoidStyle = { Id = nil, Name = "Void Blasts", Description = "Deep violet blasts that seem to swallow the light.", Cosmetic = "Void" },
		ToxicStyle = { Id = nil, Name = "Toxic Blasts", Description = "Acid green blasts.", Cosmetic = "Toxic" },
		GoldenStyle = { Id = nil, Name = "Golden Blasts", Description = "Pure gold blasts for a proper flex.", Cosmetic = "Golden" },
	} :: { [string]: CosmeticProduct },
	CosmeticProductOrder = { "NeonPinkStyle", "VoidStyle", "ToxicStyle", "GoldenStyle" },

	-- Permanent perks (Gamepasses). Free players get the whole game; these speed things up.
	Gamepasses = {
		DoubleShards = { Id = nil, Name = "2x Shards", Description = "Permanently doubles the shards you earn from blasting." },
		PrismaticLuck = { Id = nil, Name = "Prismatic Luck", Description = "Doubles the chance that crystals spawn Prismatic (worth 3x)." },
		BlastwrightPlus = { Id = nil, Name = "Blastwright Plus", Description = "The Blastwright Plus title and a free supply drop every day (3 emergency charges and a revive token). Supports the game; no power, nothing locked." },
	} :: { [string]: Gamepass },
	GamepassOrder = { "DoubleShards", "PrismaticLuck", "BlastwrightPlus" },

	-- The product ladder. Small consumables first, then cosmetics and bundles; nothing here gates core play.
	-- Tiers: Tiny (5-25 Robux), Small (49-99), Medium (149-299), Large (399-799), Premium (999+).
	Offers = {
		EmergencyCharge = { Id = nil, Name = "Emergency Charges", Description = "3 spare charges you can use any time you are running dry.", Category = "Support", Tier = "Tiny", PriceHint = 15,
			Grants = { { Kind = "Tokens", Token = "Charge", Count = 3 } } },
		ShardBoost = { Id = nil, Name = "2x Shards (15 min)", Description = "Double shards from blasting for 15 minutes. Stacks up to 2 hours.", Category = "Boosts", Tier = "Small", PriceHint = 49,
			Grants = { { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 900 } } },
		LuckBoost = { Id = nil, Name = "2x Prismatic Luck (15 min)", Description = "Twice as many Prismatic crystals for 15 minutes.", Category = "Boosts", Tier = "Small", PriceHint = 49,
			Grants = { { Kind = "Boost", Boost = "Luck", Mult = 2, Seconds = 900 } } },
		ReviveToken = { Id = nil, Name = "Expedition Revive", Description = "Continue a collapsed Expedition floor instead of losing your haul.", Category = "Support", Tier = "Small", PriceHint = 49,
			Grants = { { Kind = "Tokens", Token = "Revive", Count = 1 } } },
		StarterBlast = { Id = nil, Name = "Starter Blast", Description = "Shards, a boost and an emergency stock to kick things off.", Category = "Bundles", Tier = "Small", PriceHint = 99,
			Grants = { { Kind = "Shards", Amount = 5000, Scaled = true }, { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 900 }, { Kind = "Tokens", Token = "Charge", Count = 3 } } },
		ExpeditionKit = { Id = nil, Name = "Expedition Kit", Description = "3 revives, 5 emergency charges and a 30 minute shard boost.", Category = "Bundles", Tier = "Medium", PriceHint = 199,
			Grants = { { Kind = "Tokens", Token = "Revive", Count = 3 }, { Kind = "Tokens", Token = "Charge", Count = 5 }, { Kind = "Boost", Boost = "Shards", Mult = 2, Seconds = 1800 } } },
		CelestialFinisher = { Id = nil, Name = "Celestial Finish", Description = "Your boss kills end in a blue-white celestial FINAL BLAST.", Category = "Finishers", Tier = "Medium", PriceHint = 249,
			Grants = { { Kind = "Finisher", Id = "Celestial" } } },
		InfernoFinisher = { Id = nil, Name = "Inferno Finish", Description = "Your boss kills end in a roaring red inferno.", Category = "Finishers", Tier = "Medium", PriceHint = 249,
			Grants = { { Kind = "Finisher", Id = "Inferno" } } },
		BossHunter = { Id = nil, Name = "Boss Hunter Pack", Description = "Void finisher, the Boss Hunter title, 5 revives and a pile of shards.", Category = "Bundles", Tier = "Large", PriceHint = 499,
			Grants = { { Kind = "Finisher", Id = "Void" }, { Kind = "Title", Title = "Boss Hunter" }, { Kind = "Tokens", Token = "Revive", Count = 5 }, { Kind = "Shards", Amount = 15000, Scaled = true } } },
		UltimateBlastwright = { Id = nil, Name = "Ultimate Blastwright", Description = "Every finisher, Void and Toxic blasts, an exclusive title, revives, emergency charges and a huge shard pile.", Category = "Bundles", Tier = "Premium", PriceHint = 1499,
			Grants = { { Kind = "Finisher", Id = "Celestial" }, { Kind = "Finisher", Id = "Inferno" }, { Kind = "Finisher", Id = "Void" }, { Kind = "Cosmetic", Id = "Void" }, { Kind = "Cosmetic", Id = "Toxic" }, { Kind = "Title", Title = "Ultimate Blastwright" }, { Kind = "Tokens", Token = "Revive", Count = 10 }, { Kind = "Tokens", Token = "Charge", Count = 20 }, { Kind = "Shards", Amount = 60000, Scaled = true } } },
	} :: { [string]: Offer },
	OfferOrder = { "EmergencyCharge", "ShardBoost", "LuckBoost", "ReviveToken", "StarterBlast", "ExpeditionKit", "CelestialFinisher", "InfernoFinisher", "BossHunter", "UltimateBlastwright" },
	TierOrder = { "Tiny", "Small", "Medium", "Large", "Premium" },

	-- Monthly subscription (Roblox Subscriptions). SubscriptionId stays nil until the developer creates it.
	Club = {
		SubscriptionId = nil :: string?,
		Name = "Blastwright Club",
		Description = "Every month: a shard allotment and the Club Member title, plus a badge of support for the game.",
		MonthlyShards = 25000,
		Title = "Club Member",
	},
}
