--!nonstrict
-- Server-authoritative purchases. Nothing is ever granted because a client said so:
--   * Developer products: MarketplaceService.ProcessReceipt is the only grant path. It is idempotent (a PurchaseId
--     grants once, however often Roblox retries) and only reports PurchaseGranted after the save succeeded.
--   * Gamepasses: ownership is read from Roblox (UserOwnsGamePassAsync) and refreshed by the server-side
--     PromptGamePassPurchaseFinished event.
-- Product ids come from Config/Products.luau and stay nil until the developer creates them; with a nil id the
-- item is simply not for sale and nothing here runs for it.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Data = require(script.Parent.Data)
local Receipts = require(script.Parent.Receipts)
local Grants = require(ReplicatedStorage:WaitForChild("Shared").Grants)

local Products = Config.Products
local Decision = Enum.ProductPurchaseDecision

local Purchases = {}

local owned = {} -- [Player] = { [passKey] = true }
local productIndex = Receipts.ProductIndex(Products.DeveloperProducts)
for id, key in Receipts.ProductIndex(Products.CosmeticProducts) do
	productIndex[id] = key -- shard packs and cosmetic products share one receipt path
end
for id, key in Receipts.ProductIndex(Products.Offers) do
	productIndex[id] = key -- consumables, finishers and bundles too
end
local passIndex = Receipts.ProductIndex(Products.Gamepasses)
local clubActive = {} -- [Player] = true while the Club subscription is active
local hooks = {
	Notify = function(player, text, kind) end,
	OnChanged = function(player) end,
}

function Purchases.Owns(player, key)
	local set = owned[player]
	return set ~= nil and set[key] == true
end

-- Ask Roblox which configured passes the player owns. Safe to call with no passes configured.
function Purchases.LoadPasses(player)
	local set = {}
	for key, def in Products.Gamepasses do
		if def.Id ~= nil then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.Id)
			end)
			if ok and result then
				set[key] = true
			elseif not ok then
				warn(("[Purchases] Could not check pass %s for %s: %s"):format(key, player.Name, tostring(result)))
			end
		end
	end
	owned[player] = set
end

function Purchases.Forget(player)
	owned[player] = nil
	clubActive[player] = nil
end

-- Ask Roblox whether the player has an active Club subscription (false while no subscription id is configured).
function Purchases.RefreshClub(player)
	local id = Products.Club.SubscriptionId
	if id == nil then
		clubActive[player] = nil
		return false
	end
	local ok, status = pcall(function()
		return MarketplaceService:GetUserSubscriptionStatusAsync(player, id)
	end)
	if ok and status and status.IsSubscribed then
		clubActive[player] = true
	else
		clubActive[player] = nil
		if not ok then
			warn(("[Purchases] Could not check the Club subscription for %s: %s"):format(player.Name, tostring(status)))
		end
	end
	return clubActive[player] == true
end

function Purchases.IsClub(player)
	return clubActive[player] == true
end

local function grant(player, data, key)
	local offer = Products.Offers[key]
	if offer then
		local messages = Grants.Apply(data, offer.Grants, os.time(), data.Progress.StrataUnlocked)
		hooks.Notify(player, ("%s: %s"):format(offer.Name, table.concat(messages, ", ")), "Reward")
		return
	end
	local cosmetic = Products.CosmeticProducts[key]
	if cosmetic then
		Receipts.GrantCosmetic(data, cosmetic.Cosmetic)
		hooks.Notify(player, cosmetic.Name .. " unlocked!", "Reward")
		return
	end
	local def = Products.DeveloperProducts[key]
	local amount = Receipts.ShardAmount(def, data.Progress.StrataUnlocked)
	data.Shards += amount
	hooks.Notify(player, ("%s: +%d shards"):format(def.Name, amount), "Reward")
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Decision.NotProcessedYet -- player left; Roblox retries when they rejoin
	end
	local data = Data.Get(player)
	if not data then
		return Decision.NotProcessedYet
	end
	local key = productIndex[info.ProductId]
	if not key then
		warn(("[Purchases] Receipt for unknown product %s"):format(tostring(info.ProductId)))
		return Decision.NotProcessedYet
	end

	local purchaseId = tostring(info.PurchaseId)
	if Receipts.Apply(data.Purchases, purchaseId, os.time()) then
		local ok, err = pcall(grant, player, data, key)
		if not ok then
			Receipts.Revert(data.Purchases, purchaseId)
			warn("[Purchases] Grant failed: " .. tostring(err))
			return Decision.NotProcessedYet
		end
	end

	-- Only tell Roblox it is done once the grant is durably saved. If the save fails we return NotProcessedYet;
	-- the retry finds the id already recorded, skips the grant, and just tries the save again.
	if not Data.Save(player, false) then
		return Decision.NotProcessedYet
	end
	hooks.OnChanged(player)
	return Decision.PurchaseGranted
end

function Purchases.Init(options)
	hooks.Notify = options.Notify or hooks.Notify
	hooks.OnChanged = options.OnChanged or hooks.OnChanged

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local key = passIndex[passId]
		if key then
			owned[player] = owned[player] or {}
			owned[player][key] = true
			hooks.Notify(player, Products.Gamepasses[key].Name .. " unlocked. Thank you!", "Reward")
			hooks.OnChanged(player)
		end
	end)
end

return Purchases
