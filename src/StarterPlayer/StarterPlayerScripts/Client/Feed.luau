--!nonstrict
-- Messages, laid out properly:
--  * the FEED: a column of cards on the right edge (newest on top, at most 4 at once) for things that happened: rewards, warnings,
--    goals reached. Each card has an icon tile, a title and an optional body, and slides in from the edge.
--  * the BANNER: one big plate in the upper middle for moments (chain tiers, Critical Mass, boss phases). One at a time, queued.
-- Flat, dark plates with a coloured edge; display font for titles, clean body font. No glows, no strokes on text.
local TweenService = game:GetService("TweenService")

local Feed = {}

local DISPLAY = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSans
local BODY_BOLD = Enum.Font.BuilderSansBold

local KINDS = {
	Reward = { Color = Color3.fromRGB(240, 186, 60), Glyph = "★", Life = 4.5 },
	Info = { Color = Color3.fromRGB(84, 160, 240), Glyph = "i", Life = 4 },
	Warning = { Color = Color3.fromRGB(240, 100, 92), Glyph = "!", Life = 5 },
	Achievement = { Color = Color3.fromRGB(176, 110, 240), Glyph = "★", Life = 6.5 },
}
Feed.Kinds = KINDS

local holder, gui
local live = {}
local counter = 0
local recent = {}

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

function Feed.Init(screenGui)
	gui = screenGui
	holder = make("Frame", { Name = "Feed", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 64), Size = UDim2.fromOffset(300, 10), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 30 }, gui)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }, holder)
	local fit = make("UIScale", { Scale = 1 }, holder)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fit.Scale = math.clamp(gui.AbsoluteSize.X / 900, 0.7, 1) -- a little smaller on phones
	end)
end

-- Split "Floor 3 cleared! Choose your next step." into a title and a body. Short messages are all title.
function Feed.Split(text)
	if #text <= 32 then
		return text, ""
	end
	local cut = text:find("[!:%.]%s")
	if cut and cut >= 6 and cut <= 48 then
		local title = text:sub(1, cut)
		if title:sub(-1) == ":" or title:sub(-1) == "." then
			title = title:sub(1, -2)
		end
		return title, text:sub(cut + 2)
	end
	return text, ""
end

-- Decide the presentation from the server's kind and the wording (goals and mastery get the special card).
function Feed.Classify(text, kind)
	if kind == "Error" then
		return "Warning"
	end
	if kind == "Reward" and (text:find("^Goal") or text:find("MASTERY") or text:find("DEFEATED") or text:find("COMPLETE") or text:find("unlocked!")) then
		return "Achievement"
	end
	if kind == "Reward" then
		return "Reward"
	end
	return "Info"
end

function Feed.Push(kind, title, body)
	if not holder then
		return
	end
	local now = os.clock()
	local key = title .. "|" .. (body or "")
	if recent[key] and now - recent[key] < 1.5 then
		return -- the same message twice in a row is noise
	end
	recent[key] = now
	local style = KINDS[kind] or KINDS.Info
	counter += 1

	local wrapper = make("Frame", { Name = "Item", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = -counter, ZIndex = 30 }, holder)
	local card = make("Frame", { BackgroundColor3 = Color3.fromRGB(24, 27, 42), BackgroundTransparency = 0.04, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(320, 0), BorderSizePixel = 0, ZIndex = 31 }, wrapper)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
	make("UIStroke", { Color = Color3.fromRGB(70, 78, 110), Thickness = 1, Transparency = 0.3 }, card)
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 60), PaddingRight = UDim.new(0, 12) }, card)

	-- the colour edge on the left and the icon tile
	local edge = make("Frame", { BackgroundColor3 = style.Color, Position = UDim2.new(0, -60, 0, -10), Size = UDim2.new(0, 5, 1, 20), BorderSizePixel = 0, ZIndex = 32 }, card)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, edge)
	local tile = make("Frame", { BackgroundColor3 = style.Color, Position = UDim2.fromOffset(-50, 0), Size = UDim2.fromOffset(34, 34), BorderSizePixel = 0, ZIndex = 32 }, card)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, tile)
	make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = DISPLAY, Text = style.Glyph, TextSize = 20, TextColor3 = Color3.fromRGB(28, 26, 40), ZIndex = 33 }, tile)

	local column = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 32 }, card)
	make("UIListLayout", { Padding = UDim.new(0, 2) }, column)
	make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = DISPLAY, Text = title, TextSize = 17, TextColor3 = Color3.fromRGB(246, 247, 252), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33, LayoutOrder = 1 }, column)
	if body and body ~= "" then
		make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = BODY, Text = body, TextSize = 14, TextColor3 = Color3.fromRGB(180, 188, 210), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33, LayoutOrder = 2 }, column)
	end

	TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
	table.insert(live, wrapper)
	while #live > 4 do
		local old = table.remove(live, 1)
		if old.Parent then
			old:Destroy()
		end
	end
	task.delay(style.Life, function()
		if wrapper.Parent then
			local inner = wrapper:FindFirstChildOfClass("Frame")
			if inner then
				TweenService:Create(inner, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(330, 0) }):Play()
			end
			task.delay(0.3, function()
				if wrapper.Parent then
					wrapper:Destroy()
				end
			end)
		end
	end)
end

-- Banner ---------------------------------------------------------------------------------------------------------------------

local bannerQueue = {}
local bannerBusy = false
local plate, bannerTitle, bannerSub, bannerRule

local function ensureBanner()
	if plate then
		return
	end
	plate = make("Frame", { Name = "Banner", BackgroundColor3 = Color3.fromRGB(16, 18, 30), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(520, 96), Visible = false, BorderSizePixel = 0, ZIndex = 40 }, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, plate)
	make("UISizeConstraint", { MaxSize = Vector2.new(560, 120) }, plate)
	bannerRule = make("Frame", { BackgroundColor3 = Color3.fromRGB(240, 186, 60), Size = UDim2.new(1, 0, 0, 5), BorderSizePixel = 0, ZIndex = 41 }, plate)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, bannerRule)
	bannerTitle = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 52), Font = DISPLAY, Text = "", TextSize = 42, TextColor3 = Color3.new(1, 1, 1), ZIndex = 41 }, plate)
	bannerSub = make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 24), Font = BODY_BOLD, Text = "", TextSize = 17, TextColor3 = Color3.fromRGB(190, 198, 220), ZIndex = 41 }, plate)
end

local function playNext()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local item = table.remove(bannerQueue, 1)
	ensureBanner()
	bannerTitle.Text = item.Title
	bannerSub.Text = item.Subtitle or ""
	bannerRule.BackgroundColor3 = item.Color
	bannerTitle.TextColor3 = item.Color:Lerp(Color3.new(1, 1, 1), 0.55)
	plate.Position = UDim2.fromScale(0.5, 0.22)
	plate.BackgroundTransparency = 1
	plate.Visible = true
	bannerRule.BackgroundTransparency = 1
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	local slide = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(plate, slide, { Position = UDim2.fromScale(0.5, 0.26), BackgroundTransparency = 0.08 }):Play()
	TweenService:Create(bannerRule, slide, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(bannerTitle, slide, { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, slide, { TextTransparency = 0 }):Play()
	task.delay(item.Hold or 1.6, function()
		local out = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(plate, out, { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.24) }):Play()
		TweenService:Create(bannerRule, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(bannerTitle, out, { TextTransparency = 1 }):Play()
		TweenService:Create(bannerSub, out, { TextTransparency = 1 }):Play()
		task.delay(0.3, function()
			plate.Visible = false
			bannerBusy = false
			playNext()
		end)
	end)
end

-- Queue a banner. Long backlogs are trimmed so a chain does not replay stale moments.
function Feed.Banner(title, subtitle, color, hold)
	if not gui then
		return
	end
	if #bannerQueue >= 2 then
		table.remove(bannerQueue, 1)
	end
	table.insert(bannerQueue, { Title = title, Subtitle = subtitle, Color = color or KINDS.Reward.Color, Hold = hold })
	playNext()
end

return Feed
