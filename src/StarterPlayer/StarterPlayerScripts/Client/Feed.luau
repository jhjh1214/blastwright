--!nonstrict
-- Messages, laid out properly:
--  * the FEED: a column of cards on the right edge (newest on top, at most 4 at once) for things that happened: rewards, warnings,
--    goals reached. Each card has an icon tile, a title and an optional body, and slides in from the edge.
--  * the BANNER: one big plate in the upper middle for moments (chain tiers, Critical Mass, boss phases). One at a time, queued.
-- Flat, dark plates with a coloured edge; display font for titles, clean body font. No glows, no strokes on text.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Calm = require(script.Parent.Calm)
local Icons = require(script.Parent.Icons)

local Feed = {}

local DISPLAY = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSans
local BODY_BOLD = Enum.Font.BuilderSansBold

local KINDS = {
	Reward = { Color = Theme.Colors.Goals, Icon = "Gem", Life = 4.5 },
	Info = { Color = Theme.Colors.Codex, Icon = "Codex", Life = 4 },
	Warning = { Color = Theme.Colors.Danger, Icon = "Bomb", Life = 5 },
	Achievement = { Color = Theme.Colors.Boost, Icon = "Goals", Life = 6.5 },
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
	holder = make("Frame", { Name = "Feed", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 84), Size = UDim2.fromOffset(320, 10), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 30 }, gui)
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

-- During a boss fight the middle and right of the screen belong to the boss HUD: only warnings and achievements get a card.
local compact = false
function Feed.SetCompact(on)
	compact = on == true
end

function Feed.Push(kind, title, body)
	if not holder then
		return
	end
	if compact and kind ~= "Warning" and kind ~= "Achievement" then
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
	local card = make("Frame", { BackgroundColor3 = Theme.Shade(style.Color, 0.55), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(330, 0), BorderSizePixel = 0, ZIndex = 31 }, wrapper)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, card)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round }, card)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(style.Color, 0.05), Theme.Shade(style.Color, 0.5)), Rotation = 90 }, card)
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 72), PaddingRight = UDim.new(0, 14) }, card)

	-- the icon tile: a chunky coloured square with a big drawn icon
	local tile = make("Frame", { BackgroundColor3 = style.Color, Position = UDim2.fromOffset(-62, -2), Size = UDim2.fromOffset(52, 52), BorderSizePixel = 0, ZIndex = 32 }, card)
	make("UICorner", { CornerRadius = UDim.new(0, 13) }, tile)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = 3.5, LineJoinMode = Enum.LineJoinMode.Round }, tile)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(style.Color, 0.3), Theme.Shade(style.Color, 0.06)), Rotation = 90 }, tile)
	Icons.Draw(style.Icon, tile, style.Color, 0.84)

	local column = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 32 }, card)
	make("UIListLayout", { Padding = UDim.new(0, 2) }, column)
	local titleLabel = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = DISPLAY, Text = title, TextSize = 21, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33, LayoutOrder = 1 }, column)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = Theme.StrokeFor(21, 3), LineJoinMode = Enum.LineJoinMode.Round }, titleLabel)
	if body and body ~= "" then
		local bodyLabel = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = BODY_BOLD, Text = body, TextSize = 15, TextColor3 = Color3.fromRGB(240, 244, 255), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 33, LayoutOrder = 2 }, column)
		make("UIStroke", { Color = Theme.Colors.Outline, Thickness = Theme.StrokeFor(15, 2), LineJoinMode = Enum.LineJoinMode.Round }, bodyLabel)
	end

	TweenService:Create(card, TweenInfo.new(Theme.Anim.Popup, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) }):Play()
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
local plate, bannerTitle, bannerSub, bannerRule, bannerStroke, plateScale

local function ensureBanner()
	if plate then
		return
	end
	plate = make("Frame", { Name = "Banner", BackgroundColor3 = Theme.Colors.Panel, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(560, 112), Visible = false, BorderSizePixel = 0, ZIndex = Theme.Z.Banner }, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 20) }, plate)
	plateScale = make("UIScale", { Scale = 1 }, plate)
	make("UISizeConstraint", { MaxSize = Vector2.new(600, 130) }, plate)
	bannerStroke = make("UIStroke", { Color = Theme.Colors.Outline, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round }, plate)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(Theme.Colors.Panel, 0.12), Theme.Shade(Theme.Colors.Panel, 0.3)), Rotation = 90 }, plate)
	bannerRule = make("Frame", { BackgroundColor3 = Color3.fromRGB(240, 186, 60), Size = UDim2.new(1, 0, 0, 16), BorderSizePixel = 0, ZIndex = Theme.Z.Banner + 1 }, plate)
	make("UICorner", { CornerRadius = UDim.new(0, 20) }, bannerRule)
	bannerTitle = make("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.new(0.94, 0, 0, 58), Font = DISPLAY, Text = "", TextSize = 50, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = Theme.Z.Banner + 2 }, plate)
	make("UITextSizeConstraint", { MaxTextSize = 50, MinTextSize = 16 }, bannerTitle)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round }, bannerTitle)
	bannerSub = make("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.new(0.9, 0, 0, 24), Font = BODY_BOLD, Text = "", TextSize = 19, TextScaled = true, TextColor3 = Color3.fromRGB(235, 240, 255), ZIndex = Theme.Z.Banner + 2 }, plate)
	make("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 10 }, bannerSub)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = 2.5, LineJoinMode = Enum.LineJoinMode.Round }, bannerSub)
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
	bannerTitle.TextColor3 = item.Color:Lerp(Color3.new(1, 1, 1), 0.35)
	local shownY = item.Calm and 0.2 or 0.26
	plateScale.Scale = item.Calm and 0.62 or 1
	plate.Position = UDim2.fromScale(0.5, shownY - 0.04)
	plate.BackgroundTransparency = 1
	bannerStroke.Transparency = 1
	plate.Visible = true
	bannerRule.BackgroundTransparency = 1
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	local slide = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(plate, slide, { Position = UDim2.fromScale(0.5, shownY), BackgroundTransparency = 0 }):Play()
	TweenService:Create(bannerStroke, slide, { Transparency = 0 }):Play()
	TweenService:Create(bannerRule, slide, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(bannerTitle, slide, { TextTransparency = 0 }):Play()
	TweenService:Create(bannerSub, slide, { TextTransparency = 0 }):Play()
	task.delay(item.Hold or 1.6, function()
		local out = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(plate, out, { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, shownY - 0.02) }):Play()
		TweenService:Create(bannerStroke, out, { Transparency = 1 }):Play()
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
-- important = true for banners that must show even in calm mode (boss intro, phases, boss defeated). In calm mode (boss or
-- Expedition) other banners are dropped, and the ones that show are smaller and sit higher so the field stays readable.
function Feed.Banner(title, subtitle, color, hold, important)
	if not gui then
		return
	end
	if Calm.On and not important then
		return
	end
	if #bannerQueue >= 2 then
		table.remove(bannerQueue, 1)
	end
	table.insert(bannerQueue, { Title = title, Subtitle = subtitle, Color = color or KINDS.Reward.Color, Hold = hold, Calm = Calm.On })
	playNext()
end

return Feed
