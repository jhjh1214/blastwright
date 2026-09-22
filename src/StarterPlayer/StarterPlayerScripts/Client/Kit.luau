--!nonstrict
-- The UI kit: reusable chunky components built from layers (depth shadow, outlined edge, coloured body, inner highlight,
-- icon, outlined text). Everything is sized with scale / constraints so it works from phones to wide monitors, and every
-- button shares one interaction: quick hover grow, press squash with a click, release with a small overshoot.
--   Kit.Button   the workhorse (icon and/or text; vertical or horizontal); IconButton / SideButton / ActionButton are presets
--   Kit.Panel    a modal panel with a coloured title ribbon and a big close button
--   Kit.Bar      an outlined progress bar that animates
--   Kit.Currency an icon + amount pill that bounces when the amount rises
--   Kit.Chip     a small outlined label (boost timers, event chips)
--   Kit.Outline  outline a piece of text
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local AudioManager = require(script.Parent.AudioManager)

local Kit = {}
local C = Theme.Colors

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end
Kit.Make = make

local function tween(inst, seconds, props, style, direction)
	local ok = pcall(function()
		TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props):Play()
	end)
	return ok
end
Kit.Tween = tween

-- Outline text: a dark stroke around the letters (the chunky sticker look).
function Kit.Outline(label, thickness, color)
	local s = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color or C.Outline
	s.Thickness = Theme.StrokeFor(label.TextSize, thickness or Theme.Stroke.Text)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
	return s
end

-- A text label with the standard outlined look. size = maximum text size; the text shrinks to fit its box.
function Kit.Label(parent, text, size, props)
	local p = {
		BackgroundTransparency = 1,
		Font = Theme.Font.Display,
		Text = text,
		TextSize = size,
		TextColor3 = C.Ink,
		TextScaled = true,
		TextWrapped = false,
	}
	for k, v in props or {} do
		p[k] = v
	end
	local l = make("TextLabel", p, parent)
	make("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = math.max(8, math.floor(size * 0.4)) }, l)
	Kit.Outline(l, size >= 24 and Theme.Stroke.Text or Theme.Stroke.TextSmall)
	return l
end

-- Sounds ------------------------------------------------------------------------------------------------------------------------

local SOUNDS = {
	Click = function() AudioManager.Play("Click") end,
	Hover = function() AudioManager.Play("Click", { Pitch = 1.7, Volume = 0.12 }) end,
	Open = function() AudioManager.Play("Click", { Pitch = 1.25 }) end,
	Close = function() AudioManager.Play("Click", { Pitch = 0.8 }) end,
	Reward = function() AudioManager.Play("Reward") end,
	Error = function() AudioManager.Play("Error") end,
}
Kit.Sounds = SOUNDS

-- Button --------------------------------------------------------------------------------------------------------------------------

-- o: Size (UDim2), Position, AnchorPoint, LayoutOrder, Color, Icon (name), Text (primary), Sub (supporting text),
--    Layout "Vertical" | "Horizontal", TextSize, Depth (px of thickness), Corner (px), OnClick, Sound ("Click"),
--    Enabled (default true), Outline (px)
function Kit.Button(parent, o)
	local depth = o.Depth or 7
	local corner = o.Corner or 14
	local outline = o.Outline or Theme.Stroke.Outer
	local color = o.Color or C.Info
	local vertical = (o.Layout or "Vertical") == "Vertical"

	local root = make("Frame", { Name = o.Name or "Button", BackgroundTransparency = 1, Size = o.Size, Position = o.Position or UDim2.new(), AnchorPoint = o.AnchorPoint or Vector2.new(), LayoutOrder = o.LayoutOrder or 0, ZIndex = o.ZIndex or 1, Visible = o.Visible ~= false }, parent)
	local scale = make("UIScale", { Scale = 1 }, root)

	-- depth layers: soft drop shadow, then the dark outlined edge that shows below the face
	local shadow = make("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 1 }, root)
	make("UICorner", { CornerRadius = UDim.new(0, corner) }, shadow)
	local edge = make("Frame", { BackgroundColor3 = Theme.Shade(color, 0.5), Size = UDim2.new(1, 0, 1, 0), BorderSizePixel = 0, ZIndex = 2 }, root)
	make("UICorner", { CornerRadius = UDim.new(0, corner) }, edge)
	make("UIStroke", { Color = C.Outline, Thickness = outline, LineJoinMode = Enum.LineJoinMode.Round }, edge)

	-- the face is the clickable part
	local face = make("TextButton", { Name = "Face", Text = "", AutoButtonColor = false, BackgroundColor3 = color, Size = UDim2.new(1, 0, 1, -depth), BorderSizePixel = 0, ZIndex = 3 }, root)
	make("UICorner", { CornerRadius = UDim.new(0, corner) }, face)
	make("UIStroke", { Color = C.Outline, Thickness = outline, LineJoinMode = Enum.LineJoinMode.Round }, face)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(color, 0.28), Theme.Shade(color, 0.06)), Rotation = 90 }, face)
	-- inner border and a soft gloss on the top half
	local inner = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), ZIndex = 4 }, face)
	make("UICorner", { CornerRadius = UDim.new(0, math.max(4, corner - 4)) }, inner)
	make("UIStroke", { Color = Theme.Tint(color, 0.6), Thickness = 2, Transparency = 0.45 }, inner)
	local gloss = make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0.42, 0), BorderSizePixel = 0, ZIndex = 4 }, face)
	make("UICorner", { CornerRadius = UDim.new(0, math.max(4, corner - 4)) }, gloss)

	local obj = { Root = root, Face = face, Color = color, Depth = depth }

	-- content
	local hasIcon, hasText = o.Icon ~= nil, o.Text ~= nil
	local iconHolder, textLabel, subLabel
	if hasIcon then
		iconHolder = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 }, face)
		local fraction = vertical and (hasText and 0.62 or 0.8) or 0.86
		if vertical then
			iconHolder.Position = UDim2.new(0.5, 0, hasText and 0.4 or 0.5, 0)
		else
			iconHolder.AnchorPoint = Vector2.new(0, 0.5)
			iconHolder.Position = UDim2.new(0, 10, 0.5, 0)
		end
		-- a square in pixels, from the face's height (zero-width scale frames with aspect constraints collapse)
		local function sizeIcon()
			local h = face.AbsoluteSize.Y
			if h > 0 then
				local px = math.floor(h * fraction)
				iconHolder.Size = UDim2.fromOffset(px, px)
			end
		end
		face:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeIcon)
		iconHolder.Size = UDim2.fromOffset(40, 40)
		sizeIcon()
		Icons.Draw(o.Icon, iconHolder, color, 1)
	end
	if hasText then
		local size = o.TextSize or Theme.Type.Secondary
		if vertical then
			textLabel = Kit.Label(face, o.Text, size, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(0.92, 0, hasIcon and 0.28 or 0.6, 0), ZIndex = 6 })
			if not hasIcon then
				textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
				textLabel.Position = UDim2.fromScale(0.5, o.Sub and 0.42 or 0.5)
			end
		else
			local left = hasIcon and 0.32 or 0.04
			textLabel = Kit.Label(face, o.Text, size, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(left, 0, o.Sub and 0.36 or 0.5, 0), Size = UDim2.new(1 - left - 0.04, 0, o.Sub and 0.5 or 0.7, 0), ZIndex = 6, TextXAlignment = hasIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center })
		end
	end
	if o.Sub then
		subLabel = make("TextLabel", { BackgroundTransparency = 1, Font = Theme.Font.Body, Text = o.Sub, TextSize = Theme.Type.Supporting, TextColor3 = C.Ink, TextScaled = true, ZIndex = 6, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.new(0.86, 0, 0.24, 0) }, face)
		make("UITextSizeConstraint", { MaxTextSize = Theme.Type.Supporting, MinTextSize = 8 }, subLabel)
		Kit.Outline(subLabel, Theme.Stroke.TextSmall)
		if not vertical then
			subLabel.Position = UDim2.new(hasIcon and 0.66 or 0.5, 0, 1, -5)
		end
	end

	-- badge (a red dot with an optional number)
	local badge = make("Frame", { Name = "Badge", BackgroundColor3 = C.Danger, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(26, 26), Visible = false, ZIndex = 8 }, root)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
	make("UIStroke", { Color = C.Outline, Thickness = 3 }, badge)
	local badgeText = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Theme.Font.Display, Text = "!", TextSize = 16, TextColor3 = C.Ink, ZIndex = 9 }, badge)

	-- interaction: hover grows, press squashes and sinks onto the edge, release bounces back
	local enabled = o.Enabled ~= false
	local function rest()
		tween(scale, Theme.Anim.Release, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(face, Theme.Anim.Release, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 1, -depth) }, Enum.EasingStyle.Back)
	end
	face.MouseEnter:Connect(function()
		if enabled then
			tween(scale, Theme.Anim.Hover, { Scale = 1.06 })
			SOUNDS.Hover()
		end
	end)
	face.MouseLeave:Connect(function()
		rest()
	end)
	face.MouseButton1Down:Connect(function()
		if enabled then
			tween(scale, Theme.Anim.Press, { Scale = 0.94 })
			tween(face, Theme.Anim.Press, { Position = UDim2.fromOffset(0, depth - 2), Size = UDim2.new(1, 0, 1, -2) })
		end
	end)
	face.MouseButton1Up:Connect(function()
		rest()
	end)
	face.Activated:Connect(function()
		if not enabled then
			SOUNDS.Error()
			return
		end
		local sound = SOUNDS[o.Sound or "Click"]
		if sound then
			sound()
		end
		if o.OnClick then
			o.OnClick()
		end
	end)

	function obj.SetText(text)
		if textLabel then textLabel.Text = text end
	end
	function obj.SetSub(text)
		if subLabel then subLabel.Text = text end
	end
	function obj.SetColor(c)
		obj.Color = c
		face.BackgroundColor3 = c
		edge.BackgroundColor3 = Theme.Shade(c, 0.5)
		local g = face:FindFirstChildOfClass("UIGradient")
		if g then g.Color = ColorSequence.new(Theme.Tint(c, 0.28), Theme.Shade(c, 0.06)) end
	end
	function obj.SetEnabled(on)
		enabled = on
		obj.SetColor(on and color or C.Neutral)
	end
	function obj.SetBadge(on, text)
		badge.Visible = on == true
		if text then badgeText.Text = tostring(text) end
	end
	-- a pressed-in look for the open page
	function obj.SetSelected(on)
		face.Position = UDim2.fromOffset(0, on and depth - 2 or 0)
		face.Size = on and UDim2.new(1, 0, 1, -2) or UDim2.new(1, 0, 1, -depth)
	end
	return obj
end

-- Presets ------------------------------------------------------------------------------------------------------------------------

-- A square icon button (side menus): big icon and a small caption.
function Kit.SideButton(parent, o)
	o.Layout = "Vertical"
	o.TextSize = o.TextSize or 16
	return Kit.Button(parent, o)
end

-- A wide primary action: icon left, big text, optional supporting line.
function Kit.ActionButton(parent, o)
	o.Layout = "Horizontal"
	o.TextSize = o.TextSize or Theme.Type.Primary
	return Kit.Button(parent, o)
end

-- The big red close button.
function Kit.CloseButton(parent, onClick)
	return Kit.Button(parent, { Name = "Close", Size = UDim2.fromOffset(52, 56), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Color = C.Danger, Icon = "Close", Depth = 5, Corner = 12, Sound = "Close", OnClick = onClick, ZIndex = 20 })
end

-- Panel ---------------------------------------------------------------------------------------------------------------------------

-- A modal-style panel: thick outlined body, a coloured title ribbon, a big close button. Returns { Root, Ribbon, Title, Body }.
-- o: Size, Position, AnchorPoint, Color (ribbon), Title, OnClose, Visible, ZIndex
function Kit.Panel(parent, o)
	local color = o.Color or C.Info
	local root = make("Frame", { Name = o.Name or "Panel", BackgroundTransparency = 1, Size = o.Size, Position = o.Position, AnchorPoint = o.AnchorPoint or Vector2.new(0.5, 0.5), Visible = o.Visible ~= false, ZIndex = o.ZIndex or Theme.Z.Panel }, parent)
	local shadow = make("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, Position = UDim2.fromOffset(0, 8), Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 1 }, root)
	make("UICorner", { CornerRadius = UDim.new(0, 22) }, shadow)
	local body = make("Frame", { BackgroundColor3 = C.Panel, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 2 }, root)
	make("UICorner", { CornerRadius = UDim.new(0, 22) }, body)
	make("UIStroke", { Color = C.Outline, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round }, body)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(C.Panel, 0.1), Theme.Shade(C.Panel, 0.25)), Rotation = 90 }, body)
	local inner = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 1, -14), ZIndex = 3 }, body)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, inner)
	make("UIStroke", { Color = Theme.Tint(C.Panel, 0.4), Thickness = 2, Transparency = 0.55 }, inner)

	-- title ribbon overlapping the top edge
	local ribbon = make("Frame", { Name = "Ribbon", BackgroundColor3 = color, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(0.6, 0, 0, 58), BorderSizePixel = 0, ZIndex = 6 }, root)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, ribbon)
	make("UIStroke", { Color = C.Outline, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round }, ribbon)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(color, 0.3), Theme.Shade(color, 0.08)), Rotation = 90 }, ribbon)
	local title = Kit.Label(ribbon, o.Title or "", 34, { Size = UDim2.new(1, -24, 0.78, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7, TextXAlignment = Enum.TextXAlignment.Left })

	local closeButton = Kit.CloseButton(root, o.OnClose)
	closeButton.Root.Position = UDim2.new(1, -10, 0, -14)

	local content = make("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 44), Size = UDim2.new(1, -28, 1, -58), ZIndex = 4 }, root)
	return { Root = root, Ribbon = ribbon, Title = title, Body = content, Close = closeButton, Frame = body }
end

-- Progress bar --------------------------------------------------------------------------------------------------------------------

-- A chunky outlined bar. bar.Set(fraction, text) animates the fill; text (optional) is shown over the bar.
function Kit.Bar(parent, o)
	local color = o.Color or C.Success
	local root = make("Frame", { Name = o.Name or "Bar", BackgroundColor3 = C.PanelDark, Size = o.Size or UDim2.new(1, 0, 0, 22), Position = o.Position or UDim2.new(), AnchorPoint = o.AnchorPoint or Vector2.new(), LayoutOrder = o.LayoutOrder or 0, BorderSizePixel = 0, ZIndex = o.ZIndex or 5, ClipsDescendants = false }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 9) }, root)
	make("UIStroke", { Color = C.Outline, Thickness = Theme.Stroke.Small, LineJoinMode = Enum.LineJoinMode.Round }, root)
	local clip = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = (o.ZIndex or 5) + 1 }, root)
	make("UICorner", { CornerRadius = UDim.new(0, 9) }, clip)
	local fill = make("Frame", { Name = "Fill", BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, ZIndex = (o.ZIndex or 5) + 2 }, clip)
	make("UICorner", { CornerRadius = UDim.new(0, 9) }, fill)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(color, 0.35), Theme.Shade(color, 0.05)), Rotation = 90 }, fill)
	local gloss = make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, Position = UDim2.fromScale(0, 0.08), Size = UDim2.fromScale(1, 0.32), BorderSizePixel = 0, ZIndex = (o.ZIndex or 5) + 3 }, fill)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, gloss)
	local label = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Theme.Font.Display, Text = "", TextSize = 16, TextColor3 = C.Ink, TextScaled = true, ZIndex = (o.ZIndex or 5) + 4 }, root)
	make("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 8 }, label)
	Kit.Outline(label, 2.5)
	local bar = { Root = root, Fill = fill }
	local last = 0
	function bar.Set(fraction, text, instant)
		fraction = math.clamp(fraction or 0, 0, 1)
		label.Text = text or ""
		if instant then
			fill.Size = UDim2.fromScale(fraction, 1)
		else
			tween(fill, Theme.Anim.Fill, { Size = UDim2.fromScale(fraction, 1) }, Enum.EasingStyle.Quart)
		end
		last = fraction
	end
	function bar.SetColor(c)
		fill.BackgroundColor3 = c
		local g = fill:FindFirstChildOfClass("UIGradient")
		if g then g.Color = ColorSequence.new(Theme.Tint(c, 0.35), Theme.Shade(c, 0.05)) end
	end
	return bar
end

-- Currency -------------------------------------------------------------------------------------------------------------------------

-- An icon + amount pill. cur.Set(amount) counts up quickly and bounces when the amount rises.
function Kit.Currency(parent, o)
	local color = o.Color or C.Premium
	local root = make("Frame", { Name = o.Name or "Currency", BackgroundColor3 = C.PanelDark, Size = o.Size or UDim2.fromOffset(170, 46), Position = o.Position or UDim2.new(), AnchorPoint = o.AnchorPoint or Vector2.new(), BorderSizePixel = 0, ZIndex = o.ZIndex or 5 }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, root)
	make("UIStroke", { Color = C.Outline, Thickness = Theme.Stroke.Outer, LineJoinMode = Enum.LineJoinMode.Round }, root)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(C.PanelDark, 0.16), Theme.Shade(C.PanelDark, 0.2)), Rotation = 90 }, root)
	local scale = make("UIScale", { Scale = 1 }, root)
	local iconHolder = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -6, 0.5, 0), Size = UDim2.fromOffset(64, 64), ZIndex = (o.ZIndex or 5) + 2 }, root)
	local function sizeCurrencyIcon()
		local h = root.AbsoluteSize.Y
		if h > 0 then
			local px = math.floor(h * 1.25)
			iconHolder.Size = UDim2.fromOffset(px, px)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCurrencyIcon)
	sizeCurrencyIcon()
	Icons.Draw(o.Icon or "Gem", iconHolder, color, 1)
	local text = Kit.Label(root, "0", 26, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(1, -66, 0.72, 0), ZIndex = (o.ZIndex or 5) + 2, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.Tint(color, 0.4) })
	local cur = { Root = root, Label = text, Value = 0, Shown = 0 }
	local function fmt(n)
		n = math.floor(n + 0.5)
		if n >= 1e9 then return ("%.1fB"):format(n / 1e9) end
		if n >= 1e6 then return ("%.2fM"):format(n / 1e6) end
		local s = tostring(n)
		return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
	end
	cur.Format = fmt
	function cur.Set(amount, instant)
		local rose = amount > cur.Value
		cur.Value = amount
		if instant then
			cur.Shown = amount
			text.Text = fmt(amount)
			return
		end
		if rose then
			tween(scale, 0.08, { Scale = 1.12 })
			task.delay(0.08, function()
				tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end
	-- (the count-up itself runs from cur.Step, called each frame by the owner)
	function cur.Step(dt)
		if math.abs(cur.Shown - cur.Value) < 1 then
			if cur.Shown ~= cur.Value then
				cur.Shown = cur.Value
				text.Text = fmt(cur.Shown)
			end
			return
		end
		cur.Shown += (cur.Value - cur.Shown) * math.min(1, dt * 9)
		text.Text = fmt(cur.Shown)
	end
	return cur
end

-- Chip ----------------------------------------------------------------------------------------------------------------------------

-- A small outlined label pill (boost timers, event notes). Auto-sizes to its text.
function Kit.Chip(parent, o)
	local color = o.Color or C.Info
	local root = make("Frame", { Name = o.Name or "Chip", BackgroundColor3 = Theme.Shade(color, 0.35), Size = UDim2.new(0, 0, 0, o.Height or 34), AutomaticSize = Enum.AutomaticSize.X, Position = o.Position or UDim2.new(), AnchorPoint = o.AnchorPoint or Vector2.new(), LayoutOrder = o.LayoutOrder or 0, BorderSizePixel = 0, Visible = o.Visible ~= false, ZIndex = o.ZIndex or 5 }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, root)
	make("UIStroke", { Color = C.Outline, Thickness = Theme.Stroke.Small, LineJoinMode = Enum.LineJoinMode.Round }, root)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(color, 0.15), Theme.Shade(color, 0.3)), Rotation = 90 }, root)
	make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, root)
	local label = make("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Font = Theme.Font.Display, Text = o.Text or "", TextSize = o.TextSize or 17, TextColor3 = C.Ink, ZIndex = (o.ZIndex or 5) + 1 }, root)
	Kit.Outline(label, 2.5)
	return { Root = root, Label = label }
end

-- Popup ---------------------------------------------------------------------------------------------------------------------------

-- A reward popup: a chunky centred card with a title ribbon, a big icon, the amount / name, and a green button. It pops in with a
-- bounce, plays the reward sound and closes itself after a few seconds (or on the button). One at a time.
-- o: Title, Icon (Icons name), Text (what you got), Sub (small line), Color
-- Reward popups queue instead of dropping: a Mastery reward and a boss-defeated moment landing in the same instant both get
-- shown, one after the other, instead of one silently vanishing or the two overlapping on screen.
local popupOpen = false
local popupQueue = {}
function Kit.Popup(parent, o)
	if popupOpen then
		if #popupQueue < 3 then
			table.insert(popupQueue, { parent, o })
		end
		return
	end
	popupOpen = true
	local color = o.Color or C.Goals
	-- Tapping the dimmed backdrop also closes it (a big, obvious way to dismiss besides the button), never waits it out.
	local dim = make("TextButton", { Name = "PopupDim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = Theme.Z.Popup, Active = true }, parent)
	local card = make("Frame", { BackgroundColor3 = C.Panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 320), ZIndex = Theme.Z.Popup + 1 }, dim)
	make("UISizeConstraint", { MaxSize = Vector2.new(420, 340) }, card)
	make("UICorner", { CornerRadius = UDim.new(0, 24) }, card)
	make("UIStroke", { Color = C.Outline, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round }, card)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(C.Panel, 0.14), Theme.Shade(C.Panel, 0.3)), Rotation = 90 }, card)
	local scale = make("UIScale", { Scale = 0.6 }, card)
	local ribbon = make("Frame", { BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.86, 0, 0, 60), BorderSizePixel = 0, ZIndex = Theme.Z.Popup + 3 }, card)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, ribbon)
	make("UIStroke", { Color = C.Outline, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round }, ribbon)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(color, 0.3), Theme.Shade(color, 0.08)), Rotation = 90 }, ribbon)
	Kit.Label(ribbon, o.Title or "NICE!", 34, { Size = UDim2.new(0.92, 0, 0.78, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = Theme.Z.Popup + 4 })
	local disc = make("Frame", { BackgroundColor3 = Theme.Shade(color, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(150, 150), BorderSizePixel = 0, ZIndex = Theme.Z.Popup + 2 }, card)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
	make("UIStroke", { Color = C.Outline, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round }, disc)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(color, 0.35), Theme.Shade(color, 0.25)), Rotation = 90 }, disc)
	Icons.Draw(o.Icon or "Gem", disc, color, 0.72)
	Kit.Label(card, o.Text or "", 30, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 216), Size = UDim2.new(0.9, 0, 0, 40), ZIndex = Theme.Z.Popup + 3 })
	if o.Sub then
		local sub = make("TextLabel", { BackgroundTransparency = 1, Font = Theme.Font.Body, Text = o.Sub, TextSize = 17, TextColor3 = C.Ink, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 258), Size = UDim2.new(0.86, 0, 0, 22), ZIndex = Theme.Z.Popup + 3 }, card)
		make("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 9 }, sub)
		Kit.Outline(sub, 2)
	end
	local function close()
		if not dim.Parent then
			return
		end
		popupOpen = false
		tween(scale, Theme.Anim.Close, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(dim, Theme.Anim.Close, { BackgroundTransparency = 1 })
		task.delay(Theme.Anim.Close + 0.02, function()
			dim:Destroy()
			local nextCall = table.remove(popupQueue, 1)
			if nextCall then
				Kit.Popup(nextCall[1], nextCall[2])
			end
		end)
	end
	dim.Activated:Connect(close)
	Kit.Button(card, { Size = UDim2.fromOffset(160, 58), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Color = C.Success, Text = o.CloseText or "NICE!", TextSize = 28, Depth = 6, Sound = "Close", OnClick = close, ZIndex = Theme.Z.Popup + 4 })
	tween(dim, Theme.Anim.Popup, { BackgroundTransparency = 0.45 })
	tween(scale, Theme.Anim.Popup, { Scale = 1 }, Enum.EasingStyle.Back)
	SOUNDS.Reward()
	task.delay(o.Hold or 5, close)
end

-- A flat thick-outlined card frame (item cards, rows). Returns the frame.
function Kit.Card(parent, o)
	local color = o.Color or C.Panel
	local card = make("Frame", { Name = o.Name or "Card", BackgroundColor3 = color, Size = o.Size or UDim2.new(1, 0, 0, 80), Position = o.Position or UDim2.new(), LayoutOrder = o.LayoutOrder or 0, BorderSizePixel = 0, ZIndex = o.ZIndex or 5 }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, o.Corner or 14) }, card)
	make("UIStroke", { Color = C.Outline, Thickness = o.Outline or Theme.Stroke.Small, LineJoinMode = Enum.LineJoinMode.Round }, card)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(color, 0.14), Theme.Shade(color, 0.14)), Rotation = 90 }, card)
	return card
end

return Kit
