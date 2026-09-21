--!nonstrict
-- Reusable UI effects, all procedural (no asset ids): gradients, glowing and animated borders, shimmer, hover/press
-- feedback, colored icon tiles, progress bars and spinning 3D gems in ViewportFrames. Purely cosmetic: every function
-- is safe to call on any GuiObject and never touches game state.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

-- The palette shared by everything that needs a category colour.
Fx.Family = {
	Echo = Color3.fromRGB(90, 220, 255),
	Explosion = Color3.fromRGB(255, 140, 60),
	Combo = Color3.fromRGB(255, 90, 220),
	Risk = Color3.fromRGB(255, 80, 90),
}
Fx.Room = {
	Mining = Color3.fromRGB(110, 150, 210),
	Combat = Color3.fromRGB(235, 80, 80),
	Elite = Color3.fromRGB(190, 90, 255),
	Treasure = Color3.fromRGB(255, 200, 60),
	Chaos = Color3.fromRGB(255, 70, 200),
	Boss = Color3.fromRGB(200, 40, 60),
}
Fx.Tab = {
	Forge = Color3.fromRGB(255, 140, 60),
	Daily = Color3.fromRGB(110, 230, 150),
	Farm = Color3.fromRGB(170, 235, 80),
	Goals = Color3.fromRGB(255, 205, 90),
	Shop = Color3.fromRGB(255, 100, 200),
	Codex = Color3.fromRGB(90, 200, 255),
}

local function lighten(c, amount)
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

local function darken(c, amount)
	return c:Lerp(Color3.new(0, 0, 0), amount)
end
Fx.Lighten, Fx.Darken = lighten, darken

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

-- A subtle top-light / bottom-shade gradient. It multiplies the element's own colour, so later changes to
-- BackgroundColor3 still work.
function Fx.Depth(gui, strength)
	strength = strength or 0.22
	return make("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), darken(Color3.new(1, 1, 1), strength)),
		Rotation = 90,
	}, gui)
end

-- A background gradient between two colours (element background should be white for the true colours to show).
function Fx.Gradient(gui, c1, c2, rotation)
	return make("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90 }, gui)
end

-- A plain outline (kept under the old name so callers keep working). Deliberately static: no pulsing glow.
function Fx.Glow(gui, color, thickness, period)
	return make("UIStroke", { Color = color, Thickness = math.min(thickness or 2, 2), Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, gui)
end

-- A plain outline in the first colour (kept under the old name). No travelling rainbow.
function Fx.AnimatedBorder(gui, colors, thickness, period)
	return make("UIStroke", { Color = colors[1], Thickness = math.min(thickness or 2, 2), Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, gui)
end

-- (Removed on purpose: sweeping light bands read as cheap. Kept as a no-op so existing calls are harmless.)
function Fx.Shimmer(gui, period, strength)
	return nil
end

-- Grow slightly on hover and shrink slightly on press.
function Fx.Hover(button)
	local scale = make("UIScale", { Scale = 1 }, button)
	local function to(value, time)
		pcall(function()
			TweenService:Create(scale, TweenInfo.new(time or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = value }):Play()
		end)
	end
	button.MouseEnter:Connect(function()
		to(1.05)
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.94, 0.06)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.05)
	end)
	return scale
end

-- A rounded, glowing colour tile with a glyph or short text on it.
function Fx.Icon(parent, glyph, color, size, props)
	local tile = make("Frame", { BackgroundColor3 = color, Size = UDim2.fromOffset(size, size), BorderSizePixel = 0 }, parent)
	for k, v in props or {} do
		tile[k] = v
	end
	make("UICorner", { CornerRadius = UDim.new(0, math.floor(size * 0.28)) }, tile)
	make("UIGradient", { Color = ColorSequence.new(lighten(Color3.new(1, 1, 1), 0), darken(Color3.new(1, 1, 1), 0.35)), Rotation = 60 }, tile)
	make("UIStroke", { Color = lighten(color, 0.45), Thickness = 2, Transparency = 0.25 }, tile)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.FredokaOne,
		Text = glyph,
		TextSize = math.floor(size * 0.5),
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.5,
		ZIndex = (tile.ZIndex or 1) + 1,
	}, tile)
	return tile
end

-- A progress bar (fraction 0..1). Returns the outer frame; the fill is its child "Fill".
function Fx.Progress(parent, fraction, color, props)
	local bar = make("Frame", { BackgroundColor3 = Color3.fromRGB(16, 18, 28), Size = UDim2.new(1, 0, 0, 10), BorderSizePixel = 0 }, parent)
	for k, v in props or {} do
		bar[k] = v
	end
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, bar)
	local fill = make("Frame", { Name = "Fill", BackgroundColor3 = color, Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BorderSizePixel = 0 }, bar)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, fill)
	make("UIGradient", { Color = ColorSequence.new(lighten(Color3.new(1, 1, 1), 0), darken(Color3.new(1, 1, 1), 0.3)), Rotation = 90 }, fill)
	if fraction >= 1 then
		Fx.Shimmer(fill, 1.8, 0.7)
	end
	return bar
end

-- Spinning gems -------------------------------------------------------------------------------------------------------

local gems = {}
local loop = nil
local elapsed = 0

local function ensureLoop()
	if loop then
		return
	end
	loop = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		for i = #gems, 1, -1 do
			local g = gems[i]
			if not g.Frame.Parent then
				table.remove(gems, i)
			elseif g.Frame.AbsoluteSize.X > 0 then
				local cf = CFrame.Angles(math.rad(18), elapsed * 1.3 + g.Phase, math.rad(10))
				for _, part in g.Parts do
					part.CFrame = cf -- every piece is centred on the origin, so one rotation spins the whole crystal
				end
			end
		end
	end)
end

-- A small spinning crystal (a tall faceted block over a glowing core) in a ViewportFrame. dim = greyed-out "not found".
function Fx.Gem(parent, color, size, dim)
	local frame = make("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Ambient = Color3.fromRGB(140, 140, 160), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -1, -0.5) }, parent)
	local col = dim and Color3.fromRGB(70, 74, 90) or color
	local parts = {}
	for _, spec in {
		{ Vector3.new(0.9, 2.0, 0.9), Enum.Material.Glass, 0.25, col },
		{ Vector3.new(0.55, 2.7, 0.55), Enum.Material.Neon, 0.35, col },
		{ Vector3.new(0.5, 0.5, 0.5), Enum.Material.Neon, 0, lighten(col, 0.45) },
	} do
		table.insert(parts, make("Part", { Anchored = true, CanCollide = false, Size = spec[1], Material = spec[2], Transparency = spec[3], Color = spec[4], CFrame = CFrame.new() }, frame))
	end
	local cam = make("Camera", { FieldOfView = 40, CFrame = CFrame.lookAt(Vector3.new(0, 0.4, 5.2), Vector3.new(0, 0, 0)) }, frame)
	frame.CurrentCamera = cam
	if not dim then
		table.insert(gems, { Frame = frame, Parts = parts, Phase = math.random() * 6 })
		ensureLoop()
	else
		for _, part in parts do
			part.CFrame = CFrame.Angles(math.rad(18), 0.6, math.rad(10))
		end
	end
	return frame
end

-- Per-frame animation ---------------------------------------------------------------------------------------------------

local animated = {}
local animConn = nil
local animClock = 0

-- Call fn(t, dt) every frame while `object` is alive (it stops by itself when the object is destroyed).
function Fx.OnFrame(object, fn)
	table.insert(animated, { Object = object, Fn = fn })
	if animConn then
		return
	end
	animConn = RunService.RenderStepped:Connect(function(dt)
		animClock += dt
		for i = #animated, 1, -1 do
			local a = animated[i]
			if not a.Object.Parent then
				table.remove(animated, i)
			else
				pcall(a.Fn, animClock, dt)
			end
		end
	end)
end

-- (Removed on purpose, see Shimmer.)
function Fx.Sparkles(parent, count, color) end

-- Expanding rings (an "explosion preview" or a pulse), centred in `parent`.
function Fx.Rings(parent, color, count, period, maxSize)
	count = count or 3
	period = period or 1.8
	for i = 1, count do
		local ring = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundTransparency = 1,
			ZIndex = (parent.ZIndex or 1) + 1,
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		local stroke = make("UIStroke", { Color = color, Thickness = 3, Transparency = 0.1 }, ring)
		local delay = (i - 1) * period / count
		pcall(function()
			TweenService:Create(ring, TweenInfo.new(period, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, delay), { Size = UDim2.fromOffset(maxSize or 90, maxSize or 90) }):Play()
			TweenService:Create(stroke, TweenInfo.new(period, Enum.EasingStyle.Quad, Enum.EasingDirection.In, -1, false, delay), { Transparency = 1, Thickness = 0.5 }):Play()
		end)
	end
end

-- Dots orbiting the centre of `parent`.
function Fx.Orbit(parent, color, count, radius, speed, dotSize)
	local dots = {}
	for i = 1, count do
		local dot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromOffset(dotSize or 8, dotSize or 8), ZIndex = (parent.ZIndex or 1) + 2 }, parent)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
		make("UIStroke", { Color = lighten(color, 0.5), Thickness = 1.5, Transparency = 0.3 }, dot)
		dots[i] = dot
	end
	Fx.OnFrame(parent, function(t)
		for i, dot in dots do
			local a = t * (speed or 1.6) + (i / count) * math.pi * 2
			dot.Position = UDim2.new(0.5, math.cos(a) * radius, 0.5, math.sin(a) * radius * 0.55)
		end
	end)
end

-- A gentle up-and-down float for an element.
function Fx.Float(gui, amplitude, speed)
	local base = gui.Position
	Fx.OnFrame(gui, function(t)
		gui.Position = base + UDim2.fromOffset(0, math.sin(t * (speed or 2)) * (amplitude or 4))
	end)
end

-- A heartbeat pulse of size for an element.
function Fx.Pulse(gui, amount, speed)
	local scale = gui:FindFirstChildOfClass("UIScale") or make("UIScale", { Scale = 1 }, gui)
	Fx.OnFrame(gui, function(t)
		scale.Scale = 1 + math.max(0, math.sin(t * (speed or 3))) * (amount or 0.1)
	end)
end

return Fx
