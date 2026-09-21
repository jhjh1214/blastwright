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

-- A stroke whose transparency slowly breathes.
function Fx.Glow(gui, color, thickness, period)
	local stroke = make("UIStroke", { Color = color, Thickness = thickness or 2, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, gui)
	pcall(function()
		TweenService:Create(stroke, TweenInfo.new(period or 1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.05 }):Play()
	end)
	return stroke
end

-- A stroke with a colour gradient that slowly travels around the border.
function Fx.AnimatedBorder(gui, colors, thickness, period)
	local stroke = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = thickness or 2, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, gui)
	local keys = {}
	for i, c in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	local grad = make("UIGradient", { Color = ColorSequence.new(keys) }, stroke)
	pcall(function()
		TweenService:Create(grad, TweenInfo.new(period or 6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
	end)
	return stroke
end

-- A soft light band that sweeps across the element (best on buttons and banners). It is an overlay frame, because an
-- object can only show one UIGradient and the element usually has its own.
function Fx.Shimmer(gui, period, strength)
	strength = strength or 0.55
	local overlay = make("Frame", {
		Name = "Shimmer",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = (gui.ZIndex or 1) + 1,
		Active = false,
	}, gui)
	local corner = gui:FindFirstChildOfClass("UICorner")
	if corner then
		make("UICorner", { CornerRadius = corner.CornerRadius }, overlay)
	end
	local grad = make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 1),
			NumberSequenceKeypoint.new(0.5, 1 - strength),
			NumberSequenceKeypoint.new(0.6, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Rotation = 25,
		Offset = Vector2.new(-1, 0),
	}, overlay)
	pcall(function()
		TweenService:Create(grad, TweenInfo.new(period or 2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) }):Play()
	end)
	return overlay
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
		Font = Enum.Font.GothamBlack,
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

return Fx
