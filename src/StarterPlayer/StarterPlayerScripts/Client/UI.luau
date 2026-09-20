--!nonstrict
-- All HUD and menus, built in code. Touch-first: every button is at least 48px tall.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local AudioManager = require(script.Parent.AudioManager)
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
		TextSize = 20,
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

local gui, shardLabel, seamLabel, chainLabel, previewLabel, toastHolder, tierLabel
local chargeRow, panel, panelScroll, detonateButton
local activeTab = "Forge"
local displayShards = 0
local chargeButtons = {}

-- Callbacks provided by Input
UI.OnDetonate = nil
UI.OnClear = nil

function UI.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = mk("ScreenGui", { Name = "BlastwrightUI", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5 }, playerGui)

	-- Shards (top left)
	local shardFrame = mk("Frame", { BackgroundColor3 = THEME.Bg, BackgroundTransparency = 0.15, Position = UDim2.new(0, 12, 0, 8), Size = UDim2.fromOffset(190, 46) }, gui)
	corner(shardFrame, 12)
	shardLabel = label(shardFrame, "◆ 0", 26, THEME.Gold, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })

	-- Seam info (top center)
	seamLabel = label(gui, "", 18, THEME.Dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(300, 28) })

	-- Live chain readout
	chainLabel = label(gui, "", 44, THEME.Hot, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(340, 60), Font = Enum.Font.GothamBlack })

	-- Tier banner
	tierLabel = label(gui, "", 64, THEME.Gold, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(560, 90),
		Font = Enum.Font.GothamBlack,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		TextScaled = true,
	})
	mk("UISizeConstraint", { MaxSize = Vector2.new(700, 110) }, tierLabel)

	-- Toasts
	toastHolder = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(420, 120) }, gui)
	mk("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }, toastHolder)

	-- Bottom controls
	previewLabel = label(gui, "", 20, THEME.Text, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128), Size = UDim2.fromOffset(420, 30) })

	chargeRow = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.fromOffset(420, 44) }, gui)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8) }, chargeRow)

	local bottom = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(420, 58) }, gui)
	mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }, bottom)
	local clear = button(bottom, "Clear", THEME.Row, { Size = UDim2.fromOffset(100, 54), LayoutOrder = 1 })
	detonateButton = button(bottom, "DETONATE", THEME.Hot, { Size = UDim2.fromOffset(220, 58), TextSize = 26, LayoutOrder = 2, Font = Enum.Font.GothamBlack })
	clear.Activated:Connect(function()
		if UI.OnClear then UI.OnClear() end
	end)
	detonateButton.Activated:Connect(function()
		if UI.OnDetonate then UI.OnDetonate() end
	end)

	-- Right-side menu buttons
	local side = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(110, 110) }, gui)
	mk("UIListLayout", { Padding = UDim.new(0, 8) }, side)
	for _, name in { "Forge", "Codex" } do
		local b = button(side, name, THEME.Panel, { Size = UDim2.fromOffset(110, 48) })
		b.Activated:Connect(function()
			AudioManager.Play("Click")
			local sameTabOpen = State.PanelOpen and activeTab == name
			UI.SetPanel(not sameTabOpen, name)
		end)
	end

	-- Forge / Codex panel
	panel = mk("Frame", { BackgroundColor3 = THEME.Bg, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.92, 0, 0.78, 0), Visible = false, ZIndex = 10 }, gui)
	corner(panel, 16)
	mk("UISizeConstraint", { MaxSize = Vector2.new(560, 460) }, panel)
	mk("UIStroke", { Color = THEME.Accent, Thickness = 2, Transparency = 0.4 }, panel)
	label(panel, "", 26, THEME.Text, { Name = "Title", Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 40), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 11 })
	local close = button(panel, "X", THEME.Row, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(48, 48), ZIndex = 11 })
	close.Activated:Connect(function()
		UI.SetPanel(false)
	end)
	panelScroll = mk("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 60),
		Size = UDim2.new(1, -24, 1, -72),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, panel)
	mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, panelScroll)

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

function UI.SetPreview(text)
	if previewLabel then
		previewLabel.Text = text
	end
end

function UI.SetChain(pops, mult)
	if not chainLabel then return end
	if pops <= 0 then
		chainLabel.Text = ""
		return
	end
	chainLabel.Text = ("CHAIN %d   x%.1f"):format(pops, mult)
	chainLabel.TextSize = 40
	TweenService:Create(chainLabel, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 46 }):Play()
end

function UI.ShowTier(name, bonus, total)
	AudioManager.Play("Tier")
	tierLabel.Text = name:upper() .. "!"
	tierLabel.TextTransparency = 0
	tierLabel.TextStrokeTransparency = 0.3
	tierLabel.Rotation = -4
	tierLabel.Position = UDim2.fromScale(0.5, 0.46)
	TweenService:Create(tierLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.4), Rotation = 0 }):Play()
	task.delay(1.4, function()
		TweenService:Create(tierLabel, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

function UI.Toast(text, kind)
	if not toastHolder then return end
	local color = kind == "Reward" and THEME.Gold or (kind == "Error" and THEME.Bad or THEME.Text)
	local t = label(toastHolder, text, 20, color, { Size = UDim2.new(1, 0, 0, 28), TextTransparency = 1 })
	TweenService:Create(t, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	AudioManager.Play(kind == "Error" and "Error" or "Reward")
	task.delay(2.6, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.45, function() t:Destroy() end)
	end)
end

local function row(order, titleText, desc, buttonText, enabled, onClick, titleColor)
	local f = mk("Frame", { BackgroundColor3 = THEME.Row, Size = UDim2.new(1, -8, 0, 76), LayoutOrder = order, ZIndex = 11 }, panelScroll)
	corner(f, 12)
	label(f, titleText, 20, titleColor or THEME.Text, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12 })
	label(f, desc, 15, THEME.Dim, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -150, 0, 38), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, ZIndex = 12 })
	if buttonText then
		local b = button(f, buttonText, enabled and THEME.Accent or THEME.Panel, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 52), TextSize = 17, ZIndex = 12, TextColor3 = enabled and THEME.Bg or THEME.Dim })
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
		header(order, "Strata")
		for n, s in Config.Strata do
			order += 1
			local unlocked = n <= d.StrataUnlocked
			local text = unlocked and (d.ActiveStratum == n and "Active" or "Select") or ("Unlock  ◆ " .. commas(s.Cost))
			local can = (unlocked and d.ActiveStratum ~= n) or (n == d.StrataUnlocked + 1 and d.Shards >= s.Cost)
			row(order, ("%d. %s"):format(n, s.Name), s.Description, text, can, function()
				Remotes.Buy:FireServer("Stratum", tostring(n))
			end)
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
			row(index, known and (def.Name .. "  (" .. def.Rarity .. ")" .. mut) or "???", known and def.Description or ("Found in stratum " .. def.Stratum), nil, false, nil, known and Color3.fromRGB(rc[1], rc[2], rc[3]) or THEME.Dim)
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
			local b = button(chargeRow, def.Name, selected and THEME.Accent or THEME.Panel, { Size = UDim2.fromOffset(150, 44), TextSize = 16, LayoutOrder = i, TextColor3 = selected and THEME.Bg or THEME.Text })
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
	local stratumName = Config.Strata[d.ActiveStratum] and Config.Strata[d.ActiveStratum].Name or ""
	seamLabel.Text = ("%s   |   Charges %d/%d"):format(stratumName, d.ChargesLeft - #State.Placed, d.ChargesMax)
	rebuildCharges()
	rebuildPanel()
end

return UI
