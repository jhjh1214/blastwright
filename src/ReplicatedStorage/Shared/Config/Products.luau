--!strict
-- Monetization catalogue. Every Id is nil on purpose: IDs only exist after the developer creates the product
-- in the Roblox Creator Dashboard (see docs/MONETIZATION.md and docs/MANUAL_ACTIONS.md), then pastes them here.
-- While an Id is nil the shop shows the item as "not for sale yet" and nothing else changes.
-- Never invent an ID.
export type DeveloperProduct = { Id: number?, Name: string, Description: string, Amount: number }
export type Gamepass = { Id: number?, Name: string, Description: string }

return {
	-- Consumables (Developer Products). Amount is shards per stratum unlocked, so a pack stays worth buying later.
	DeveloperProducts = {
		ShardPouch = { Id = nil, Name = "Shard Pouch", Description = "A small pouch of shards.", Amount = 500 },
		ShardSatchel = { Id = nil, Name = "Shard Satchel", Description = "A satchel of shards.", Amount = 2500 },
		ShardChest = { Id = nil, Name = "Shard Chest", Description = "A heavy chest of shards.", Amount = 8000 },
		ShardVault = { Id = nil, Name = "Shard Vault", Description = "A whole vault of shards.", Amount = 30000 },
	} :: { [string]: DeveloperProduct },
	DeveloperProductOrder = { "ShardPouch", "ShardSatchel", "ShardChest", "ShardVault" },

	-- Permanent perks (Gamepasses). Free players get the whole game; these speed things up.
	Gamepasses = {
		DoubleShards = { Id = nil, Name = "2x Shards", Description = "Permanently doubles the shards you earn from blasting." },
		PrismaticLuck = { Id = nil, Name = "Prismatic Luck", Description = "Doubles the chance that crystals spawn Prismatic (worth 3x)." },
	} :: { [string]: Gamepass },
	GamepassOrder = { "DoubleShards", "PrismaticLuck" },
}
