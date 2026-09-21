--!nonstrict
-- All HUD and menus, built in code. Touch-first (buttons >= 40px tall) and kept to the screen edges so the
-- middle of the view stays clear: the blast HUD sits in the corners, the roaming HUD along the top.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Products = Config.Products

local AudioManager = require(script.Parent.AudioManager)
local CameraFeedback = require(script.Parent.CameraFeedback)
local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local ShopArt = require(script.Parent.ShopArt)
local Dock = require(script.Parent.Dock)
local StatusDock = require(script.Parent.StatusDock)
local Calm = require(script.Parent.Calm)
local Feed = require(script.Parent.Feed)
local BossHud = require(script.Parent.BossHud)
local Theme = require(script.Parent.Theme)
local Loadout = require(Shared.Loadout)
local TrackLogic = require(Shared.Track)
local Grants = require(Shared.Grants)
local SpecimensLogic = require(Shared.Specimens)
local Reveal = require(script.Parent.Reveal)
local AscensionLogic = require(Shared.Ascension)
local ChainSim = require(Shared.ChainSim)
local Kit = require(script.Parent.Kit)
local Icons = require(script.Parent.Icons)

local UI = {}

local THEME = {
	Bg = Theme.Colors.PanelDark,
	Panel = Theme.Colors.Panel,
	Row = Color3.fromRGB(58, 68, 120),
	Accent = Theme.Colors.Info,
	Gold = Theme.Colors.Premium,
	Hot = Theme.Colors.Action,
	Text = Color3.fromRGB(255, 255, 255),
	Dim = Color3.fromRGB(200, 208, 236),
	Bad = Theme.Colors.Danger,
	Good = Theme.Colors.Success,
}
local FONT = Theme.Font.Display

local function mk(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	mk("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function label(parent, text, size, color, props)
	local p = {
		BackgroundTransparency = 1,
		Font = size >= 18 and Theme.Font.Display or Theme.Font.Body,
		Text = text,
		TextSize = size,
		TextColor3 = color or THEME.Text,
		TextStrokeTransparency = 1,
	}
	for k, v in props or {} do
		if k ~= "NoOutline" then
			p[k] = v
		end
	end
	local l = mk("TextLabel", p, parent)
	if size >= 16 and not (props and props.NoOutline) then
		Kit.Outline(l, size >= 24 and 3 or 2.5)
	end
	return l
end

-- The quick chunky button used all over the menus: thick dark outline, outlined text, light top, and the shared
-- hover / press / release feel (grow, squash, overshoot). Big primary actions use Kit.Button instead.
local function button(parent, text, color, props)
	local p = {
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Font = Theme.Font.Display,
		Text = text,
		TextSize = 18,
		TextColor3 = THEME.Text,
	}
	for k, v in props or {} do
		p[k] = v
	end
	local b = mk("TextButton", p, parent)
	corner(b, 12)
	mk("UIStroke", { Color = Theme.Colors.Outline, Thickness = 3.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, b)
	Kit.Outline(b, 2.5)
	mk("UIGradient", { Color = ColorSequence.new(Theme.Tint(color, 0.26), Theme.Shade(color, 0.08)), Rotation = 90 }, b)
	local sc = mk("UIScale", { Scale = 1 }, b)
	b.MouseEnter:Connect(function() Kit.Tween(sc, Theme.Anim.Hover, { Scale = 1.05 }) end)
	b.MouseLeave:Connect(function() Kit.Tween(sc, Theme.Anim.Release, { Scale = 1 }, Enum.EasingStyle.Back) end)
	b.MouseButton1Down:Connect(function() Kit.Tween(sc, Theme.Anim.Press, { Scale = 0.94 }) end)
	b.MouseButton1Up:Connect(function() Kit.Tween(sc, Theme.Anim.Release, { Scale = 1 }, Enum.EasingStyle.Back) end)
	return b
end

-- Lets code that reads/writes a plain button (.Text, .BackgroundColor3, .Visible) drive a Kit.Button.
local function proxy(obj)
	return setmetatable({}, {
		__newindex = function(_, k, v)
			if k == "Text" then obj.SetText(v) elseif k == "BackgroundColor3" then obj.SetColor(v) elseif k == "Visible" then obj.Root.Visible = v end
		end,
		__index = function(_, k)
			if k == "Visible" then return obj.Root.Visible end
			if k == "Root" then return obj.Root end
			if k == "Face" then return obj.Face end
			return nil
		end,
	})
end

local function commas(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local statusDock
local shardCur
local gui, shardLabel, locationLabel, cacheLabel, objectiveCard, objectiveText, blastHint, seamLabel, chainLabel, previewFrame, previewLabel, infoLabel
local welcomeFrame, detonateStroke
local detonatePulse = false
local settingButtons = {}
local tabButtons = {}
local chargeColumn, panel, panelScroll, detonateButton, dock, bossHud, leftCol, readPanel, panelRule
local roamGroup, blastGroup
local runLabel, runModal, runCards, runTitle, runBank, rigLabel
local bossFrame, bossName, bossFill, bossHint, dodgeButton, criticalLabel
local boostLabel, chargeButton, reviveModal, reviveText, reviveYes, reviveNo, combatLabel
local activeTab = "Forge"
local displayShards = 0
local chargeButtons = {}
local highlighted = nil

-- Callbacks provided by Input
UI.OnDetonate = nil
UI.OnClear = nil
UI.OnLeave = nil

local function fullGroup(name)
	return mk("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
end

function UI.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = mk("ScreenGui", { Name = "BlastwrightUI", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets }, playerGui)

	-- Always visible: shards (top-left) and toasts / tier banner
	shardCur = Kit.Currency(gui, { Name = "Shards", Size = UDim2.fromOffset(196, 52), Position = UDim2.fromOffset(12, 8), Icon = "Gem", Color = Theme.Colors.Premium })
	shardLabel = shardCur.Label

	Feed.Init(gui) -- messages live in their own column on the right; big moments use the banner
	Reveal.Init(gui)

	----------------------------------------------------------- roaming HUD
	roamGroup = fullGroup("Roam")
	locationLabel = label(roamGroup, "", 20, THEME.Text, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(320, 28) })
	-- The area name is a passing banner (fades in on entering an area, then away). Live events and the Server Goal are small
	-- tiles with their own icons and timers in the bottom-right corner (StatusDock), so the middle of the screen stays clear.
	locationLabel.TextTransparency = 1
	statusDock = StatusDock.Build(roamGroup)
	cacheLabel = label(roamGroup, "", 16, THEME.Text, { Position = UDim2.new(0, 16, 0, 66), Size = UDim2.fromOffset(200, 22), TextXAlignment = Enum.TextXAlignment.Left })
	-- Quest card under the shards. Fixed sizes only (no automatic sizing): the height is set from the measured text in
	-- UI.SetObjective, so nothing can collapse or grow by itself.
	objectiveCard = Kit.Card(roamGroup, { Name = "Objective", Color = Theme.Colors.PanelDark, Position = UDim2.new(0, 12, 0, 96), Size = UDim2.fromOffset(230, 80), ZIndex = Theme.Z.Hud })
	objectiveCard.Visible = false
	local tag = mk("Frame", { BackgroundColor3 = Theme.Colors.Warning, Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(112, 24), BorderSizePixel = 0, ZIndex = Theme.Z.Hud + 1 }, objectiveCard)
	corner(tag, 8)
	mk("UIStroke", { Color = Theme.Colors.Outline, Thickness = 3 }, tag)
	mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Theme.Font.Display, Text = "QUEST", TextSize = 15, TextColor3 = Color3.fromRGB(255, 255, 255), ZIndex = Theme.Z.Hud + 2 }, tag)
	objectiveText = mk("TextLabel", { Name = "Text", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 38), Size = UDim2.fromOffset(206, 20), Font = Theme.Font.Body, Text = "", TextSize = 16, TextColor3 = Color3.fromRGB(255, 255, 255), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = Theme.Z.Hud + 2 }, objectiveCard)

	-- A small help button in the corner; every feature has its own button in the dock along the bottom.
	Kit.Button(roamGroup, { Name = "Help", Size = UDim2.fromOffset(54, 60), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Color = Theme.Colors.Codex, Text = "?", TextSize = 34, Depth = 5, Corner = 12, OnClick = function() UI.ShowWelcome(true) end })
	dock = Dock.Build(roamGroup, function() return objectiveCard end, function(name)
		AudioManager.Play("Click")
		if State.PanelOpen and activeTab == name then
			UI.SetPanel(false)
		else
			UI.SetPanel(true, name)
			if name == "Farm" then
				Remotes.FarmAction:FireServer("refresh")
			end
		end
	end)

	----------------------------------------------------------- blast HUD (corners only)
	blastGroup = fullGroup("Blast")
	blastGroup.Visible = false
	local blastScale = mk("UIScale", { Scale = 1 }, blastGroup)
	local function fitBlast()
		local a = gui.AbsoluteSize
		if a.X > 0 and a.Y > 0 then
			local sc = math.clamp(math.min(a.Y / 640, a.X / 860), 0.55, 1)
			blastScale.Scale = sc
			blastGroup.Size = UDim2.fromScale(1 / sc, 1 / sc) -- (the frame grows as the content shrinks, so it still fills the screen)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBlast)
	fitBlast()

	Kit.Button(blastGroup, { Name = "Leave", Size = UDim2.fromOffset(128, 60), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Color = Theme.Colors.Warning, Text = "LEAVE", TextSize = 26, Depth = 5, Corner = 12, OnClick = function() if UI.OnLeave then UI.OnLeave() end end })

	-- Left column: status cards that stack (Critical Mass, run / puzzle, rig hearts and the monster) instead of overlapping.
	leftCol = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 56), Size = UDim2.fromOffset(290, 0), AutomaticSize = Enum.AutomaticSize.Y }, blastGroup)
	mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, leftCol)
	local function card(order, color, props)
		local l = label(leftCol, "", 15, color, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, BackgroundColor3 = Color3.fromRGB(18, 20, 33), BackgroundTransparency = 0.12, LayoutOrder = order, Visible = false, Font = Enum.Font.BuilderSansBold })
		corner(l, 10)
		mk("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, l)
		for k, v in props or {} do l[k] = v end
		return l
	end
	criticalLabel = card(1, Color3.fromRGB(255, 176, 80), { Font = Enum.Font.FredokaOne, TextSize = 19 })
	runLabel = card(2, THEME.Gold)
	rigLabel = card(3, Color3.fromRGB(255, 150, 150))
	rigLabel.Visible = true

	-- Top stack: everything that explains the fight sits in ONE column at the top (boss header, threat cards, what this volley
	-- would do, the crystal under the cursor), so the rig and the grid below stay clear. The camera fits the grid under it.
	local topStack = mk("Frame", { Name = "TopStack", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.new(1, -370, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, blastGroup)
	mk("UIListLayout", { Padding = UDim.new(0, 5), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, topStack)
	mk("UISizeConstraint", { MaxSize = Vector2.new(500, 9999) }, topStack)
	local function reportReserve()
		local bottom = topStack.AbsolutePosition.Y - gui.AbsolutePosition.Y + topStack.AbsoluteSize.Y
		CameraFeedback.SetTopReserve(topStack.AbsoluteSize.Y > 0 and bottom + 8 or 0)
	end
	topStack:GetPropertyChangedSignal("AbsoluteSize"):Connect(reportReserve)

	-- Boss HUD: a header plate (health, the five phases, the one thing to do) and a row of threat cards.
	bossHud = BossHud.Build(topStack, Config.Bosses)

	dodgeButton = proxy(Kit.Button(blastGroup, { Name = "Dodge", Size = UDim2.fromOffset(190, 76), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -118), Color = Theme.Colors.Codex, Icon = "Bolt", Text = "DODGE (Q)", TextSize = 24, Layout = "Horizontal", Visible = false, OnClick = function() Remotes.Dodge:FireServer() end }))
	-- The Dodge button counts down between server updates (the server only sends a snapshot when something happens).
	local tickAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		tickAccumulator += dt
		if tickAccumulator < 0.1 then return end
		tickAccumulator = 0
		bossHud.Tick() -- threat countdowns
		local boss = State.Data and State.Data.Boss
		if boss and boss.RT and dodgeButton.Visible then
			local passed = os.clock() - (State.EventsAt or os.clock())
			if boss.RT.ShieldLeft - passed > 0 then
				dodgeButton.Text = "SHIELD UP"
			elseif boss.RT.DodgeLeft - passed > 0 then
				dodgeButton.Text = ("Dodge %ds"):format(math.ceil(boss.RT.DodgeLeft - passed))
				dodgeButton.BackgroundColor3 = Theme.Colors.Neutral
			else
				dodgeButton.Text = "DODGE (Q)"
				dodgeButton.BackgroundColor3 = Theme.Colors.Codex
			end
		end
	end)
	-- Active boosts (top, beside the shard count), the emergency-charge button, and the Revive offer.
	-- (boosts are shown next to the shards), the emergency-charge button, and the Revive offer.
	local boostChip = Kit.Chip(gui, { Name = "Boosts", Color = Theme.Colors.Boost, Visible = false, Position = UDim2.fromOffset(218, 12), Height = 44, TextSize = 20 })
	boostLabel = setmetatable({}, { __newindex = function(_, k, v)
		if k == "Text" then boostChip.Label.Text = v elseif k == "Visible" then boostChip.Root.Visible = v end
	end })
	chargeButton = proxy(Kit.Button(blastGroup, { Name = "EmergencyCharge", Size = UDim2.fromOffset(190, 64), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -204), Color = Theme.Colors.Boost, Icon = "Bolt", Text = "+1 CHARGE", TextSize = 20, Layout = "Horizontal", Visible = false, OnClick = function() Remotes.UseCharge:FireServer() end }))
	reviveModal = mk("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30, Active = true }, gui)
	reviveText = label(reviveModal, "", 24, THEME.Gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(1, -40, 0, 120), TextWrapped = true, Font = Enum.Font.FredokaOne, ZIndex = 31 })
	reviveYes = button(reviveModal, "", THEME.Accent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(320, 52), ZIndex = 31 })
	reviveNo = button(reviveModal, "Give up (keep 40% of the haul)", THEME.Panel, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromOffset(320, 44), ZIndex = 31 })
	reviveYes.Activated:Connect(function()
		Remotes.RunRevive:FireServer(true)
	end)
	reviveNo.Activated:Connect(function()
		Remotes.RunRevive:FireServer(false)
	end)

	-- The combat read (what this volley does to the Lurker / boss / its attacks) and the crystal info line are the last entries
	-- of the top stack, under the boss header and threat cards.
	readPanel = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, topStack)
	mk("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, readPanel)
	local function readCard(order, color, fill)
		local l = label(readPanel, "", 14, color, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, BackgroundColor3 = fill, BackgroundTransparency = 0.1, LayoutOrder = order, Visible = false, Font = Enum.Font.BuilderSansMedium })
		corner(l, 10)
		mk("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, l)
		return l
	end
	combatLabel = readCard(1, Color3.fromRGB(255, 226, 200), Color3.fromRGB(56, 26, 28))
	infoLabel = readCard(2, Color3.fromRGB(190, 198, 220), Color3.fromRGB(18, 20, 33))
	mk("UIStroke", { Color = Color3.fromRGB(226, 96, 84), Thickness = 1.5, Transparency = 0.35 }, combatLabel)

	-- Between-floor choice: three cards and "Bank & leave". Covers the screen while choosing (blasting is paused anyway).
	runModal = mk("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Active = true }, gui)
	runTitle = label(runModal, "", 26, THEME.Gold, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.new(1, -24, 0, 70), TextWrapped = true, Font = Enum.Font.FredokaOne, ZIndex = 21 })
	local row = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 310), ZIndex = 21 }, runModal)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }, row)
	runCards = {}
	for i = 1, 3 do
		local card = button(row, "", THEME.Panel, { Size = UDim2.fromOffset(210, 300), ZIndex = 22, LayoutOrder = i })
		mk("UIStroke", { Name = "RoomStroke", Color = THEME.Gold, Thickness = 2, Transparency = 0.25 }, card)
		local band = mk("Frame", { Name = "Band", BackgroundColor3 = THEME.Gold, Size = UDim2.new(1, 0, 0, 40), BorderSizePixel = 0, ZIndex = 23 }, card)
		corner(band, 12)
		mk("TextLabel", { Name = "RoomName", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Font = Enum.Font.BuilderSansBold, TextSize = 17, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Text = "" }, band)
		-- plain, readable text: a small grey caption, then the name, then the description, for each of the three parts
		local body = mk("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -56), ZIndex = 23 }, card)
		mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, body)
		local function line(name, order, size, color, font, wrapped)
			return mk("TextLabel", { Name = name, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = font or Enum.Font.BuilderSans, TextSize = size, TextColor3 = color, TextStrokeTransparency = 1, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 24, Text = "" }, body)
		end
		local caption = Color3.fromRGB(130, 140, 165)
		line("CapRoom", 1, 11, caption, Enum.Font.BuilderSansBold)
		line("RoomDesc", 2, 13, Color3.fromRGB(215, 222, 240))
		mk("Frame", { Name = "Gap1", LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 8), ZIndex = 23 }, body)
		line("CapRoute", 4, 11, caption, Enum.Font.BuilderSansBold)
		line("RouteName", 5, 15, Color3.new(1, 1, 1), Enum.Font.BuilderSansBold)
		line("RouteDesc", 6, 13, Color3.fromRGB(215, 222, 240))
		mk("Frame", { Name = "Gap2", LayoutOrder = 7, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 8), ZIndex = 23 }, body)
		line("CapRelic", 8, 11, caption, Enum.Font.BuilderSansBold)
		line("RelicName", 9, 15, Color3.new(1, 1, 1), Enum.Font.BuilderSansBold)
		line("RelicDesc", 10, 13, Color3.fromRGB(215, 222, 240))
		card.Activated:Connect(function()
			AudioManager.Play("Click")
			Remotes.RunPick:FireServer(i)
		end)
		runCards[i] = card
	end
	runBank = button(runModal, "", THEME.Accent, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(300, 48), ZIndex = 22 })
	runBank.Activated:Connect(function()
		AudioManager.Play("Click")
		Remotes.RunPick:FireServer("bank")
	end)

	seamLabel = label(blastGroup, "", 17, THEME.Dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(340, 24), Visible = false })
	previewFrame = mk("Frame", { BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.new(1, -340, 0, 34), Visible = false }, blastGroup)
	corner(previewFrame, 10)
	mk("UISizeConstraint", { MaxSize = Vector2.new(460, 34) }, previewFrame)
	previewLabel = label(previewFrame, "", 17, THEME.Text, { Size = UDim2.fromScale(1, 1), TextScaled = true })
	mk("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 13 }, previewLabel)
	chainLabel = label(blastGroup, "", 40, THEME.Hot, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(420, 56), Font = Enum.Font.FredokaOne, TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.fromRGB(20, 20, 30) })

	chargeColumn = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(150, 180) }, blastGroup)
	mk("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, chargeColumn)
	local clear = button(chargeColumn, "Clear", THEME.Row, { Size = UDim2.fromOffset(150, 42), LayoutOrder = 100 })
	clear.Activated:Connect(function()
		if UI.OnClear then UI.OnClear() end
	end)

	local detonate = Kit.ActionButton(blastGroup, { Name = "Detonate", Size = UDim2.fromOffset(260, 96), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Color = Theme.Colors.Action, Icon = "Bomb", Text = "DETONATE", TextSize = 38, OnClick = function() if UI.OnDetonate then UI.OnDetonate() end end })
	detonateButton = proxy(detonate)
	detonateStroke = mk("UIStroke", { Color = Color3.fromRGB(255, 244, 150), Thickness = 7, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, detonate.Face)

	----------------------------------------------------------- Forge / Codex panel
	local kitPanel = Kit.Panel(gui, { Name = "MenuPanel", Size = UDim2.new(0.74, 0, 0.7, 0), Position = UDim2.fromScale(0.58, 0.5), Color = THEME.Accent, Title = "", Visible = false, OnClose = function() UI.SetPanel(false) end })
	panel = kitPanel.Root
	mk("UISizeConstraint", { MaxSize = Vector2.new(620, 480) }, panel)
	panelRule = kitPanel.Ribbon
	kitPanel.Title.Name = "Title"
	-- (the dock along the bottom is the navigation now; this in-panel tab bar stays hidden but keeps the tab buttons wired)
	local tabBar = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 42), ZIndex = 11, Visible = false }, kitPanel.Body)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
	for i, name in { "Forge", "Loadout", "Daily", "Farm", "Goals", "Shop", "Codex" } do
		local tab = button(tabBar, name, THEME.Row, { Size = UDim2.new(1 / 7, -5, 1, 0), TextSize = 14, LayoutOrder = i, ZIndex = 12 })
		tab.TextColor3 = Fx.Tab[name]
		mk("UIStroke", { Color = Fx.Tab[name], Thickness = 1.5, Transparency = 0.5 }, tab)
		tabButtons[name] = tab
		tab.Activated:Connect(function()
			AudioManager.Play("Click")
			UI.SetPanel(true, name)
			if name == "Farm" then
				Remotes.FarmAction:FireServer("refresh")
			end
		end)
	end
	panelScroll = mk("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, kitPanel.Body)
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panelScroll)

	-- Welcome / how-to-play panel
	welcomeFrame = mk("Frame", { BackgroundColor3 = THEME.Bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.92, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 20 }, gui)
	corner(welcomeFrame, 16)
	mk("UISizeConstraint", { MaxSize = Vector2.new(460, 9999) }, welcomeFrame)
	mk("UIStroke", { Color = Theme.Colors.Outline, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round }, welcomeFrame)
	welcomeFrame.BackgroundColor3 = Theme.Colors.Panel
	mk("UIGradient", { Color = ColorSequence.new(Theme.Tint(Theme.Colors.Panel, 0.12), Theme.Shade(Theme.Colors.Panel, 0.3)), Rotation = 90 }, welcomeFrame)
	mk("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, welcomeFrame)
	mk("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, welcomeFrame)
	label(welcomeFrame, "Welcome to Blastwright", 26, THEME.Gold, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, ZIndex = 21 })
	local steps = {
		"1. Follow the gold arrow to a glowing blast pad and use its station (E on PC, tap the prompt on mobile).",
		"2. Tap the grid to plant charges, then press DETONATE. Kindlequartz chains to its neighbours, and Resonite boosts everything popped after it.",
		"3. Spend shards in the Forge on upgrades and to unlock new mine areas.",
		"4. Hidden geode caches are scattered off the roads. Explore to find them all.",
	}
	for i, text in steps do
		label(welcomeFrame, text, 17, THEME.Text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 1 + i, ZIndex = 21 })
	end
	local settingsRow = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 15, ZIndex = 21 }, welcomeFrame)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }, settingsRow)
	for _, setting in { { "Music", "Music" }, { "Sfx", "Effects" }, { "Shake", "Shake" } } do
		local key, title = setting[1], setting[2]
		local b = button(settingsRow, title .. ": On", THEME.Row, { Size = UDim2.new(1 / 3, -7, 1, 0), TextSize = 15, ZIndex = 22 })
		settingButtons[key] = { Button = b, Title = title }
		b.Activated:Connect(function()
			local current = not State.Data or not State.Data.Settings or State.Data.Settings[key] ~= false
			local nextValue = not current
			AudioManager.Play("Click")
			if State.Data and State.Data.Settings then
				State.Data.Settings[key] = nextValue
			end
			AudioManager.SetEnabled(key, nextValue)
			if key == "Shake" then
				CameraFeedback.SetShakeEnabled(nextValue)
			end
			Remotes.Setting:FireServer(key, nextValue)
			UI.RefreshSettings()
		end)
	end

	local go = button(welcomeFrame, "Let's go", THEME.Accent, { Size = UDim2.fromOffset(180, 48), TextSize = 20, TextColor3 = THEME.Text, LayoutOrder = 20, ZIndex = 21 })
	go.Activated:Connect(function()
		AudioManager.Play("Click")
		UI.ShowWelcome(false)
	end)

	-- Pulse the highlighted menu button
	RunService.Heartbeat:Connect(function()
		local pulse = 0.15 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 6))
		if highlighted and dock then
			dock.PulseHighlight(pulse)
		end
		if detonatePulse and detonateStroke then
			detonateStroke.Transparency = pulse
		end
	end)

	-- Shard count-up and bounce
	RunService.Heartbeat:Connect(function(dt)
		shardCur.Set(State.Data and State.Data.Shards or 0, shardCur.Shown == 0 and shardCur.Value == 0)
		shardCur.Step(dt)
	end)
end

function UI.SetEngaged(engaged)
	if not gui then return end
	blastGroup.Visible = engaged
	roamGroup.Visible = not engaged
	if engaged then
		UI.SetPanel(false)
		UI.ShowWelcome(false)
	end
end

-- Objective card text (roaming). nil hides the card.
-- Expedition HUD line and the between-floor choice. view = server run view, or nil when not on an expedition.
function UI.SetRun(view)
	Calm.Set(view ~= nil)
	if not runLabel then return end
	if not view then
		runLabel.Visible = false
		runModal.Visible = false
		return
	end
	runLabel.Text = ("EXPEDITION  floor %d / %d  (%s%s)\nHaul %s  |  Relics %d"):format(view.Floor, view.Floors, view.RoomName or "", view.Chaos and (": " .. view.Chaos) or "", commas(view.Haul), #view.Relics)
	runLabel.Visible = true
	local choosing = view.Phase == "Choosing"
	runModal.Visible = choosing
	if choosing then
		runTitle.Text = ("Floor %d cleared!  Haul %s. Choose your next step."):format(view.Floor, commas(view.Haul))
		for i, card in runCards do
			local c = view.Choices[i]
			card.Visible = c ~= nil
			if c then
				local roomColor = Fx.Room[c.Room] or THEME.Gold
				local body = card.Body
				card.BackgroundColor3 = Fx.Darken(roomColor, 0.82)
				card:FindFirstChild("RoomStroke").Color = roomColor
				card.Band.BackgroundColor3 = Fx.Darken(roomColor, 0.15)
				card.Band.RoomName.Text = c.RoomName
				body.CapRoom.Text = "NEXT FLOOR"
				body.RoomDesc.Text = c.RoomDescription
				body.CapRoute.Text = "PATH"
				body.RouteName.Text = c.RouteName
				body.RouteDesc.Text = c.RouteDescription
				body.CapRelic.Text = c.RelicName ~= "" and ("RELIC" .. (c.RelicFamily ~= "" and ("  -  " .. string.upper(c.RelicFamily)) or "")) or "RELIC"
				body.RelicName.Text = c.RelicName ~= "" and c.RelicName or "None this time"
				body.RelicName.TextColor3 = Fx.Lighten(Fx.Family[c.RelicFamily] or THEME.Text, 0.4)
				body.RelicDesc.Text = c.RelicDescription
			end
		end
		runBank.Text = ("Bank %s shards & leave"):format(commas(view.BankNow))
	end
end

function UI.SetObjective(text)
	if not objectiveCard then return end
	objectiveCard.Visible = text ~= nil and text ~= ""
	if text then
		objectiveText.Text = text
		local h = math.max(18, math.ceil(objectiveText.TextBounds.Y))
		objectiveText.Size = UDim2.fromOffset(206, h)
		objectiveCard.Size = UDim2.fromOffset(230, 38 + h + 10)
	end
end

-- Pulse a menu button ("Forge") to draw the eye; nil clears.
function UI.SetHighlight(name)
	if highlighted == name then return end
	highlighted = name
	if dock then
		dock.SetHighlight(name)
	end
end

-- Instruction pill shown above the blast controls. "" hides it.
-- The next-step hint no longer floats over the grid: a non-empty hint just makes the Detonate button pulse.
function UI.SetBlastHint(text)
	detonatePulse = text ~= nil and text ~= ""
	if detonateStroke then
		detonateStroke.Enabled = detonatePulse
	end
end

function UI.RefreshSettings()
	local settings = State.Data and State.Data.Settings
	for key, entry in settingButtons do
		local on = not settings or settings[key] ~= false
		entry.Button.Text = ("%s: %s"):format(entry.Title, on and "On" or "Off")
		entry.Button.BackgroundColor3 = on and THEME.Accent or THEME.Row
		entry.Button.TextColor3 = on and THEME.Text or THEME.Text
	end
end

function UI.ShowWelcome(show)
	if welcomeFrame then
		welcomeFrame.Visible = show
	end
end

local shownArea = nil
local areaFade = 0
-- Shows the area name only when it changes (entering a new area): fades in, holds, fades away.
function UI.SetLocation(text)
	if not locationLabel or text == shownArea then
		return
	end
	shownArea = text
	areaFade += 1
	local mine = areaFade
	locationLabel.Text = text
	local stroke = locationLabel:FindFirstChildOfClass("UIStroke")
	locationLabel.TextTransparency = 1
	if stroke then stroke.Transparency = 1 end
	Kit.Tween(locationLabel, 0.35, { TextTransparency = 0 })
	if stroke then Kit.Tween(stroke, 0.35, { Transparency = 0 }) end
	task.delay(3, function()
		if mine ~= areaFade then
			return
		end
		Kit.Tween(locationLabel, 0.9, { TextTransparency = 1 })
		if stroke then Kit.Tween(stroke, 0.9, { Transparency = 1 }) end
	end)
end

function UI.SetPreview(text)
	if previewLabel then
		previewLabel.Text = text
		previewFrame.Visible = text ~= ""
	end
end

-- Second preview line (crystal description, legend). "" hides it.
function UI.SetCombat(text)
	if combatLabel then
		combatLabel.Text = text or ""
		combatLabel.Visible = text ~= nil and text ~= ""
	end
end

function UI.SetInfo(text)
	if infoLabel then
		infoLabel.Text = text
		infoLabel.Visible = text ~= nil and text ~= ""
	end
end

function UI.SetWorldBoss(view, receivedAt)
	if statusDock then
		statusDock.SetWorldBoss(view, receivedAt)
	end
end

-- Shared Server Goal tile (bottom-right status dock). view = { Round, Progress, Target, Done, FrenzyLeft } or nil.
function UI.SetCommunity(view, receivedAt)
	if statusDock then
		statusDock.SetGoal(view, receivedAt)
	end
end

function UI.SetChain(pops, mult)
	if not chainLabel then return end
	if pops <= 0 then
		chainLabel.Text = ""
		return
	end
	chainLabel.Text = ("CHAIN %d   x%.1f"):format(pops, mult)
	-- the combo meter heats up as the chain grows: white-orange, gold, red-hot, then magenta, and gets bigger
	local heat = pops >= 35 and Color3.fromRGB(255, 90, 230) or (pops >= 20 and Color3.fromRGB(255, 70, 60) or (pops >= 10 and Color3.fromRGB(255, 205, 80) or Color3.fromRGB(255, 160, 90)))
	chainLabel.TextColor3 = heat
	local base = 36 + math.min(pops, 40) * 0.5
	chainLabel.TextSize = base
	TweenService:Create(chainLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = base + 8 }):Play()
end

-- The boss appears / changes phase: a banner with the name (or the new phase) and what to do now.
function UI.ShowBossIntro(boss)
	AudioManager.Play("Tier")
	local def = Config.Bosses.Defs[boss.Kind]
	Feed.Banner(string.upper(boss.Name), def and def.Description or nil, Color3.fromRGB(214, 70, 78), 3.2, true)
end

function UI.ShowPhase(phase, boss)
	AudioManager.Play("Tier")
	Feed.Banner(string.upper(phase) .. " PHASE", boss and BossHud.Objective(boss, Config.Bosses) or nil, BossHud.PhaseColor[phase] or THEME.Gold, 2.2, true)
end

-- Big moments (chain tiers, Critical Mass, boss phases) use the banner: one plate at a time, no glow.
local BANNER_COLORS = {
	rumble = Color3.fromRGB(236, 176, 74),
	cascade = Color3.fromRGB(242, 146, 60),
	avalanche = Color3.fromRGB(238, 92, 72),
	cataclysm = Color3.fromRGB(226, 84, 196),
	["critical mass"] = Color3.fromRGB(255, 138, 40),
	["boss defeated"] = Color3.fromRGB(240, 196, 70),
}

function UI.ShowTier(name, bonus, total)
	AudioManager.Play("Tier")
	local key = string.lower(name)
	local color = BANNER_COLORS[key] or (key:find("phase") and Color3.fromRGB(210, 92, 92)) or THEME.Gold
	local subtitle = (bonus and bonus > 0) and ("+%d%% chain bonus"):format(math.floor(bonus * 100 + 0.5)) or nil
	if key == "critical mass" then
		subtitle = "Damage and shards up for the next volleys"
	elseif key == "boss defeated" then
		subtitle = "Final blast!"
	end
	Feed.Banner(string.upper(name), subtitle, color, nil, key == "boss defeated")
end

-- Messages go to the feed on the right. "Threat" messages (boss wind-ups) are shown by the boss panel instead, so they only make a sound.
function UI.ShowReward(title, text, icon, color, sub)
	Kit.Popup(gui, { Title = title, Text = text, Icon = icon, Color = color, Sub = sub })
end

function UI.Toast(text, kind)
	if kind == "Threat" then
		AudioManager.Play("Error")
		return
	end
	local style = Feed.Classify(text, kind)
	-- the big moments also get a reward popup
	if style == "Achievement" and (text:find("^MASTERY") or text:find("^EXPEDITION COMPLETE") or text:find("^ELITE REWARD")) then
		local title, body = Feed.Split(text)
		UI.ShowReward(text:find("^MASTERY") and "MASTERY!" or (text:find("^ELITE") and "RELIC FOUND!" or "VICTORY!"), title, text:find("^MASTERY") and "Goals" or (text:find("^ELITE") and "Gem" or "Goals"), Theme.Colors.Boost, body)
	end
	local title, body = Feed.Split(text)
	Feed.Push(style, title, body)
	AudioManager.Play(kind == "Error" and "Error" or "Reward")
end

local TAB_GLYPH = { Loadout = "◆", Forge = "▲", Daily = "★", Farm = "●", Goals = "★", Shop = "◆", Codex = "◆" }

-- One list row: a glowing icon tile (or a spinning gem), title and description, an optional progress bar, and a button.
-- opts = { Icon = glyph, IconColor = Color3, Gem = Color3 (spinning crystal), Dim = greyed out, Progress = 0..1, Accent = Color3 }
local function row(order, titleText, desc, buttonText, enabled, onClick, titleColor, opts)
	opts = opts or {}
	local accent = opts.Accent or Fx.Tab[activeTab] or THEME.Accent
	local hasBar = opts.Progress ~= nil
	local height = hasBar and 90 or 78
	local f = mk("Frame", { BackgroundColor3 = THEME.Row, Size = UDim2.new(1, -8, 0, height), LayoutOrder = order, ZIndex = 11 }, panelScroll)
	corner(f, 14)
	Fx.Depth(f, 0.2)
	mk("UIStroke", { Color = Theme.Colors.Outline, Thickness = 3.5, LineJoinMode = Enum.LineJoinMode.Round }, f)
	f.BackgroundColor3 = opts.Dim and Color3.fromRGB(52, 58, 92) or Theme.Shade(accent, 0.62)
	local iconY = (height - 56) // 2
	if opts.Gem then
		local holder = mk("Frame", { BackgroundColor3 = Fx.Darken(opts.Gem, 0.78), Position = UDim2.fromOffset(16, iconY), Size = UDim2.fromOffset(56, 56), BorderSizePixel = 0, ZIndex = 12 }, f)
		corner(holder, 14)
		mk("UIStroke", { Color = opts.Dim and THEME.Dim or opts.Gem, Thickness = 2, Transparency = opts.Dim and 0.7 or 0.2 }, holder)
		local gem = Fx.Gem(holder, opts.Gem, 56, opts.Dim)
		gem.ZIndex = 13
	else
		local tileColor = opts.Dim and Color3.fromRGB(96, 104, 140) or (opts.IconColor or accent)
		if opts.Icon then
			Fx.Icon(f, opts.Icon, tileColor, 54, { Position = UDim2.fromOffset(16, iconY + 1), ZIndex = 12 })
		else
			-- no specific icon: draw this page's own icon big on a coloured tile
			local tile = mk("Frame", { BackgroundColor3 = tileColor, Position = UDim2.fromOffset(16, iconY + 1), Size = UDim2.fromOffset(54, 54), BorderSizePixel = 0, ZIndex = 12 }, f)
			corner(tile, 14)
			mk("UIStroke", { Color = Theme.Colors.Outline, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round }, tile)
			mk("UIGradient", { Color = ColorSequence.new(Theme.Tint(tileColor, 0.28), Theme.Shade(tileColor, 0.08)), Rotation = 90 }, tile)
			Icons.Draw(activeTab, tile, tileColor, 0.86)
		end
	end
	label(f, titleText, 19, titleColor or THEME.Text, { Position = UDim2.fromOffset(82, 6), Size = UDim2.new(1, -212, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 })
	label(f, desc, 14, THEME.Dim, { Position = UDim2.fromOffset(82, 32), Size = UDim2.new(1, -212, 0, hasBar and 32 or 40), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, ZIndex = 12 })
	if hasBar then
		local bar = Kit.Bar(f, { Position = UDim2.new(0, 82, 0, height - 24), Size = UDim2.new(1, -212, 0, 16), Color = opts.Progress >= 1 and Theme.Colors.Success or accent, ZIndex = 12 })
		bar.Set(opts.Progress, nil, true)
	end
	if buttonText then
		local ready = enabled and string.sub(buttonText, 1, 5) == "Claim"
		local b = button(f, buttonText, enabled and Fx.Lighten(accent, 0.1) or THEME.Panel, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 52), TextSize = 16, ZIndex = 12, TextColor3 = enabled and THEME.Text or THEME.Dim })
		if ready then
			Fx.Shimmer(b, 1.6, 0.7)
			Fx.Glow(b, Fx.Lighten(accent, 0.5), 2.5, 0.9)
		end
		b.Activated:Connect(function()
			if onClick then onClick() end
		end)
	end
	return f
end

local function header(order, text)
	local c = Fx.Tab[activeTab] or THEME.Accent
	local f = mk("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -8, 0, 34), LayoutOrder = order, ZIndex = 11 }, panelScroll)
	corner(f, 10)
	f.BackgroundColor3 = c
	Fx.Depth(f, 0.25)
	mk("UIStroke", { Color = Theme.Colors.Outline, Thickness = 3.5, LineJoinMode = Enum.LineJoinMode.Round }, f)
	local t = label(f, string.upper(text), 18, Color3.new(1, 1, 1), { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, ZIndex = 12 })
	mk("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 9 }, t)
end

local function rebuildPanel()
	if not panel.Visible or not State.Data then return end
	for _, c in panelScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local d = State.Data
	local titleLabel = panel:FindFirstChild("Title", true)
	titleLabel.TextColor3 = THEME.Text
	panelRule.BackgroundColor3 = Fx.Tab[activeTab] or THEME.Accent
	for name, tab in tabButtons do
		local selected = name == activeTab
		tab.BackgroundColor3 = selected and Fx.Tab[name] or THEME.Row
		tab.TextColor3 = selected and THEME.Text or Fx.Tab[name]
	end

	if activeTab == "Forge" then
		titleLabel.Text = "Forge"
		local order = 0
		header(order, "Rig upgrades")
		for _, id in Config.Upgrades.Order do
			order += 1
			local def = Config.Upgrades.Defs[id]
			local level = d.Upgrades[id] or 0
			local cost = def.Costs[level + 1]
			row(order, ("%s  Lv %d/%d"):format(def.Name, level, #def.Costs), def.Description, cost and ("Buy  ◆ " .. commas(cost)) or "MAX", cost ~= nil and d.Shards >= cost, function()
				Remotes.Buy:FireServer("Upgrade", id)
			end, nil, { Progress = level / math.max(1, #def.Costs), Icon = "▲", Accent = Color3.fromRGB(255, 150, 60) })
		end
		order += 1
		header(order, "Charges")
		for _, id in Config.Charges.Order do
			local def = Config.Charges.Defs[id]
			if def.UnlockCost then
				order += 1
				local owned = d.UnlockedCharges[id]
				row(order, def.Name, def.Description, owned and "Owned" or ("Unlock  ◆ " .. commas(def.UnlockCost)), not owned and d.Shards >= def.UnlockCost, function()
					if not owned then Remotes.Buy:FireServer("Charge", id) end
				end, nil, { Icon = ({ Basic = "o", Shaft = "|", Cross = "+", Shock = "~" })[id] or "*", Accent = ({ Basic = Color3.fromRGB(255, 160, 60), Shaft = Color3.fromRGB(90, 200, 255), Cross = Color3.fromRGB(255, 100, 220), Shock = Color3.fromRGB(120, 230, 190) })[id], Dim = false })
			end
		end
		order += 1
		header(order, "Mine areas (unlock to blast there)")
		for n, s in Config.Strata do
			order += 1
			local unlocked = n <= d.StrataUnlocked
			local can = n == d.StrataUnlocked + 1 and d.Shards >= s.Cost
			row(order, ("%d. %s"):format(n, s.Name), s.Description, unlocked and "Open" or ("Unlock  ◆ " .. commas(s.Cost)), can, function()
				if not unlocked then Remotes.Buy:FireServer("Stratum", tostring(n)) end
			end, nil, { Icon = tostring(n), Accent = ({ Color3.fromRGB(90, 200, 255), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 120, 60), Color3.fromRGB(110, 230, 190) })[n], Dim = not unlocked and not can })
		end
	elseif activeTab == "Loadout" then
		titleLabel.Text = "Loadout"
		local order = 0
		header(order, "Each charge has its own upgrade path: pick ONE fork per branch")
		-- Expedition difficulty: opt-in tiers that add rules and pay a bigger haul. Unlocked by winning at your top tier.
		if d.Ascension then
			local asc = d.Ascension
			order += 1
			header(order, ("Expedition difficulty (Ascension)  -  highest unlocked: %d"):format(asc.Unlocked))
			local tiers = Config.Ascension.Tiers
			for tier = 0, math.min(asc.Unlocked + 1, #tiers) do
				order += 1
				local locked = tier > asc.Unlocked
				local selected = asc.Selected == tier
				local fx = AscensionLogic.Effects(tier, Config.Ascension)
				local title = tier == 0 and "Normal" or ("Ascension %d: %s"):format(tier, tiers[tier].Name)
				local desc
				if locked then
					desc = tier == 1 and "Win an Expedition on Normal to unlock." or ("Win an Expedition at Ascension %d to unlock."):format(tier - 1)
				elseif tier == 0 then
					desc = "The standard Expedition."
				else
					desc = ("%s  Total haul x%.2f."):format(tiers[tier].Description, fx.RewardMult)
				end
				row(order, title, desc, locked and "Locked" or (selected and "Selected" or "Select"), not locked and not selected, function()
					Remotes.AscensionSet:FireServer(tier)
				end, selected and THEME.Gold or nil, { Icon = tostring(tier), Accent = Color3.fromRGB(235, 90, 90), Dim = locked or not selected })
			end
		end
		local state = { Owned = d.Traits or {} }
		local charges = State.Charges()
		for _, branch in Config.Traits.BranchOrder do
			local def = Config.Charges.Defs[branch]
			local unlocked = d.UnlockedCharges[branch] == true
			local eff = charges[branch]
			local cells = #ChainSim.BlastCells(eff.Shape, 5, 5, eff.Radius or 0, eff.Range or 0, 9, eff)
			local direct = eff.DirectMult and eff.DirectMult > 1 and ("   direct hits x%.2f"):format(eff.DirectMult) or ""
			order += 1
			header(order, ("%s   %d cells%s"):format(def.Name, cells, direct))
			local anyOwned = false
			for _ in pairs(state.Owned) do anyOwned = true break end
			local ownedHere = false
			for id, node in Config.Traits.Nodes do
				if node.Branch == branch and state.Owned[id] then ownedHere = true end
			end
			order += 1
			local resetText = ownedHere and ("Reset  ◆ " .. commas(Config.Traits.Respec)) or nil
			row(order, unlocked and def.Role or "Locked: unlock this charge in the Forge", def.Description, resetText, ownedHere and d.Shards >= Config.Traits.Respec, function()
				Remotes.TraitAction:FireServer("respec", branch)
			end, nil, { Icon = ({ Basic = "o", Shaft = "|", Cross = "+", Shock = "~" })[branch] or "*", Accent = ({ Basic = Color3.fromRGB(255, 160, 60), Shaft = Color3.fromRGB(90, 200, 255), Cross = Color3.fromRGB(255, 100, 220), Shock = Color3.fromRGB(120, 230, 190) })[branch], Dim = not unlocked })
			for _, node in Loadout.BranchView(state, branch, Config.Traits, d.UnlockedCharges, d.Shards) do
				order += 1
				local cfgNode = Config.Traits.Nodes[node.Id]
				local btn
				if node.Owned then
					btn = "Owned"
				elseif node.CanBuy then
					btn = "Buy  ◆ " .. commas(node.Cost)
				elseif node.Reason == "Not enough shards." then
					btn = "◆ " .. commas(node.Cost)
				else
					btn = "Locked"
				end
				local tierText = cfgNode.Group and ("Tier %d, fork"):format(node.Tier) or ("Tier %d"):format(node.Tier)
				local desc = node.Description
				if not node.Owned and not node.CanBuy and node.Reason ~= "Not enough shards." then
					desc = desc .. "  (" .. node.Reason .. ")"
				end
				row(order, ("%s  [%s]"):format(node.Name, tierText), desc, btn, node.CanBuy, function()
					Remotes.TraitAction:FireServer("buy", node.Id)
				end, node.Owned and THEME.Gold or nil, { Icon = tostring(node.Tier), Accent = ({ Basic = Color3.fromRGB(255, 160, 60), Shaft = Color3.fromRGB(90, 200, 255), Cross = Color3.fromRGB(255, 100, 220), Shock = Color3.fromRGB(120, 230, 190) })[branch], Dim = not node.Owned and not node.CanBuy })
			end
		end
	elseif activeTab == "Daily" then
		titleLabel.Text = "Daily objectives"
		local secs = math.max(0, math.floor((State.DailyResetAt or 0) - os.clock()))
		-- Free daily reward: claim once a day; consecutive days build a 7-day streak.
		if d.Streak then
			local sv = d.Streak
			local dayNo = sv.CycleDay > 0 and sv.CycleDay or 1
			header(-10, ("Daily reward  -  streak %d day%s"):format(sv.Count, sv.Count == 1 and "" or "s"))
			row(-9, ("Day %d of 7"):format(dayNo), Grants.Describe(Config.Streak.Days[dayNo]) .. (sv.CanClaim and "" or "   (tomorrow: " .. Grants.Describe(Config.Streak.Days[dayNo % 7 + 1]) .. ")"), sv.CanClaim and "Claim FREE" or "Claimed", sv.CanClaim, function()
				Remotes.StreakClaim:FireServer()
			end, nil, { Icon = "★", Accent = Color3.fromRGB(110, 230, 150), Dim = not sv.CanClaim, Progress = dayNo / 7 })
		end
		header(0, ("Resets in %dh %02dm (unclaimed rewards are lost)"):format(secs // 3600, (secs % 3600) // 60))
		for _, item in d.Dailies or {} do
			local done = item.Progress >= item.Target
			local btnText = item.Claimed and "Claimed" or (done and ("Claim  ◆ " .. commas(item.Reward)) or ("%d / %d"):format(item.Progress, item.Target))
			row(item.Slot, item.Text, ("Reward: ◆ %s"):format(commas(item.Reward)), btnText, done and not item.Claimed, function()
				if done and not item.Claimed then Remotes.Claim:FireServer(item.Slot) end
			end, nil, { Progress = item.Progress / math.max(1, item.Target), Icon = "★", Accent = item.Claimed and THEME.Dim or nil, Dim = item.Claimed })
		end
		-- Daily Puzzle: same grid for everyone, one try, medal by score against par.
		local pz = d.Puzzle
		if pz then
			header(20, ("Daily Puzzle  (streak %d, best %d)"):format(pz.Streak, pz.BestStreak))
			local medals = {}
			for _, m in Config.Puzzle.Medals do
				table.insert(medals, ("%s %d%%: %s"):format(m.Name, m.Ratio * 100, commas(m.Reward)))
			end
			local desc = "Stand at a blast pad. 3 Basic charges, one volley, everyone gets the same grid. Score vs par: " .. table.concat(medals, ", ") .. ". Streak adds +10% a day."
			local btn, canPlay = "Play", true
			if pz.Done then
				btn = (pz.Medal ~= "" and pz.Medal or "No medal") .. (" (%s / par %s)"):format(commas(pz.Score), commas(pz.Par))
				canPlay = false
			end
			row(21, "Today's puzzle", desc, btn, canPlay, function()
				if canPlay then Remotes.PuzzleStart:FireServer() end
			end, nil, { Icon = "P", Accent = Color3.fromRGB(255, 200, 60), Dim = not canPlay })
		end
		-- Notice Board: pick ONE contract at a time from three daily offers (Easy / Standard / Hard).
		if d.Contracts and #d.Contracts > 0 then
			local anyActive = false
			for _, c in d.Contracts do
				anyActive = anyActive or c.Active
			end
			header(30, anyActive and "Notice Board: finish your contract or give it up to take another" or "Notice Board: pick one contract (progress counts after you accept)")
			local tierIcons = { "E", "S", "H" }
			local tierColors = { Theme.Colors.Success, Theme.Colors.Warning, Theme.Colors.Danger }
			for _, c in d.Contracts do
				local rewards = Config.Contracts.Rewards[c.Tier] or {}
				local parts = {}
				for _, g in rewards do
					if g.Kind == "Shards" then
						table.insert(parts, "◆ " .. commas(g.Amount * math.max(1, d.Progress and d.Progress.StrataUnlocked or 1)))
					elseif g.Kind == "Tokens" then
						table.insert(parts, ("%d %s token%s"):format(g.Count, string.lower(g.Token), g.Count > 1 and "s" or ""))
					end
				end
				local done = c.Progress >= c.Target
				local btn, can, onClick
				if c.Done then
					btn, can = "Done", false
				elseif c.Active then
					if done then
						btn, can, onClick = "Claim", true, function() Remotes.ContractClaim:FireServer() end
					else
						btn, can = ("%d / %d"):format(c.Progress, c.Target), false
					end
				else
					btn, can = "Accept", not anyActive
					onClick = function() Remotes.ContractAccept:FireServer(c.Tier) end
				end
				row(30 + c.Tier, ("%s: %s"):format(c.TierName, c.Text), "Reward: " .. table.concat(parts, " + "), btn, can, onClick or function() end, nil, { Progress = c.Active and c.Progress / math.max(1, c.Target) or (c.Done and 1 or nil), Icon = tierIcons[c.Tier], Accent = tierColors[c.Tier], Dim = c.Done })
			end
			if anyActive then
				row(34, "Give up the current contract", "Its progress is lost, but you can take it (or another) again today.", "Give up", true, function() Remotes.ContractAccept:FireServer("abandon") end, nil, { Icon = "X", Accent = Theme.Colors.Neutral })
			end
		end
		-- Weekly challenges: bigger targets and rewards, reset Monday 00:00 UTC.
		local weekSecs = math.max(0, math.floor((State.WeeklyResetAt or 0) - os.clock()))
		header(10, ("Weekly challenges: reset in %dd %02dh (unclaimed rewards are lost)"):format(weekSecs // 86400, (weekSecs % 86400) // 3600))
		for _, item in d.Weeklies or {} do
			local done = item.Progress >= item.Target
			local btnText = item.Claimed and "Claimed" or (done and ("Claim  ◆ " .. commas(item.Reward)) or ("%s / %s"):format(commas(item.Progress), commas(item.Target)))
			row(10 + item.Slot, item.Text, ("Reward: ◆ %s"):format(commas(item.Reward)), btnText, done and not item.Claimed, function()
				if done and not item.Claimed then Remotes.ClaimWeekly:FireServer(item.Slot) end
			end, nil, { Progress = item.Progress / math.max(1, item.Target), Icon = "W", Accent = Color3.fromRGB(190, 120, 255), Dim = item.Claimed })
		end
	elseif activeTab == "Farm" then
		local f = d.Farm
		titleLabel.Text = "Crystal Farm"
		if f then
			header(0, ("Level %d / %d: produces %s shards an hour, stores up to %d hours (even while you are away)"):format(f.Level, f.MaxLevel, commas(f.PerHour), f.CapHours))
			local full = f.Pending >= f.PerHour * f.CapHours
			row(1, "Store", full and "The store is full: collect it so it keeps producing!" or "Shards waiting for you.", f.Pending > 0 and ("Collect  ◆ " .. commas(f.Pending)) or "Empty", f.Pending > 0, function()
				Remotes.FarmAction:FireServer("collect")
			end)
			if f.NextCost then
				row(2, ("Upgrade to level %d"):format(f.Level + 1), ("Produces %s shards an hour. Collects the store first."):format(commas(f.NextPerHour)), "Upgrade  ◆ " .. commas(f.NextCost), d.Shards >= f.NextCost, function()
					Remotes.FarmAction:FireServer("upgrade")
				end)
			else
				row(2, "Fully upgraded", "Nothing left to build here.", "Max", false, function() end)
			end
		end
	elseif activeTab == "Goals" then
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
	elseif activeTab == "Shop" then
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
	else
		titleLabel.Text = "Codex"
		local found = 0
		for index, id in Config.Crystals.Order do
			local def = Config.Crystals.Defs[id]
			local known = d.Codex.Discovered[id]
			if known then found += 1 end
			local rc = Config.Rarities.Info[def.Rarity].Color
			local mut = d.Codex.Mutated[id] and "   Prismatic found" or ""
			row(index, known and (def.Name .. "  (" .. def.Rarity .. ")" .. mut) or "???", known and def.Description or ("Found in stratum " .. def.Stratum), nil, false, nil, known and Color3.fromRGB(rc[1], rc[2], rc[3]) or THEME.Dim, { Gem = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]), Dim = not known, Accent = Color3.fromRGB(rc[1], rc[2], rc[3]) })
		end
		-- Blast colors: owned styles can be equipped; locked ones say how to get them.
		local order = #Config.Crystals.Order + 1
		-- Specimen Cabinet: every crystal kind in six grades; big chains find better grades.
		if d.Specimens then
			local have = 0
			for _, count in d.Specimens.Found do
				if count > 0 then have += 1 end
			end
			local totalSlots = #Config.Crystals.Order * #Config.Specimens.Rarities
			header(order, ("Specimen Cabinet  %d/%d  (find them by blasting; big chains find rarer grades)"):format(have, totalSlots))
			for _, entry in SpecimensLogic.View({ Found = d.Specimens.Found }, Config.Crystals.Order, Config.Specimens) do
				order += 1
				local def = Config.Crystals.Defs[entry.Kind]
				local parts = {}
				for _, g in entry.Grades do
					table.insert(parts, g.Count > 0 and ("%s x%d"):format(g.Name, g.Count) or "?")
				end
				local c = def and Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]) or THEME.Accent
				row(order, (def and def.Name or entry.Kind) .. ("   %d/%d"):format(entry.Have, entry.Of), table.concat(parts, "  |  "), nil, false, nil, entry.Have >= entry.Of and THEME.Gold or nil, { Gem = c, Accent = c, Progress = entry.Have / entry.Of, Dim = entry.Have == 0 })
			end
			order += 1
		end
		-- Assay Office: pop each crystal kind to reach milestones; claim the rewards here.
		if d.Assay and #d.Assay > 0 then
			header(order, "Assay Office: every crystal kind has its own pop milestones")
			for _, a in d.Assay do
				order += 1
				local def = Config.Crystals.Defs[a.Kind]
				local first = a.Claimable[1]
				local btn, can, onClick
				if first then
					local tier = Config.Assay.Tiers[first]
					btn, can = "Claim  ◆ " .. commas(tier.Reward * math.max(1, d.Progress and d.Progress.StrataUnlocked or 1)), true
					onClick = function() Remotes.AssayClaim:FireServer(a.Kind, first) end
				elseif a.Next then
					btn, can = ("%s / %s"):format(commas(a.Pops), commas(a.Next.Pops)), false
				else
					btn, can = "Grandmaster", false
				end
				local c = def and Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]) or THEME.Accent
				local goal = a.Next and ("Next: %s at %s pops"):format(a.Next.Id, commas(a.Next.Pops)) or "Every milestone reached"
				row(order, (def and def.Name or a.Kind) .. ("  (%s popped)"):format(commas(a.Pops)), goal, btn, can, onClick or function() end, nil, { Gem = c, Accent = c, Progress = a.Next and a.Pops / math.max(1, a.Next.Pops) or 1 })
			end
			order += 1
		end
		header(order, "Blast colors")
		for _, style in d.Styles or {} do
			order += 1
			local c = style.Color
			local btnText = style.Equipped and "Equipped" or (style.Owned and "Equip" or "Locked")
			row(order, style.Name, style.Owned and "Owned" or style.Unlock, btnText, style.Owned and not style.Equipped, function()
				if style.Owned and not style.Equipped then Remotes.Equip:FireServer(style.Id) end
			end, Color3.fromRGB(c[1], c[2], c[3]), { Icon = "●", Accent = Color3.fromRGB(c[1], c[2], c[3]), Dim = not style.Owned })
		end
		-- Monsters, bosses, relics and boss mastery: the long-term "I have not seen everything yet" list.
		local col = d.Collection
		if col then
			order += 1
			header(order, "Lurkers (kills)")
			for _, r in col.Lurkers do
				order += 1
				row(order, r.Found and ("%s  x%d"):format(r.Name, r.Kills) or "???", r.Found and r.Description or "Not met yet", nil, false, nil, r.Found and THEME.Text or THEME.Dim, { Icon = string.sub(r.Name, 1, 1), Accent = Color3.fromRGB(235, 90, 90), Dim = not r.Found })
			end
			order += 1
			header(order, "Bosses")
			for _, r in col.Bosses do
				order += 1
				row(order, r.Found and ("%s  x%d"):format(r.Name, r.Kills) or "???", r.Found and r.Description or "Reach a boss floor of an Expedition (floor 4 or 8)", nil, false, nil, r.Found and THEME.Gold or THEME.Dim, { Icon = "★", Accent = Color3.fromRGB(200, 40, 60), Dim = not r.Found })
			end
			order += 1
			header(order, ("Relics found %d/%d"):format(col.RelicsFound, col.RelicsTotal))
			for _, r in col.Relics do
				order += 1
				row(order, r.Found and ("%s  [%s]"):format(r.Name, r.Family) or "???", r.Found and r.Description or "Find it in an Expedition", nil, false, nil, r.Found and THEME.Text or THEME.Dim, { Icon = "◆", Accent = Fx.Family[r.Family] or THEME.Accent, Dim = not r.Found })
			end
		end
		local fin = d.Finishers
		if fin then
			order += 1
			header(order, "Boss finishers (the look of your FINAL BLAST)")
			for _, def in Config.Finishers.Defs do
				order += 1
				local owned = def.Id == Config.Finishers.DefaultId or fin.Owned[def.Id] == true
				local worn = fin.Equipped == def.Id
				row(order, def.Name, owned and "Owned" or "Sold in the Shop", worn and "Worn" or (owned and "Wear" or "Locked"), owned and not worn, function()
					if owned and not worn then Remotes.EquipFinisher:FireServer(def.Id) end
				end, Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]), { Icon = "✦", Accent = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]), Dim = not owned })
			end
		end
		local mastery = d.Mastery
		if mastery then
			order += 1
			header(order, "Boss mastery (each one gives a title to wear)")
			for _, obj in mastery.Objectives do
				order += 1
				local worn = mastery.Title == obj.Title
				local btnText = not obj.Done and "Locked" or (worn and "Worn" or "Wear")
				row(order, obj.Name .. "  [" .. obj.Title .. "]", obj.Description .. ("  Reward: %s"):format(commas(obj.Reward)), btnText, obj.Done and not worn, function()
					if obj.Done and not worn then Remotes.EquipTitle:FireServer(obj.Title) end
				end, obj.Done and THEME.Gold or THEME.Dim, { Icon = obj.Done and "★" or "?", Accent = THEME.Gold, Dim = not obj.Done })
			end
			if mastery.Title ~= "" then
				order += 1
				row(order, "Take off title", "Remove the title above your head.", "Remove", true, function()
					Remotes.EquipTitle:FireServer("")
				end)
			end
		end
		titleLabel.Text = ("Codex  %d/%d"):format(found, #Config.Crystals.Order)
	end
end

function UI.SetPanel(open, tab)
	activeTab = tab or activeTab
	State.PanelOpen = open
	panel.Visible = open
	if dock then
		dock.SetSelected(open and activeTab or nil)
	end
	rebuildPanel()
end

local function rebuildCharges()
	for _, b in chargeButtons do b:Destroy() end
	table.clear(chargeButtons)
	if not State.Data then return end
	for i, id in Config.Charges.Order do
		if State.Data.UnlockedCharges[id] then
			local def = Config.Charges.Defs[id]
			local selected = State.SelectedCharge == id
			local kindColor = ({ Basic = Color3.fromRGB(255, 160, 60), Shaft = Color3.fromRGB(90, 200, 255), Cross = Color3.fromRGB(255, 100, 220), Shock = Color3.fromRGB(120, 230, 190) })[id] or THEME.Accent
			local kindGlyph = ({ Basic = "o", Shaft = "|", Cross = "+", Shock = "~" })[id] or "*"
			local b = button(chargeColumn, ("[%s] %s"):format(kindGlyph, def.Name), selected and kindColor or THEME.Panel, { Size = UDim2.fromOffset(150, 42), TextSize = 15, LayoutOrder = i, TextColor3 = selected and THEME.Text or Fx.Lighten(kindColor, 0.35) })
			mk("UIStroke", { Color = kindColor, Thickness = selected and 3 or 1.5, Transparency = selected and 0.05 or 0.5 }, b)
			b.Activated:Connect(function()
				AudioManager.Play("Click")
				State.SelectedCharge = id
				State.Changed:Fire("Charge")
			end)
			table.insert(chargeButtons, b)
		end
	end
end

function UI.Refresh()
	if not gui or not State.Data then return end
	local d = State.Data
	seamLabel.Text = ("Charges %d / %d"):format(d.ChargesLeft - #State.Placed, d.ChargesMax)
	local rig = "Rig " .. string.rep("♥", d.Hearts or 0) .. string.rep("♡", math.max(0, (d.HeartsMax or 0) - (d.Hearts or 0)))
	if d.Monster then
		local m = d.Monster
		rig = ("%s\n%s  %d / %d HP%s"):format(rig, m.Name, m.HP, m.MaxHP, m.Warn and "  (smash next turn!)" or "")
	elseif d.Tremor then
		rig = rig .. "\nSomething stirs beneath the rocks..."
	end
	rigLabel.Text = rig
	-- boosts, emergency charges and the revive offer
	local boostBits = {}
	if d.Boosts then
		local passed = os.clock() - (State.EventsAt or os.clock())
		for _, kind in { "Shards", "Luck" } do
			local b = d.Boosts[kind]
			local left = b and (b.Left - passed) or 0
			if left > 0 then
				table.insert(boostBits, ("%sx %s  %d:%02d"):format(tostring(b.Mult), kind == "Shards" and "shards" or "luck", left // 60, left % 60))
			end
		end
	end
	boostLabel.Text = table.concat(boostBits, "   ")
	boostLabel.Visible = #boostBits > 0
	local stock = d.Inventory and d.Inventory.Charge or 0
	chargeButton.Visible = stock > 0 and not (d.Puzzle and d.Puzzle.Active) and (d.ChargesLeft - #State.Placed) <= 1
	chargeButton.Text = ("+1 CHARGE  (%d)"):format(stock)
	reviveModal.Visible = d.AwaitRevive == true
	if d.AwaitRevive then
		reviveText.Text = "THE TUNNEL IS COLLAPSING!\nUse a Revive to keep fighting?"
		reviveYes.Text = ("Use a Revive (%d left)"):format(d.Inventory and d.Inventory.Revive or 0)
	end
	local boss = d.Boss
	bossHud.Update(boss)
	Feed.SetCompact(boss ~= nil)
	Calm.Set(boss ~= nil or State.Run ~= nil)
	dodgeButton.Visible = boss ~= nil
	if boss then
		local shielded = boss.RT and boss.RT.Shielded
		dodgeButton.Text = shielded and "SHIELD UP" or (boss.DodgeReady and "DODGE (Q)" or ("Dodge %ds"):format(math.ceil(boss.DodgeCooldown or 0)))
		dodgeButton.BackgroundColor3 = shielded and Theme.Colors.Success or (boss.DodgeReady and Theme.Colors.Codex or Theme.Colors.Neutral)
	end
	criticalLabel.Visible = (d.Critical or 0) > 0
	if (d.Critical or 0) > 0 then
		criticalLabel.Text = ("CRITICAL MASS  x%d"):format(d.Critical)
	end
	if d.Puzzle and d.Puzzle.Active then
		runLabel.Text = "DAILY PUZZLE\nSame grid for everyone. Basic charges only, ONE volley: plant up to " .. Config.Puzzle.Charges .. ", then detonate."
		runLabel.Visible = true
	elseif not State.Run then
		runLabel.Visible = false
	end

	local found, total = 0, #Config.World.Caches
	for _ in d.Caches or {} do
		found += 1
	end
	cacheLabel.Text = ("Geode caches %d/%d"):format(found, total)

	local claimable = false
	for _, item in d.Dailies or {} do
		if item.Progress >= item.Target and not item.Claimed then
			claimable = true
		end
	end
	for _, g in d.Goals or {} do
		if g.Complete and not g.Claimed then
			claimable = true
		end
	end
	for _, item in d.Weeklies or {} do
		if item.Progress >= item.Target and not item.Claimed then
			claimable = true
		end
	end
	if dock then
		local dailyReady, goalReady = false, false
		for _, list in { d.Dailies or {}, d.Weeklies or {} } do
			for _, item in list do
				if item.Progress >= item.Target and not item.Claimed then dailyReady = true end
			end
		end
		for _, c in d.Contracts or {} do
			if c.Active and c.Progress >= c.Target then dailyReady = true end
		end
		for _, g in d.Goals or {} do
			if g.Complete and not g.Claimed then goalReady = true end
		end
		if d.Streak and d.Streak.CanClaim then dailyReady = true end
		if d.Track and TrackLogic.ClaimableCount({ Xp = d.Track.Xp, Claimed = d.Track.Claimed }, d.Passes and d.Passes.TrackPremium == true, Config.Track) > 0 then goalReady = true end
		dock.SetBadge("Daily", dailyReady)
		dock.SetBadge("Goals", goalReady)
		dock.SetBadge("Farm", d.Farm ~= nil and d.Farm.Pending >= math.max(1, d.Farm.PerHour) ) -- an hour of production is waiting
	end

	-- Live events: one status tile each (icon, name, time left) in the bottom-right corner.
	if statusDock then
		statusDock.SetEvents(d.Events or {}, State.EventsAt)
	end
	UI.RefreshSettings()

	rebuildCharges()
	rebuildPanel()
end

return UI
