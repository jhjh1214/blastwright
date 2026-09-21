--!nonstrict
-- The boss fight HUD, laid out so it can be read at a glance:
--   1. a header plate: name, health bar, the five phases as labelled pips (where you are), and ONE line saying what to do now;
--   2. a row of threat cards, one per wound-up attack: what it is, a countdown with a draining bar, and the one-line answer
--      ("pop 3+ crystals on the red line", "pop a Lensglass", "pop the purple crystals"), turning green once it is stopped.
-- Flat dark plates, display font for names and numbers, plain body text. The boss's attacks are ALSO drawn on the grid
-- (CavernView); this is the place that explains them.
local BossHud = {}

local DISPLAY = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSans
local BODY_BOLD = Enum.Font.BuilderSansBold

local PHASES = { "Armor", "Attack", "Weak", "Enrage", "Finisher" }
local PHASE_COLOR = {
	Armor = Color3.fromRGB(240, 190, 60),
	Attack = Color3.fromRGB(232, 92, 84),
	Weak = Color3.fromRGB(226, 90, 200),
	Enrage = Color3.fromRGB(236, 56, 56),
	Finisher = Color3.fromRGB(96, 214, 230),
}
BossHud.PhaseColor = PHASE_COLOR

local THREATS = {
	Slam = { Title = "SLAM", Glyph = "S", Color = Color3.fromRGB(232, 92, 84), Answer = "Pop 3+ crystals on the red line, or Dodge." },
	Meteor = { Title = "METEORS", Glyph = "M", Color = Color3.fromRGB(240, 146, 56), Answer = "Pop a Lensglass to deflect them, or Dodge." },
	Corruption = { Title = "CORRUPTION", Glyph = "C", Color = Color3.fromRGB(170, 100, 236), Answer = "Pop the purple crystals before it lands." },
}

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function objective(boss, config)
	local def = config.Defs[boss.Kind]
	if boss.Phase == "Armor" then
		return ("Break the %d gold armor nodes"):format(#boss.Nodes)
	elseif boss.Phase == "Attack" or boss.Phase == "Enrage" then
		return "Hit the core in the middle of the grid"
	elseif boss.Phase == "Weak" then
		return "Chain through BOTH pink weak points"
	elseif boss.Phase == "Finisher" then
		return ("One huge chain (%d+ pops) or Critical Mass finishes it"):format(def.Finisher.Pops)
	end
	return ""
end

BossHud.Objective = objective

-- parent: the blast HUD group. config: Config.Bosses.
function BossHud.Build(parent, config)
	local plate = make("Frame", { Name = "BossHeader", BackgroundColor3 = Color3.fromRGB(18, 20, 33), BackgroundTransparency = 0.05, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56), Size = UDim2.fromOffset(460, 98), Visible = false, BorderSizePixel = 0, ZIndex = 8 }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, plate)
	make("UIStroke", { Color = Color3.fromRGB(70, 78, 110), Thickness = 1, Transparency = 0.3 }, plate)
	local scale = make("UIScale", { Scale = 1 }, plate)
	local rule = make("Frame", { BackgroundColor3 = PHASE_COLOR.Attack, Size = UDim2.new(1, 0, 0, 5), BorderSizePixel = 0, ZIndex = 9 }, plate)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, rule)

	local nameLabel = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 9), Size = UDim2.new(0.6, 0, 0, 26), Font = DISPLAY, Text = "", TextSize = 23, TextColor3 = Color3.fromRGB(246, 247, 252), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 }, plate)
	local phaseTag = make("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 13), Size = UDim2.new(0.4, 0, 0, 20), Font = BODY_BOLD, Text = "", TextSize = 15, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9 }, plate)

	local back = make("Frame", { BackgroundColor3 = Color3.fromRGB(38, 42, 62), Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 16), BorderSizePixel = 0, ZIndex = 9 }, plate)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, back)
	local fill = make("Frame", { BackgroundColor3 = PHASE_COLOR.Attack, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 10 }, back)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, fill)
	local hpText = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = BODY_BOLD, Text = "", TextSize = 13, TextColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, back)

	local pips = {}
	local pipRow = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 62), Size = UDim2.new(1, -32, 0, 16), ZIndex = 9 }, plate)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, pipRow)
	for i, name in PHASES do
		local pip = make("TextLabel", { BackgroundColor3 = Color3.fromRGB(38, 42, 62), Size = UDim2.new(0.2, -3.2, 1, 0), Font = BODY_BOLD, Text = string.upper(name), TextSize = 11, TextColor3 = Color3.fromRGB(120, 128, 155), BorderSizePixel = 0, LayoutOrder = i, ZIndex = 10 }, pipRow)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, pip)
		pips[name] = pip
	end

	local goal = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 78), Size = UDim2.new(1, -32, 0, 16), Font = BODY_BOLD, Text = "", TextSize = 14, TextColor3 = Color3.fromRGB(214, 220, 238), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 }, plate)

	local row = make("Frame", { Name = "Threats", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 162), Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, Visible = false, ZIndex = 8 }, parent)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, row)

	local function fit()
		local width = parent.AbsoluteSize.X
		if width > 0 then
			scale.Scale = math.clamp((width - 24) / 460, 0.6, 1)
		end
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local cards = {} -- [threatId] = { Frame, Count, Bar, LandsAt, Total, Cancelled }
	local hud = {}

	local function makeCard(threat)
		local info = THREATS[threat.Type]
		local card = make("Frame", { BackgroundColor3 = Color3.fromRGB(18, 20, 33), BackgroundTransparency = 0.05, Size = UDim2.fromOffset(214, 82), BorderSizePixel = 0, LayoutOrder = threat.Id, ZIndex = 8 }, row)
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
		make("UIStroke", { Color = Color3.fromRGB(70, 78, 110), Thickness = 1, Transparency = 0.3 }, card)
		local bar = make("Frame", { Name = "Edge", BackgroundColor3 = info.Color, Size = UDim2.new(0, 5, 1, 0), BorderSizePixel = 0, ZIndex = 9 }, card)
		make("UICorner", { CornerRadius = UDim.new(0, 12) }, bar)
		local tile = make("Frame", { BackgroundColor3 = info.Color, Position = UDim2.fromOffset(14, 9), Size = UDim2.fromOffset(32, 32), BorderSizePixel = 0, ZIndex = 9 }, card)
		make("UICorner", { CornerRadius = UDim.new(0, 9) }, tile)
		make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = DISPLAY, Text = info.Glyph, TextSize = 19, TextColor3 = Color3.fromRGB(26, 24, 38), ZIndex = 10 }, tile)
		local title = make("TextLabel", { Name = "Title", BackgroundTransparency = 1, Position = UDim2.fromOffset(54, 8), Size = UDim2.new(1, -110, 0, 18), Font = DISPLAY, Text = info.Title, TextSize = 16, TextColor3 = Color3.fromRGB(246, 247, 252), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 }, card)
		local count = make("TextLabel", { Name = "Count", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(56, 28), Font = DISPLAY, Text = "", TextSize = 24, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9 }, card)
		local track = make("Frame", { BackgroundColor3 = Color3.fromRGB(38, 42, 62), Position = UDim2.fromOffset(54, 30), Size = UDim2.new(1, -66, 0, 6), BorderSizePixel = 0, ZIndex = 9 }, card)
		make("UICorner", { CornerRadius = UDim.new(0, 3) }, track)
		local fillBar = make("Frame", { Name = "Fill", BackgroundColor3 = info.Color, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 10 }, track)
		make("UICorner", { CornerRadius = UDim.new(0, 3) }, fillBar)
		local answer = make("TextLabel", { Name = "Answer", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 46), Size = UDim2.new(1, -24, 0, 30), Font = BODY, Text = info.Answer, TextSize = 13, TextColor3 = Color3.fromRGB(190, 198, 220), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 9 }, card)
		return { Frame = card, Count = count, Fill = fillBar, Title = title, Edge = bar, Answer = answer, Info = info }
	end

	-- Called with the boss view (Boss.View + RT) whenever a snapshot arrives; nil hides everything.
	function hud.Update(boss)
		if not boss then
			plate.Visible = false
			row.Visible = false
			for id, c in cards do
				c.Frame:Destroy()
				cards[id] = nil
			end
			return
		end
		plate.Visible = true
		local color = PHASE_COLOR[boss.Phase] or PHASE_COLOR.Attack
		rule.BackgroundColor3 = color
		fill.BackgroundColor3 = color
		nameLabel.Text = boss.Name
		local index = table.find(PHASES, boss.Phase) or 1
		phaseTag.Text = ("PHASE %d OF %d"):format(index, #PHASES)
		phaseTag.TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
		fill.Size = UDim2.fromScale(math.clamp(boss.HP / boss.MaxHP, 0, 1), 1)
		hpText.Text = ("%d / %d"):format(boss.HP, boss.MaxHP)
		for i, name in PHASES do
			local pip = pips[name]
			if i == index then
				pip.BackgroundColor3 = color
				pip.TextColor3 = Color3.fromRGB(24, 22, 36)
			elseif i < index then
				pip.BackgroundColor3 = color:Lerp(Color3.fromRGB(38, 42, 62), 0.7)
				pip.TextColor3 = Color3.fromRGB(170, 178, 200)
			else
				pip.BackgroundColor3 = Color3.fromRGB(38, 42, 62)
				pip.TextColor3 = Color3.fromRGB(120, 128, 155)
			end
		end
		goal.Text = objective(boss, config)

		-- threat cards
		local threats = boss.RT and boss.RT.Threats or {}
		local seen = {}
		local now = os.clock()
		for _, t in threats do
			seen[t.Id] = true
			local c = cards[t.Id]
			if not c then
				c = makeCard(t)
				cards[t.Id] = c
			end
			c.LandsAt = now + t.LandsIn
			c.Total = t.Total
			c.Type = t.Type
			-- state text: how much of it has been stopped
			local stopped = false
			if t.Type == "Slam" then
				stopped = t.Cancelled
			elseif t.Type == "Meteor" then
				local live, total = 0, #t.Zones
				for _, z in t.Zones do
					if not z.Cancelled then live += 1 end
				end
				stopped = live == 0
				c.Title.Text = ("METEORS  %d/%d"):format(total - live, total)
			else
				stopped = #t.Marks == 0
				c.Title.Text = stopped and "CORRUPTION" or ("CORRUPTION  %d"):format(#t.Marks)
			end
			c.Stopped = stopped
			local stateColor = stopped and Color3.fromRGB(96, 214, 140) or c.Info.Color
			c.Edge.BackgroundColor3 = stateColor
			c.Fill.BackgroundColor3 = stateColor
			c.Answer.Text = stopped and "Stopped." or c.Info.Answer
			c.Answer.TextColor3 = stopped and Color3.fromRGB(150, 230, 180) or Color3.fromRGB(190, 198, 220)
		end
		for id, c in cards do
			if not seen[id] then
				c.Frame:Destroy()
				cards[id] = nil
			end
		end
		row.Visible = next(cards) ~= nil
	end

	-- Called several times a second: the countdowns run between server updates.
	function hud.Tick()
		local now = os.clock()
		for _, c in cards do
			local left = math.max(0, c.LandsAt - now)
			c.Count.Text = c.Stopped and "OK" or ("%.1f"):format(left)
			c.Count.TextColor3 = c.Stopped and Color3.fromRGB(150, 230, 180) or (left < 1.2 and Color3.fromRGB(255, 120, 110) or Color3.new(1, 1, 1))
			c.Fill.Size = UDim2.fromScale(math.clamp(left / math.max(0.1, c.Total), 0, 1), 1)
		end
	end

	return hud
end

return BossHud
