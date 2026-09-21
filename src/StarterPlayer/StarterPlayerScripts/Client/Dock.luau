--!nonstrict
-- The bottom navigation dock: one button per feature (Forge, Shop, Daily, Goals, Codex, Farm), each a flat coloured tile
-- with a hand-drawn icon, a caption and a red badge when something is waiting. Built for touch: 64 px tiles, and the whole
-- dock scales down on narrow screens. Buttons press down like physical keys. No glow.
local Icons = require(script.Parent.Icons)

local Dock = {}

local FONT = Enum.Font.FredokaOne
local TILE = 64

local COLORS = {
	Forge = Color3.fromRGB(232, 120, 60),
	Shop = Color3.fromRGB(222, 80, 150),
	Daily = Color3.fromRGB(60, 178, 120),
	Goals = Color3.fromRGB(226, 170, 40),
	Codex = Color3.fromRGB(70, 140, 220),
	Farm = Color3.fromRGB(120, 180, 50),
}
Dock.Colors = COLORS

local LABELS = { Forge = "Forge", Shop = "Shop", Daily = "Daily", Goals = "Goals", Codex = "Codex", Farm = "Farm" }

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

-- parent: the roaming HUD group. onPress(name) is called when a tile is pressed.
function Dock.Build(parent, onPress)
	local order = { "Forge", "Shop", "Daily", "Goals", "Codex", "Farm" }
	local holder = make("Frame", { Name = "Dock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(#order * (TILE + 12) + 20, TILE + 40), ZIndex = 5 }, parent)
	local scale = make("UIScale", { Scale = 1 }, holder)

	-- a soft dark plate the tiles sit on
	local plate = make("Frame", { BackgroundColor3 = Color3.fromRGB(18, 20, 32), BackgroundTransparency = 0.18, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 5 }, holder)
	make("UICorner", { CornerRadius = UDim.new(0, 22) }, plate)
	make("UIStroke", { Color = Color3.fromRGB(80, 88, 120), Thickness = 1.5, Transparency = 0.4 }, plate)

	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, holder)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, row)

	local tiles = {}
	for i, name in order do
		local color = COLORS[name]
		local cell = make("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(TILE, TILE + 24), LayoutOrder = i, ZIndex = 6 }, row)
		-- the tile's lower edge (gives it thickness) and the face on top of it
		local edge = make("Frame", { BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.45), Position = UDim2.fromOffset(0, 5), Size = UDim2.fromOffset(TILE, TILE), BorderSizePixel = 0, ZIndex = 6 }, cell)
		make("UICorner", { CornerRadius = UDim.new(0, 16) }, edge)
		local face = make("TextButton", { Name = "Face", Text = "", AutoButtonColor = false, BackgroundColor3 = color, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(TILE, TILE), BorderSizePixel = 0, ZIndex = 7 }, cell)
		make("UICorner", { CornerRadius = UDim.new(0, 16) }, face)
		make("UIGradient", { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.22), color:Lerp(Color3.new(0, 0, 0), 0.08)), Rotation = 90 }, face)
		local outline = make("UIStroke", { Name = "Highlight", Color = Color3.fromRGB(255, 240, 170), Thickness = 3, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
		Icons.Draw(name, face, color)
		make("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-6, TILE + 6), Size = UDim2.fromOffset(TILE + 12, 16), Font = FONT, Text = LABELS[name], TextSize = 14, TextColor3 = Color3.fromRGB(235, 238, 250), ZIndex = 7 }, cell)
		local badge = make("Frame", { Name = "Badge", BackgroundColor3 = Color3.fromRGB(235, 70, 70), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(18, 18), Visible = false, ZIndex = 9 }, cell)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
		make("UIStroke", { Color = Color3.fromRGB(18, 20, 32), Thickness = 2 }, badge)

		-- press feel: the face moves down onto its edge
		face.MouseButton1Down:Connect(function()
			face.Position = UDim2.fromOffset(0, 4)
		end)
		local function release()
			face.Position = UDim2.fromOffset(0, 0)
		end
		face.MouseButton1Up:Connect(release)
		face.MouseLeave:Connect(release)
		face.Activated:Connect(function()
			if onPress then
				onPress(name)
			end
		end)
		tiles[name] = { Face = face, Outline = outline, Badge = badge }
	end

	-- shrink on narrow screens so it always fits (phones in portrait)
	local function fit()
		local screen = parent.AbsoluteSize.X
		if screen > 0 then
			scale.Scale = math.clamp((screen - 16) / holder.Size.X.Offset, 0.55, 1)
		end
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local dock = { Holder = holder, Tiles = tiles }
	function dock.SetBadge(name, on)
		if tiles[name] then
			tiles[name].Badge.Visible = on == true
		end
	end
	-- the objective can point at a button: it gets a gold outline that breathes gently
	function dock.SetHighlight(name)
		for tileName, t in tiles do
			t.Outline.Enabled = tileName == name
		end
	end
	-- the tile of the open panel stays pressed down
	function dock.SetSelected(name)
		for tileName, t in tiles do
			t.Face.Position = UDim2.fromOffset(0, tileName == name and 4 or 0)
		end
	end
	function dock.PulseHighlight(alpha)
		for _, t in tiles do
			if t.Outline.Enabled then
				t.Outline.Transparency = alpha
			end
		end
	end
	return dock
end

return Dock
