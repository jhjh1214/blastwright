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

local UI = {}

local THEME = {
	Bg = Color3.fromRGB(20, 24, 36),
	Panel = Color3.fromRGB(30, 36, 54),
	Row = Color3.fromRGB(40, 48, 72),
	Accent = Color3.fromRGB(90, 200, 255),
	Gold = Color3.fromRGB(255, 205, 90),
	Hot = Color3.fromRGB(255, 120, 50),
	Text = Color3.fromRGB(235, 240, 255),
	Dim = Color3.fromRGB(150, 160, 185),
	Bad = Color3.fromRGB(255, 90, 100),
	Good = Color3.fromRGB(110, 230, 150),
}
local FONT = Enum.Font.GothamBold

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
		Font = FONT,
		Text = text,
		TextSize = size,
		TextColor3 = color or THEME.Text,
		TextStrokeTransparency = 0.6,
	}
	for k, v in props or {} do
		p[k] = v
	end
	return mk("TextLabel", p, parent)
end

local function button(parent, text, color, props)
	local p = {
		AutoButtonColor = true,
		BackgroundColor3 = color,
		Font = FONT,
		Text = text,
		TextSize = 18,
		TextColor3 = THEME.Text,
	}
	for k, v in props or {} do
		p[k] = v
	end
	local b = mk("TextButton", p, parent)
	corner(b, 12)
	return b
end

local function commas(n)
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local eventLabel, communityLabel
local gui, shardLabel, locationLabel, cacheLabel, objectiveCard, objectiveText, blastHint, seamLabel, chainLabel, previewFrame, previewLabel, infoLabel
local welcomeFrame, menuDot, detonateStroke
local detonatePulse = false
local settingButtons = {}
local tabButtons = {}
local toastHolder, tierLabel, chargeColumn, panel, panelScroll, detonateButton
local roamGroup, blastGroup
local runLabel, runModal, runCards, runTitle, runBank, rigLabel
local activeTab = "Forge"
local displayShards = 0
local chargeButtons = {}
local menuButtons = {}
local menuStrokes = {}
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
	gui = mk("ScreenGui", { Name = "BlastwrightUI", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5 }, playerGui)

	-- Always visible: shards (top-left) and toasts / tier banner
	local shardFrame = mk("Frame", { BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.2, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.fromOffset(140, 40) }, gui)
	corner(shardFrame, 12)
	shardLabel = label(shardFrame, "◆ 0", 24, THEME.Gold, { Size = UDim2.fromScale(1, 1) })

	toastHolder = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(440, 120) }, gui)
	mk("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }, toastHolder)

	tierLabel = label(gui, "", 64, THEME.Gold, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(560, 90),
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextScaled = true,
	})
	mk("UISizeConstraint", { MaxSize = Vector2.new(700, 110) }, tierLabel)

	----------------------------------------------------------- roaming HUD
	roamGroup = fullGroup("Roam")
	locationLabel = label(roamGroup, "", 20, THEME.Text, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(320, 28) })
	eventLabel = label(roamGroup, "", 13, THEME.Gold, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 52), Size = UDim2.fromOffset(200, 34), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, Visible = false })
	communityLabel = label(roamGroup, "", 13, THEME.Accent, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 92), Size = UDim2.fromOffset(200, 34), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, Visible = false })
	cacheLabel = label(roamGroup, "", 16, THEME.Dim, { Position = UDim2.new(0, 14, 0, 52), Size = UDim2.fromOffset(170, 22), TextXAlignment = Enum.TextXAlignment.Left })
	objectiveCard = mk("Frame", { BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.2, Position = UDim2.new(0, 12, 0, 80), Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false }, roamGroup)
	corner(objectiveCard, 12)
	mk("UIStroke", { Color = THEME.Gold, Thickness = 2, Transparency = 0.35 }, objectiveCard)
	mk("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, objectiveCard)
	mk("UIListLayout", { Padding = UDim.new(0, 2) }, objectiveCard)
	label(objectiveCard, "OBJECTIVE", 13, THEME.Gold, { Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1 })
	objectiveText = label(objectiveCard, "", 16, THEME.Text, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2 })

	local menu = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(200, 40) }, roamGroup)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8) }, menu)
	-- One Menu button (Forge / Daily / Shop / Codex tabs inside). Objectives pulse it under the name "Forge".
	local menuButton = button(menu, "Menu", THEME.Panel, { Size = UDim2.fromOffset(84, 40), TextSize = 16 })
	menuButtons.Forge = menuButton
	menuStrokes.Forge = mk("UIStroke", { Color = THEME.Gold, Thickness = 3, Enabled = false }, menuButton)
	menuDot = mk("Frame", { BackgroundColor3 = THEME.Bad, Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Visible = false, ZIndex = 3 }, menuButton)
	corner(menuDot, 7)
	menuButton.Activated:Connect(function()
		AudioManager.Play("Click")
		UI.SetPanel(not State.PanelOpen)
	end)
	local help = button(menu, "?", THEME.Panel, { Size = UDim2.fromOffset(36, 40), LayoutOrder = 10 })
	help.Activated:Connect(function()
		AudioManager.Play("Click")
		UI.ShowWelcome(true)
	end)

	----------------------------------------------------------- blast HUD (corners only)
	blastGroup = fullGroup("Blast")
	blastGroup.Visible = false

	local leave = button(blastGroup, "< Leave", THEME.Panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(110, 40) })
	leave.Activated:Connect(function()
		if UI.OnLeave then UI.OnLeave() end
	end)

	runLabel = label(blastGroup, "", 15, THEME.Gold, { Position = UDim2.new(0, 14, 0, 52), Size = UDim2.fromOffset(240, 54), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Visible = false })

	rigLabel = label(blastGroup, "", 16, Color3.fromRGB(255, 130, 130), { Position = UDim2.new(0, 14, 0, 112), Size = UDim2.fromOffset(280, 40), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })

	-- Between-floor choice: three cards and "Bank & leave". Covers the screen while choosing (blasting is paused anyway).
	runModal = mk("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 20, Active = true }, gui)
	runTitle = label(runModal, "", 26, THEME.Gold, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.new(1, -24, 0, 70), TextWrapped = true, Font = Enum.Font.GothamBlack, ZIndex = 21 })
	local row = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 200), ZIndex = 21 }, runModal)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }, row)
	runCards = {}
	for i = 1, 3 do
		local card = button(row, "", THEME.Panel, { Size = UDim2.fromOffset(190, 190), TextSize = 15, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 22, LayoutOrder = i })
		mk("UIStroke", { Color = THEME.Gold, Thickness = 2, Transparency = 0.4 }, card)
		mk("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, card)
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

	seamLabel = label(blastGroup, "", 17, THEME.Dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.fromOffset(340, 24), Visible = false })
	previewFrame = mk("Frame", { BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.new(1, -24, 0, 30), Visible = false }, blastGroup)
	corner(previewFrame, 10)
	mk("UISizeConstraint", { MaxSize = Vector2.new(440, 30) }, previewFrame)
	previewLabel = label(previewFrame, "", 17, THEME.Text, { Size = UDim2.fromScale(1, 1), TextScaled = true })
	mk("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 13 }, previewLabel)
	infoLabel = label(blastGroup, "", 14, THEME.Dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.45, TextWrapped = true, Visible = false, TextYAlignment = Enum.TextYAlignment.Center })
	corner(infoLabel, 10)
	mk("UISizeConstraint", { MaxSize = Vector2.new(440, 44) }, infoLabel)
	mk("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 12 }, infoLabel)
	chainLabel = label(blastGroup, "", 40, THEME.Hot, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(340, 52), Font = Enum.Font.GothamBlack })

	chargeColumn = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(150, 180) }, blastGroup)
	mk("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, chargeColumn)
	local clear = button(chargeColumn, "Clear", THEME.Row, { Size = UDim2.fromOffset(150, 42), LayoutOrder = 100 })
	clear.Activated:Connect(function()
		if UI.OnClear then UI.OnClear() end
	end)

	detonateButton = button(blastGroup, "DETONATE", THEME.Hot, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(190, 62), TextSize = 26, Font = Enum.Font.GothamBlack })
	detonateStroke = mk("UIStroke", { Color = THEME.Gold, Thickness = 4, Enabled = false }, detonateButton)
	detonateButton.Activated:Connect(function()
		if UI.OnDetonate then UI.OnDetonate() end
	end)

	----------------------------------------------------------- Forge / Codex panel
	panel = mk("Frame", { BackgroundColor3 = THEME.Bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.92, 0, 0.78, 0), Visible = false, ZIndex = 10 }, gui)
	corner(panel, 16)
	mk("UISizeConstraint", { MaxSize = Vector2.new(560, 460) }, panel)
	mk("UIStroke", { Color = THEME.Accent, Thickness = 2, Transparency = 0.4 }, panel)
	label(panel, "", 26, THEME.Text, { Name = "Title", Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 })
	local close = button(panel, "X", THEME.Row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(48, 48), ZIndex = 11 })
	close.Activated:Connect(function()
		UI.SetPanel(false)
	end)
	local tabBar = mk("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 42), ZIndex = 11 }, panel)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
	for i, name in { "Forge", "Daily", "Farm", "Goals", "Shop", "Codex" } do
		local tab = button(tabBar, name, THEME.Row, { Size = UDim2.new(1 / 6, -5, 1, 0), TextSize = 14, LayoutOrder = i, ZIndex = 12 })
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
		Position = UDim2.fromOffset(12, 108),
		Size = UDim2.new(1, -24, 1, -120),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, panel)
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panelScroll)

	-- Welcome / how-to-play panel
	welcomeFrame = mk("Frame", { BackgroundColor3 = THEME.Bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.92, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 20 }, gui)
	corner(welcomeFrame, 16)
	mk("UISizeConstraint", { MaxSize = Vector2.new(460, 9999) }, welcomeFrame)
	mk("UIStroke", { Color = THEME.Gold, Thickness = 2, Transparency = 0.3 }, welcomeFrame)
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

	local go = button(welcomeFrame, "Let's go", THEME.Accent, { Size = UDim2.fromOffset(180, 48), TextSize = 20, TextColor3 = THEME.Bg, LayoutOrder = 20, ZIndex = 21 })
	go.Activated:Connect(function()
		AudioManager.Play("Click")
		UI.ShowWelcome(false)
	end)

	-- Pulse the highlighted menu button
	RunService.Heartbeat:Connect(function()
		local pulse = 0.15 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 6))
		if highlighted and menuStrokes[highlighted] then
			menuStrokes[highlighted].Transparency = pulse
		end
		if detonatePulse and detonateStroke then
			detonateStroke.Transparency = pulse
		end
	end)

	-- Shard count-up
	RunService.Heartbeat:Connect(function(dt)
		local target = State.Data and State.Data.Shards or 0
		if math.abs(target - displayShards) < 0.5 then
			displayShards = target
		else
			displayShards += (target - displayShards) * math.min(1, dt * 5)
		end
		shardLabel.Text = "◆ " .. commas(displayShards)
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
	if not runLabel then return end
	if not view then
		runLabel.Visible = false
		runModal.Visible = false
		return
	end
	runLabel.Text = ("EXPEDITION  floor %d / %d\nHaul %s  |  Relics %d"):format(view.Floor, view.Floors, commas(view.Haul), #view.Relics)
	runLabel.Visible = true
	local choosing = view.Phase == "Choosing"
	runModal.Visible = choosing
	if choosing then
		runTitle.Text = ("Floor %d cleared!  Haul %s. Choose your next step."):format(view.Floor, commas(view.Haul))
		for i, card in runCards do
			local c = view.Choices[i]
			card.Visible = c ~= nil
			if c then
				card.Text = ("%s\n%s\n\n+ %s\n%s"):format(c.RouteName, c.RouteDescription, c.RelicName ~= "" and c.RelicName or "(no relic)", c.RelicDescription)
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
	end
end

-- Pulse a menu button ("Forge") to draw the eye; nil clears.
function UI.SetHighlight(name)
	if highlighted == name then return end
	if highlighted and menuStrokes[highlighted] then
		menuStrokes[highlighted].Enabled = false
	end
	highlighted = name
	if name and menuStrokes[name] then
		menuStrokes[name].Enabled = true
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
		entry.Button.TextColor3 = on and THEME.Bg or THEME.Text
	end
end

function UI.ShowWelcome(show)
	if welcomeFrame then
		welcomeFrame.Visible = show
	end
end

function UI.SetLocation(text)
	if locationLabel then
		locationLabel.Text = text
	end
end

function UI.SetPreview(text)
	if previewLabel then
		previewLabel.Text = text
		previewFrame.Visible = text ~= ""
	end
end

-- Second preview line (crystal description, legend). "" hides it.
function UI.SetInfo(text)
	if infoLabel then
		infoLabel.Text = text
		infoLabel.Visible = text ~= nil and text ~= ""
	end
end

-- Shared Server Goal line (roaming HUD). view = { Round, Progress, Target, Done, FrenzyLeft } or nil.
function UI.SetCommunity(view, receivedAt)
	if not communityLabel then return end
	if not view then
		communityLabel.Visible = false
		return
	end
	local frenzy = math.max(0, view.FrenzyLeft - (os.clock() - (receivedAt or os.clock())))
	local text
	if frenzy > 0 then
		text = ("Server frenzy! Payouts boosted for %d:%02d"):format(frenzy // 60, frenzy % 60)
	elseif view.Done then
		text = "Server goal reached! Next one starting..."
	else
		text = ("Server goal: %s / %s pops together"):format(commas(view.Progress), commas(view.Target))
	end
	communityLabel.Text = text
	communityLabel.Visible = true
end

function UI.SetChain(pops, mult)
	if not chainLabel then return end
	if pops <= 0 then
		chainLabel.Text = ""
		return
	end
	chainLabel.Text = ("CHAIN %d   x%.1f"):format(pops, mult)
	chainLabel.TextSize = 36
	TweenService:Create(chainLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 42 }):Play()
end

function UI.ShowTier(name, bonus, total)
	AudioManager.Play("Tier")
	tierLabel.Text = name:upper() .. "!"
	tierLabel.TextTransparency = 0
	tierLabel.TextStrokeTransparency = 0.3
	tierLabel.Rotation = -4
	tierLabel.Position = UDim2.fromScale(0.5, 0.4)
	TweenService:Create(tierLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.34), Rotation = 0 }):Play()
	task.delay(1.4, function()
		TweenService:Create(tierLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

function UI.Toast(text, kind)
	if not toastHolder then return end
	local color = kind == "Reward" and THEME.Gold or (kind == "Error" and THEME.Bad or THEME.Text)
	local t = label(toastHolder, text, 19, color, { Size = UDim2.new(1, 0, 0, 26), TextTransparency = 1 })
	TweenService:Create(t, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	AudioManager.Play(kind == "Error" and "Error" or "Reward")
	task.delay(2.8, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.45, function() t:Destroy() end)
	end)
end

local function row(order, titleText, desc, buttonText, enabled, onClick, titleColor)
	local f = mk("Frame", { BackgroundColor3 = THEME.Row, Size = UDim2.new(1, -8, 0, 76), LayoutOrder = order, ZIndex = 11 }, panelScroll)
	corner(f, 12)
	label(f, titleText, 19, titleColor or THEME.Text, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 })
	label(f, desc, 15, THEME.Dim, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -150, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, ZIndex = 12 })
	if buttonText then
		local b = button(f, buttonText, enabled and THEME.Accent or THEME.Panel, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 52), TextSize = 16, ZIndex = 12, TextColor3 = enabled and THEME.Bg or THEME.Dim })
		b.Activated:Connect(function()
			if onClick then onClick() end
		end)
	end
	return f
end

local function header(order, text)
	label(panelScroll, text, 18, THEME.Accent, { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 })
end

local function rebuildPanel()
	if not panel.Visible or not State.Data then return end
	for _, c in panelScroll:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local d = State.Data
	local titleLabel = panel:FindFirstChild("Title")
	for name, tab in tabButtons do
		local selected = name == activeTab
		tab.BackgroundColor3 = selected and THEME.Accent or THEME.Row
		tab.TextColor3 = selected and THEME.Bg or THEME.Text
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
			end)
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
				end)
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
			end)
		end
	elseif activeTab == "Daily" then
		titleLabel.Text = "Daily objectives"
		local secs = math.max(0, math.floor((State.DailyResetAt or 0) - os.clock()))
		header(0, ("Resets in %dh %02dm (unclaimed rewards are lost)"):format(secs // 3600, (secs % 3600) // 60))
		for _, item in d.Dailies or {} do
			local done = item.Progress >= item.Target
			local btnText = item.Claimed and "Claimed" or (done and ("Claim  ◆ " .. commas(item.Reward)) or ("%d / %d"):format(item.Progress, item.Target))
			row(item.Slot, item.Text, ("Reward: ◆ %s"):format(commas(item.Reward)), btnText, done and not item.Claimed, function()
				if done and not item.Claimed then Remotes.Claim:FireServer(item.Slot) end
			end)
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
			end)
		end
		-- Weekly challenges: bigger targets and rewards, reset Monday 00:00 UTC.
		local weekSecs = math.max(0, math.floor((State.WeeklyResetAt or 0) - os.clock()))
		header(10, ("Weekly challenges: reset in %dd %02dh (unclaimed rewards are lost)"):format(weekSecs // 86400, (weekSecs % 86400) // 3600))
		for _, item in d.Weeklies or {} do
			local done = item.Progress >= item.Target
			local btnText = item.Claimed and "Claimed" or (done and ("Claim  ◆ " .. commas(item.Reward)) or ("%s / %s"):format(commas(item.Progress), commas(item.Target)))
			row(10 + item.Slot, item.Text, ("Reward: ◆ %s"):format(commas(item.Reward)), btnText, done and not item.Claimed, function()
				if done and not item.Claimed then Remotes.ClaimWeekly:FireServer(item.Slot) end
			end)
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
		-- Ready to claim first, then in progress, then already claimed.
		local function addRows(filter)
			for _, g in goals do
				if filter(g) then
					order += 1
					local btnText = g.Claimed and "Claimed" or (g.Complete and ("Claim  ◆ " .. commas(g.Reward)) or ("%s / %s"):format(commas(g.Progress), commas(g.Target)))
					row(order, g.Name, g.Description .. ("  Reward: ◆ %s"):format(commas(g.Reward)), btnText, g.Complete and not g.Claimed, function()
						if g.Complete and not g.Claimed then Remotes.ClaimGoal:FireServer(g.Id) end
					end, g.Claimed and THEME.Dim or nil)
				end
			end
		end
		addRows(function(g) return g.Complete and not g.Claimed end)
		addRows(function(g) return not g.Complete end)
		addRows(function(g) return g.Claimed end)
	elseif activeTab == "Shop" then
		titleLabel.Text = "Shop"
		local order = 0
		header(order, "Permanent perks")
		for _, key in Products.GamepassOrder do
			order += 1
			local def = Products.Gamepasses[key]
			local owned = d.Passes and d.Passes[key]
			local btnText = owned and "Owned" or (def.Id and "Buy" or "Not for sale yet")
			row(order, def.Name, def.Description, btnText, (not owned) and def.Id ~= nil, function()
				if def.Id and not owned then MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, def.Id) end
			end)
		end
		order += 1
		header(order, "Blast colors")
		for _, key in Products.CosmeticProductOrder do
			order += 1
			local def = Products.CosmeticProducts[key]
			local owned = false
			for _, style in d.Styles or {} do
				if style.Id == def.Cosmetic and style.Owned then owned = true end
			end
			row(order, def.Name, def.Description, owned and "Owned" or (def.Id and "Buy" or "Not for sale yet"), (not owned) and def.Id ~= nil, function()
				if def.Id and not owned then MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.Id) end
			end)
		end
		order += 1
		header(order, "Shard packs (amount x areas unlocked)")
		for _, key in Products.DeveloperProductOrder do
			order += 1
			local def = Products.DeveloperProducts[key]
			row(order, ("%s  +%s"):format(def.Name, commas(def.Amount * math.max(1, d.StrataUnlocked))), def.Description, def.Id and "Buy" or "Not for sale yet", def.Id ~= nil, function()
				if def.Id then MarketplaceService:PromptProductPurchase(Players.LocalPlayer, def.Id) end
			end)
		end
		order += 1
		header(order, "Everything is earnable by playing. The shop only saves time.")
	else
		titleLabel.Text = "Codex"
		local found = 0
		for index, id in Config.Crystals.Order do
			local def = Config.Crystals.Defs[id]
			local known = d.Codex.Discovered[id]
			if known then found += 1 end
			local rc = Config.Rarities.Info[def.Rarity].Color
			local mut = d.Codex.Mutated[id] and "   Prismatic found" or ""
			row(index, known and (def.Name .. "  (" .. def.Rarity .. ")" .. mut) or "???", known and def.Description or ("Found in stratum " .. def.Stratum), nil, false, nil, known and Color3.fromRGB(rc[1], rc[2], rc[3]) or THEME.Dim)
		end
		-- Blast colors: owned styles can be equipped; locked ones say how to get them.
		local order = #Config.Crystals.Order + 1
		header(order, "Blast colors")
		for _, style in d.Styles or {} do
			order += 1
			local c = style.Color
			local btnText = style.Equipped and "Equipped" or (style.Owned and "Equip" or "Locked")
			row(order, style.Name, style.Owned and "Owned" or style.Unlock, btnText, style.Owned and not style.Equipped, function()
				if style.Owned and not style.Equipped then Remotes.Equip:FireServer(style.Id) end
			end, Color3.fromRGB(c[1], c[2], c[3]))
		end
		titleLabel.Text = ("Codex  %d/%d"):format(found, #Config.Crystals.Order)
	end
end

function UI.SetPanel(open, tab)
	activeTab = tab or activeTab
	State.PanelOpen = open
	panel.Visible = open
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
			local b = button(chargeColumn, def.Name, selected and THEME.Accent or THEME.Panel, { Size = UDim2.fromOffset(150, 42), TextSize = 15, LayoutOrder = i, TextColor3 = selected and THEME.Bg or THEME.Text })
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
	if d.Puzzle and d.Puzzle.Active then
		runLabel.Text = "DAILY PUZZLE\nSame grid for everyone. Basic charges only, ONE volley: plant up to " .. Config.Puzzle.Charges .. ", then detonate."
		runLabel.Size = UDim2.fromOffset(300, 70)
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
	menuDot.Visible = claimable

	-- Live event banner (first active event; "+N" if there are more).
	local events = d.Events or {}
	if #events > 0 then
		local first = events[1]
		local left = math.max(0, first.EndsIn - (os.clock() - (State.EventsAt or os.clock())))
		local when = left >= 3600 and ("%dh %02dm"):format(left // 3600, (left % 3600) // 60) or ("%dm"):format(math.ceil(left / 60))
		eventLabel.Text = ("★ %s: %s (ends in %s)%s"):format(first.Name, first.Description, when, #events > 1 and (" +" .. (#events - 1) .. " more") or "")
		eventLabel.Visible = true
	else
		eventLabel.Visible = false
	end
	UI.RefreshSettings()

	rebuildCharges()
	rebuildPanel()
end

return UI
