--!nonstrict
-- The Goals tab of the menu panel. Split out of UI.luau (no behaviour change): UI.luau builds the row/header helpers and
-- passes them in through `c`; this file only lays out the rows for this tab.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grants = require(Shared.Grants)
local Products = Config.Products
local Remotes = require(Shared.Remotes)
local TrackLogic = require(Shared.Track)

return function(c)
	local d, titleLabel, row, header, commas, THEME = c.d, c.titleLabel, c.row, c.header, c.commas, c.THEME
	local goals = d.Goals or {}
	local claimedCount = 0
	for _, g in goals do
		if g.Claimed then claimedCount += 1 end
	end
	titleLabel.Text = ("Goals  %d/%d"):format(claimedCount, #goals)
	local order = 0
	-- Blastwright Track: permanent 30-level reward track. FREE reward on every level, PREMIUM reward with the pass.
	if d.Track then
		local premium = d.Passes and d.Passes.TrackPremium == true
		local level, into, need = TrackLogic.Progress(d.Track.Xp, Config.Track)
		local reached = level - 1
		header(-40, ("Blastwright Track  -  level %d / %d  (no timer, nothing expires)"):format(math.min(reached, Config.Track.MaxLevel), Config.Track.MaxLevel))
		row(-39, ("Next level: %d / %d XP"):format(into, need), "Everything you do earns Track XP: blasting, Lurkers, bosses, Expedition floors, contracts, specimens.", nil, false, nil, nil, { Icon = "▲", Accent = Color3.fromRGB(255, 205, 90), Progress = into / math.max(1, need) })
		local state = { Xp = d.Track.Xp, Claimed = d.Track.Claimed }
		local first = 1
		while first <= reached + 50 and not (TrackLogic.CanClaim(state, first, false, premium, Config.Track) or (premium and TrackLogic.CanClaim(state, first, true, premium, Config.Track))) and first <= reached do
			first += 1
		end
		if first > reached then first = reached + 1 end
		local passDef = Products.Gamepasses.TrackPremium
		for i, entry in TrackLogic.View(state, premium, Config.Track, first, 4) do
			local freeText = entry.FreeClaimed and "Claimed" or (entry.CanFree and "Claim FREE" or "Level " .. entry.Level)
			row(-38 + i * 2, ("Level %d  FREE"):format(entry.Level), Grants.Describe(entry.Free), freeText, entry.CanFree, function()
				Remotes.TrackClaim:FireServer(entry.Level, false)
			end, nil, { Icon = tostring(entry.Level), Accent = Color3.fromRGB(110, 230, 150), Dim = entry.FreeClaimed })
			if entry.Premium then
				local premiumText = entry.PremiumClaimed and "Claimed" or (entry.CanPremium and "Claim" or (premium and ("Level " .. entry.Level) or (passDef.Id and "Get Premium" or "Premium")))
				row(-37 + i * 2, ("Level %d  PREMIUM"):format(entry.Level), Grants.Describe(entry.Premium), premiumText, entry.CanPremium or (not premium and passDef.Id ~= nil and not entry.PremiumClaimed), function()
					if entry.CanPremium then
						Remotes.TrackClaim:FireServer(entry.Level, true)
					elseif not premium and passDef.Id then
						MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, passDef.Id)
					end
				end, THEME.Gold, { Icon = "★", Accent = Color3.fromRGB(255, 205, 90), Dim = entry.PremiumClaimed or not premium })
			end
		end
	end
	-- Ready to claim first, then in progress, then already claimed.
	local function addRows(filter)
		for _, g in goals do
			if filter(g) then
				order += 1
				local btnText = g.Claimed and "Claimed" or (g.Complete and ("Claim  ◆ " .. commas(g.Reward)) or ("%s / %s"):format(commas(g.Progress), commas(g.Target)))
				row(order, g.Name, g.Description .. ("  Reward: ◆ %s"):format(commas(g.Reward)), btnText, g.Complete and not g.Claimed, function()
					if g.Complete and not g.Claimed then Remotes.ClaimGoal:FireServer(g.Id) end
				end, g.Claimed and THEME.Dim or nil, { Progress = g.Progress / math.max(1, g.Target), Icon = g.Claimed and "✓" or "★", Dim = g.Claimed })
			end
		end
	end
	addRows(function(g) return g.Complete and not g.Claimed end)
	addRows(function(g) return not g.Complete end)
	addRows(function(g) return g.Claimed end)
end
