--!nonstrict
-- Icons drawn in code (there are no verified icon assets in the project, and none are invented): chunky, multi-coloured shapes
-- with a dark outline, meant to sit big on a coloured button. Each is built from rounded rectangles on a 48 x 48 canvas and
-- scales to any size. Names: Forge, Shop, Daily, Goals, Codex, Farm, Gem, Bomb, Bolt, Close, Heart, Lock.
local Theme = require(script.Parent.Theme)

local Icons = {}

-- Painted icons can replace the drawn ones: put a REAL image asset id (from the Creator Store or your own upload) here and
-- that button/tile uses the image instead. Leave nil to keep the drawn icon. Never invent an id.
Icons.Assets = {
	-- Forge = "rbxassetid://...",
}

local OUT = Theme.Colors.Outline
local WHITE = Color3.fromRGB(255, 255, 255)

-- A filled, outlined rounded box. Coordinates are on the 48 x 48 canvas (centre-based).
local function box(parent, x, y, w, h, color, radius, rotation, z, noOutline)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(x / 48, 0, y / 48, 0)
	f.Size = UDim2.new(w / 48, 0, h / 48, 0)
	f.Rotation = rotation or 0
	f.ZIndex = z or 1
	if radius and radius > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = radius >= 99 and UDim.new(1, 0) or UDim.new(0, radius)
		c.Parent = f
	end
	if not noOutline then
		local s = Instance.new("UIStroke")
		s.Color = OUT
		s.Thickness = 2.5
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = f
	end
	f.Parent = parent
	return f
end

local DRAW = {}

DRAW.Forge = function(p)
	box(p, 21, 28, 7, 30, Color3.fromRGB(196, 128, 66), 3, 40, 1) -- handle
	box(p, 32, 15, 26, 14, Color3.fromRGB(214, 224, 244), 4, 40, 2) -- head
	box(p, 32, 12, 22, 4, WHITE, 2, 40, 3, true)
end

DRAW.Shop = function(p)
	local handle = box(p, 24, 14, 18, 18, WHITE, 99, 0, 1)
	handle.BackgroundTransparency = 1
	local s = handle:FindFirstChildOfClass("UIStroke")
	s.Color = WHITE
	s.Thickness = 4.5
	box(p, 24, 30, 32, 26, Color3.fromRGB(255, 244, 205), 6, 0, 2)
	box(p, 24, 23, 32, 6, Color3.fromRGB(255, 200, 70), 3, 0, 3)
	box(p, 17, 27, 5, 5, OUT, 99, 0, 4, true)
	box(p, 31, 27, 5, 5, OUT, 99, 0, 4, true)
end

DRAW.Daily = function(p)
	box(p, 24, 27, 34, 32, WHITE, 6, 0, 1)
	box(p, 24, 15, 34, 12, Color3.fromRGB(240, 70, 82), 5, 0, 2)
	box(p, 15, 10, 5, 11, Color3.fromRGB(70, 56, 100), 3, 0, 3)
	box(p, 33, 10, 5, 11, Color3.fromRGB(70, 56, 100), 3, 0, 3)
	for row = 0, 1 do
		for col = 0, 2 do
			box(p, 14 + col * 10, 28 + row * 9, 6, 6, Color3.fromRGB(70, 198, 96), 2, 0, 3, true)
		end
	end
end

DRAW.Goals = function(p)
	box(p, 24, 25, 26, 26, Color3.fromRGB(255, 208, 50), 4, 0, 1)
	box(p, 24, 25, 26, 26, Color3.fromRGB(255, 208, 50), 4, 45, 1)
	box(p, 24, 25, 12, 12, Color3.fromRGB(255, 240, 150), 99, 0, 3, true)
end

DRAW.Codex = function(p)
	box(p, 24, 28, 36, 30, Color3.fromRGB(196, 70, 80), 5, 0, 1) -- cover
	box(p, 17, 25, 17, 28, WHITE, 3, -4, 2)
	box(p, 31, 25, 17, 28, WHITE, 3, 4, 2)
	box(p, 24, 26, 3, 30, OUT, 1, 0, 3, true)
	for i = 0, 2 do
		box(p, 17, 17 + i * 7, 10, 2, Color3.fromRGB(58, 150, 255), 1, -4, 3, true)
		box(p, 31, 17 + i * 7, 10, 2, Color3.fromRGB(58, 150, 255), 1, 4, 3, true)
	end
end

DRAW.Farm = function(p)
	box(p, 24, 39, 34, 10, Color3.fromRGB(150, 98, 60), 5, 0, 1)
	box(p, 24, 26, 5, 24, Color3.fromRGB(74, 170, 70), 2, 0, 2)
	box(p, 14, 18, 18, 10, Color3.fromRGB(110, 210, 90), 5, -28, 3)
	box(p, 34, 14, 18, 10, Color3.fromRGB(150, 230, 100), 5, 28, 3)
end

DRAW.Gem = function(p)
	box(p, 24, 25, 26, 26, Color3.fromRGB(70, 210, 255), 5, 45, 1)
	box(p, 24, 25, 12, 12, Color3.fromRGB(190, 245, 255), 3, 45, 2, true)
	box(p, 18, 18, 5, 5, WHITE, 99, 0, 3, true)
end

DRAW.Bomb = function(p)
	box(p, 22, 28, 32, 32, Color3.fromRGB(58, 58, 84), 99, 0, 1)
	box(p, 15, 20, 9, 7, Color3.fromRGB(150, 156, 190), 99, -30, 2, true)
	box(p, 34, 12, 6, 14, Color3.fromRGB(196, 128, 66), 3, 35, 2)
	box(p, 39, 7, 10, 10, Color3.fromRGB(255, 214, 64), 99, 45, 3)
	box(p, 39, 7, 4, 4, WHITE, 99, 0, 4, true)
end

DRAW.Bolt = function(p)
	box(p, 26, 14, 14, 20, Color3.fromRGB(255, 214, 64), 3, 25, 1)
	box(p, 22, 32, 14, 20, Color3.fromRGB(255, 214, 64), 3, 25, 1)
	box(p, 24, 24, 24, 9, Color3.fromRGB(255, 232, 110), 3, -10, 2, true)
end

DRAW.Close = function(p)
	box(p, 24, 24, 34, 9, WHITE, 4, 45, 1)
	box(p, 24, 24, 34, 9, WHITE, 4, -45, 1)
end

DRAW.Heart = function(p)
	box(p, 16, 19, 18, 18, Color3.fromRGB(240, 70, 92), 99, 0, 1)
	box(p, 32, 19, 18, 18, Color3.fromRGB(240, 70, 92), 99, 0, 1)
	box(p, 24, 27, 22, 22, Color3.fromRGB(240, 70, 92), 4, 45, 2)
	box(p, 15, 15, 5, 5, WHITE, 99, 0, 3, true)
end

DRAW.Lock = function(p)
	local shackle = box(p, 24, 15, 20, 22, WHITE, 99, 0, 1)
	shackle.BackgroundTransparency = 1
	local s = shackle:FindFirstChildOfClass("UIStroke")
	s.Color = Color3.fromRGB(190, 196, 220)
	s.Thickness = 5
	box(p, 24, 31, 30, 22, Color3.fromRGB(255, 208, 50), 5, 0, 2)
	box(p, 24, 30, 5, 9, OUT, 2, 0, 3, true)
end

-- Draw the icon `name` filling `parent`. Returns the canvas (a square, centred).
function Icons.Draw(name, parent, tint, fill)
	local canvas = Instance.new("Frame")
	canvas.Name = "Icon_" .. name
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(fill or 0.8, fill or 0.8)
	canvas.ZIndex = (parent.ZIndex or 1) + 1
	local asset = Icons.Assets[name]
	if asset then
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = asset
		image.ScaleType = Enum.ScaleType.Fit
		image.ZIndex = canvas.ZIndex + 1
		image.Parent = canvas
	else
		local draw = DRAW[name]
		if draw then
			draw(canvas, tint)
		end
	end
	for _, d in canvas:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = canvas.ZIndex + d.ZIndex
		end
	end
	canvas.Parent = parent
	return canvas
end

Icons.Names = { "Forge", "Shop", "Daily", "Goals", "Codex", "Farm", "Gem", "Bomb", "Bolt", "Close", "Heart", "Lock" }

return Icons
