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
		ClipsDescendants = true, -- rows above/below the visible window must never show through; explicit, not just relied on
		ZIndex = 11,
	}, kitPanel.Body)
	kitPanel.Body.ClipsDescendants = true
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
}

-- Chain tiers and Critical Mass: quick, frequent, passing banners (never a closable window, they would interrupt play).
function UI.ShowTier(name, bonus, total)
	AudioManager.Play("Tier")
	local key = string.lower(name)
	local color = BANNER_COLORS[key] or (key:find("phase") and Color3.fromRGB(210, 92, 92)) or THEME.Gold
	local subtitle = (bonus and bonus > 0) and ("+%d%% chain bonus"):format(math.floor(bonus * 100 + 0.5)) or nil
	if key == "critical mass" then
		subtitle = "Damage and shards up for the next volleys"
	end
	Feed.Banner(string.upper(name), subtitle, color)
end

-- Messages go to the feed on the right. "Threat" messages (boss wind-ups) are shown by the boss panel instead, so they only make a sound.
function UI.ShowReward(title, text, icon, color, sub)
	Kit.Popup(gui, { Title = title, Text = text, Icon = icon, Color = color, Sub = sub })
end

-- A boss kill is a big moment: a full window, not a passing banner, so it never overlaps another card and is always
-- closable at once (tap it or press CONTINUE) instead of waiting for it to fade. Queues with any Mastery reward popup
-- landing at the same instant (Kit.Popup), so only one full-window card is ever on screen.
function UI.ShowBossDefeated(bossName)
	AudioManager.Play("Tier")
	Kit.Popup(gui, { Title = "VICTORY!", Text = string.upper(bossName) .. " DEFEATED", Sub = "Final blast!", Icon = "Bomb", Color = Color3.fromRGB(240, 196, 70), CloseText = "CONTINUE", Hold = 6 })
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

local TABS = {
	Forge = require(script.Parent.Tabs.Forge),
	Loadout = require(script.Parent.Tabs.Loadout),
	Daily = require(script.Parent.Tabs.Daily),
	Farm = require(script.Parent.Tabs.Farm),
	Goals = require(script.Parent.Tabs.Goals),
	Shop = require(script.Parent.Tabs.Shop),
	Codex = require(script.Parent.Tabs.Codex),
}

-- Forward-declared so rebuildPanel (defined next) can pass it to tabs that need to ask for a refresh later (a product
-- icon arriving from Roblox, for example): the real function is assigned further down, before anything can call it.
local requestRebuild
local lastRenderedTab = nil
local function rebuildPanel()
	if not panel.Visible or not State.Data then return end
	local keepScroll = lastRenderedTab == activeTab and panelScroll.CanvasPosition or Vector2.zero -- a refresh keeps your place in the list
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

	local build = TABS[activeTab] or TABS.Codex
	build({ d = d, titleLabel = titleLabel, row = row, header = header, label = label, mk = mk, corner = corner, commas = commas, THEME = THEME, button = button, panel = panel, panelScroll = panelScroll, refresh = function() if lastRenderedTab == activeTab then requestRebuild() end end })
	lastRenderedTab = activeTab
	-- Grids and lists finish sizing themselves a frame or two after their children appear (AutomaticSize/AutomaticCanvasSize),
	-- so restoring the scroll position right away can land past the real content and expose a card from the wrong end. Wait
	-- for the canvas to stop growing, then clamp to it, instead of trusting the canvas size on the very next frame.
	local mine = lastRenderedTab
	task.spawn(function()
		local settled = panelScroll.AbsoluteCanvasSize.Y
		for _ = 1, 6 do
			task.wait()
			if lastRenderedTab ~= mine or not panel.Visible then
				return
			end
			local now = panelScroll.AbsoluteCanvasSize.Y
			if now == settled then
				break
			end
			settled = now
		end
		local maxY = math.max(0, panelScroll.AbsoluteCanvasSize.Y - panelScroll.AbsoluteWindowSize.Y)
		panelScroll.CanvasPosition = Vector2.new(0, math.clamp(keepScroll.Y, 0, maxY))
	end)
end

-- Snapshots can arrive in quick bursts (a volley, a claim, a purchase). Rebuilding the whole list for each one wastes work and
-- flickers, so refreshes are coalesced to at most one every 0.3 s. Opening a tab (SetPanel) still rebuilds immediately.
local lastRebuild, rebuildQueued = 0, false
function requestRebuild()
	if not panel or not panel.Visible then
		return
	end
	local wait = 0.3 - (os.clock() - lastRebuild)
	if wait <= 0 then
		lastRebuild = os.clock()
		rebuildPanel()
	elseif not rebuildQueued then
		rebuildQueued = true
		task.delay(wait, function()
			rebuildQueued = false
			lastRebuild = os.clock()
			rebuildPanel()
		end)
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
	requestRebuild()
end

return UI
