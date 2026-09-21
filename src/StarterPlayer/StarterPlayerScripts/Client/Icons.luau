--!nonstrict
-- Flat, hand-built icons for the navigation dock (no asset ids): each is drawn from a few rounded rectangles on a 48 x 48
-- canvas and scaled to the requested size. Colours are a light "ink" on top of whatever tile they sit on.
local Icons = {}

local INK = Color3.fromRGB(250, 246, 235)
local SHADE = Color3.fromRGB(38, 34, 54)

local function box(parent, x, y, w, h, color, radius, rotation, z)
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
		c.CornerRadius = UDim.new(0, radius)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local DRAW = {}

DRAW.Forge = function(p, tint)
	-- a hammer: wooden handle, steel head
	box(p, 22, 27, 6, 30, Color3.fromRGB(240, 205, 150), 3, 42, 1)
	box(p, 31, 15, 24, 12, Color3.fromRGB(215, 224, 240), 3, 42, 2)
	box(p, 31, 15, 24, 4, Color3.fromRGB(255, 255, 255), 2, 42, 3)
end

DRAW.Shop = function(p, tint)
	-- a shopping bag: body and a looped handle
	local handle = box(p, 24, 15, 16, 16, Color3.new(1, 1, 1), 8, 0, 1)
	handle.BackgroundTransparency = 1
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = 3
	s.Parent = handle
	box(p, 24, 29, 30, 24, INK, 5, 0, 2)
	box(p, 24, 22, 30, 4, SHADE, 0, 0, 3).BackgroundTransparency = 0.7
	box(p, 17, 25, 4, 4, tint, 2, 0, 4)
	box(p, 31, 25, 4, 4, tint, 2, 0, 4)
end

DRAW.Daily = function(p, tint)
	-- a calendar page with two rings and a grid of days
	box(p, 24, 27, 32, 30, INK, 5, 0, 1)
	box(p, 24, 17, 32, 10, tint, 4, 0, 2)
	box(p, 15, 11, 4, 9, SHADE, 2, 0, 3)
	box(p, 33, 11, 4, 9, SHADE, 2, 0, 3)
	for row = 0, 1 do
		for col = 0, 2 do
			box(p, 14 + col * 10, 28 + row * 9, 6, 6, tint, 2, 0, 3)
		end
	end
end

DRAW.Goals = function(p, tint)
	-- a star from two turned squares
	box(p, 24, 25, 22, 22, INK, 3, 0, 1)
	box(p, 24, 25, 22, 22, INK, 3, 45, 1)
	box(p, 24, 25, 9, 9, tint, 5, 0, 2)
end

DRAW.Codex = function(p, tint)
	-- an open book
	box(p, 17, 26, 18, 30, INK, 3, -5, 1)
	box(p, 31, 26, 18, 30, INK, 3, 5, 1)
	box(p, 24, 27, 3, 31, SHADE, 1, 0, 2).BackgroundTransparency = 0.35
	for i = 0, 2 do
		box(p, 17, 19 + i * 7, 11, 2, tint, 1, -5, 3)
		box(p, 31, 19 + i * 7, 11, 2, tint, 1, 5, 3)
	end
end

DRAW.Farm = function(p, tint)
	-- a sprout in soil
	box(p, 24, 39, 32, 9, Color3.fromRGB(150, 105, 70), 4, 0, 1)
	box(p, 24, 27, 4, 20, Color3.fromRGB(190, 240, 130), 2, 0, 2)
	box(p, 15, 19, 16, 9, Color3.fromRGB(150, 225, 110), 4, -28, 3)
	box(p, 33, 15, 16, 9, Color3.fromRGB(190, 240, 130), 4, 28, 3)
end

-- Draw the icon `name` into `parent` (a square frame): returns the frame holding it. tint = the tile's colour.
function Icons.Draw(name, parent, tint)
	local canvas = Instance.new("Frame")
	canvas.Name = "Icon_" .. name
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(0.72, 0.72)
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.46)
	canvas.ZIndex = (parent.ZIndex or 1) + 1
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = canvas
	local draw = DRAW[name]
	if draw then
		draw(canvas, tint or Color3.fromRGB(90, 90, 120))
	end
	for _, d in canvas:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = canvas.ZIndex + d.ZIndex
		end
	end
	canvas.Parent = parent
	return canvas
end

Icons.Names = { "Forge", "Shop", "Daily", "Goals", "Codex", "Farm" }

return Icons
