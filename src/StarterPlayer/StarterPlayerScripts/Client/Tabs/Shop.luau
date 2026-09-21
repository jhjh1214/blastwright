--!nonstrict
-- The Shop tab of the menu panel. Split out of UI.luau (no behaviour change): UI.luau builds the row/header helpers and
-- passes them in through `c`; this file only lays out the rows for this tab.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Products = Config.Products
local Remotes = require(Shared.Remotes)
local ShopArt = require(script.Parent.Parent.ShopArt)

return function(c)
	local d, titleLabel, header, mk, commas, panel, panelScroll = c.d, c.titleLabel, c.header, c.mk, c.commas, c.panel, c.panelScroll
	titleLabel.Text = "Shop"
	local order = 0
	local artCtx = { Cosmetics = Config.Cosmetics.Defs, Finishers = Config.Finishers.Defs }
	local cols = panel.AbsoluteSize.X >= 460 and 2 or 1

	-- A section: a colour banner and a grid of product cards under it.
	local function section(title)
		order += 1
		header(order, title)
		order += 1
		local grid = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, ZIndex = 11 }, panelScroll)
		mk("UIGridLayout", { CellSize = UDim2.new(1 / cols, cols == 2 and -4 or 0, 0, 238), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
		return grid
	end
	local function priceHint(n)
		return n and ("≈ R$" .. n) or nil
	end
	local function buyPrompt(def)
		return function()
			if def.Id then MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.Id) end
		end
	end

	-- Club (monthly subscription)
	local club = d.Club
	if club then
		local grid = section("Blastwright Club (monthly)")
		local text = not club.Configured and "Not for sale yet" or (club.Active and (club.CanClaim and ("Claim  ◆ " .. commas(club.MonthlyShards)) or "Claimed this month") or "Subscribe")
		ShopArt.Card(grid, {
			Name = Products.Club.Name, Description = Products.Club.Description, Art = ShopArt.Crown(), Tier = "Premium", Badge = "MONTHLY",
			Hint = "monthly", Button = text, Enabled = club.Configured and (not club.Active or club.CanClaim), Order = 1,
			OnClick = function()
				if not club.Configured then return end
				if club.Active and club.CanClaim then
					Remotes.ClubClaim:FireServer()
				elseif not club.Active then
					pcall(function() MarketplaceService:PromptSubscriptionPurchase(Players.LocalPlayer, Products.Club.SubscriptionId) end)
				end
			end,
		})
	end

	local function offerCards(title, category)
		local grid
		local n = 0
		for _, key in Products.OfferOrder do
			local def = Products.Offers[key]
			if def.Category == category then
				if not grid then grid = section(title) end
				n += 1
				local badge = def.Tier == "Premium" and "ULTIMATE" or (def.Tier == "Large" and "HOT" or (def.Category == "Bundles" and "BUNDLE" or nil))
				ShopArt.Card(grid, {
					Name = def.Name, Description = def.Description, Art = ShopArt.FromGrants(def.Grants, artCtx), Tier = def.Tier, Badge = badge,
					Hint = priceHint(def.PriceHint), Button = def.Id and "Buy" or "Not for sale yet", Enabled = def.Id ~= nil, Order = n, OnClick = buyPrompt(def),
				})
			end
		end
	end
	-- Featured: the best-value bundles first, so they are the first thing seen.
	local featured = section("Featured")
	for i, key in { "UltimateBlastwright", "BossHunter", "StarterBlast" } do
		local def = Products.Offers[key]
		if def then
			ShopArt.Card(featured, {
				Name = def.Name, Description = def.Description, Art = ShopArt.FromGrants(def.Grants, artCtx), Tier = def.Tier, Badge = i == 1 and "BEST VALUE" or "BUNDLE",
				Hint = priceHint(def.PriceHint), Button = def.Id and "Buy" or "Not for sale yet", Enabled = def.Id ~= nil, Order = i, OnClick = buyPrompt(def),
			})
		end
	end
	offerCards("Boosts", "Boosts")
	offerCards("Run support", "Support")
	offerCards("Boss finishers (your FINAL BLAST)", "Finishers")
	offerCards("Bundles", "Bundles")

	-- Permanent perks
	local perks = section("Permanent perks")
	local perkArt = { DoubleShards = ShopArt.Boost(2, "forever", Color3.fromRGB(255, 205, 90)), PrismaticLuck = ShopArt.Orb(Color3.fromRGB(255, 110, 230)), TrackPremium = ShopArt.Crown() }
	local perkTier = { DoubleShards = "Large", PrismaticLuck = "Medium", BlastwrightPlus = "Premium", TrackPremium = "Premium" }
	local perkHint = { DoubleShards = 499, PrismaticLuck = 299, BlastwrightPlus = 399, TrackPremium = 599 }
	for i, key in Products.GamepassOrder do
		local def = Products.Gamepasses[key]
		local owned = d.Passes and d.Passes[key]
		ShopArt.Card(perks, {
			Name = def.Name, Description = def.Description, Art = perkArt[key] or ShopArt.Crown(), Tier = perkTier[key] or "Large", Badge = owned and "OWNED" or "FOREVER",
			Hint = priceHint(perkHint[key]), Button = owned and "Owned" or (def.Id and "Buy" or "Not for sale yet"), Enabled = (not owned) and def.Id ~= nil, Order = i,
			OnClick = function()
				if def.Id and not owned then MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, def.Id) end
			end,
		})
	end

	-- Blast colors
	local colors = section("Blast colors")
	local colorTier = { NeonPinkStyle = "Small", VoidStyle = "Medium", ToxicStyle = "Medium", GoldenStyle = "Large" }
	local colorHint = { NeonPinkStyle = 99, VoidStyle = 149, ToxicStyle = 149, GoldenStyle = 399 }
	for i, key in Products.CosmeticProductOrder do
		local def = Products.CosmeticProducts[key]
		local owned = false
		local swatch = Color3.fromRGB(255, 170, 60)
		for _, style in d.Styles or {} do
			if style.Id == def.Cosmetic then
				swatch = Color3.fromRGB(style.Color[1], style.Color[2], style.Color[3])
				if style.Owned then owned = true end
			end
		end
		ShopArt.Card(colors, {
			Name = def.Name, Description = def.Description, Art = ShopArt.Orb(swatch), Tier = colorTier[key] or "Small", Badge = owned and "OWNED" or nil,
			Hint = priceHint(colorHint[key]), Button = owned and "Owned" or (def.Id and "Buy" or "Not for sale yet"), Enabled = (not owned) and def.Id ~= nil, Order = i,
			OnClick = function()
				if def.Id and not owned then MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.Id) end
			end,
		})
	end

	-- Shard packs
	local packs = section("Shard packs (amount x areas unlocked)")
	local packTier = { ShardPouch = "Tiny", ShardSatchel = "Small", ShardChest = "Medium", ShardVault = "Premium" }
	local packHint = { ShardPouch = 49, ShardSatchel = 199, ShardChest = 599, ShardVault = 1999 }
	local packGems = { ShardPouch = 1, ShardSatchel = 2, ShardChest = 3, ShardVault = 5 }
	for i, key in Products.DeveloperProductOrder do
		local def = Products.DeveloperProducts[key]
		ShopArt.Card(packs, {
			Name = ("%s  +%s"):format(def.Name, commas(def.Amount * math.max(1, d.StrataUnlocked))), Description = def.Description,
			Art = ShopArt.Gems(packGems[key] or 2), Tier = packTier[key] or "Small", Badge = key == "ShardVault" and "BEST VALUE" or nil,
			Hint = priceHint(packHint[key]), Button = def.Id and "Buy" or "Not for sale yet", Enabled = def.Id ~= nil, Order = i, OnClick = buyPrompt(def),
		})
	end
end
