--!nonstrict
-- The world HUD's main navigation, in the chunky style:
--   * a big red SHOP action button (icon + huge label), the primary thing to press;
--   * a vertical stack of square icon buttons above it: Forge, Daily, Goals, Codex, Farm, each its own colour with a big
--     outlined icon and a caption.
-- The whole stack scales down to fit short screens (phone landscape) so the world stays visible. Same API as before:
-- SetBadge, SetHighlight, PulseHighlight, SetSelected.
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Dock = {}

local SIDE = { "Forge", "Daily", "Goals", "Codex", "Farm" }
local COLORS = {
	Forge = Theme.Colors.Forge,
	Shop = Theme.Colors.Shop,
	Daily = Theme.Colors.Daily,
	Goals = Theme.Colors.Goals,
	Codex = Theme.Colors.Codex,
	Farm = Theme.Colors.Farm,
}
Dock.Colors = COLORS

local SIDE_W, SIDE_H, GAP = 84, 92, 8
local SHOP_W, SHOP_H = 214, 88

-- parent: the roaming HUD group. onPress(name) is called when a button is pressed.
function Dock.Build(parent, onPress)
	local totalHeight = #SIDE * (SIDE_H + GAP) + SHOP_H
	local holder = Kit.Make("Frame", { Name = "Dock", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(SHOP_W + 8, totalHeight), ZIndex = Theme.Z.Hud }, parent)
	local scale = Kit.Make("UIScale", { Scale = 1 }, holder)
	Kit.Make("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Left }, holder)

	local buttons, highlights = {}, {}
	local function addHighlight(name, b)
		local ring = Kit.Make("UIStroke", { Color = Color3.fromRGB(255, 244, 150), Thickness = 6, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, b.Face)
		highlights[name] = ring
	end

	for i, name in SIDE do
		local b = Kit.SideButton(holder, { Name = name, Size = UDim2.fromOffset(SIDE_W, SIDE_H), LayoutOrder = i, Color = COLORS[name], Icon = name, Text = string.upper(name), TextSize = 17, OnClick = function() onPress(name) end })
		buttons[name] = b
		addHighlight(name, b)
	end
	local shop = Kit.ActionButton(holder, { Name = "Shop", Size = UDim2.fromOffset(SHOP_W, SHOP_H), LayoutOrder = 100, Color = COLORS.Shop, Icon = "Shop", Text = "SHOP", TextSize = 38, OnClick = function() onPress("Shop") end })
	buttons.Shop = shop
	addHighlight("Shop", shop)

	-- fit: leave the top of the screen (shards, objective) free; shrink the stack on short screens
	local function fit()
		local h = parent.AbsoluteSize.Y
		if h > 0 then
			local available = h - 190
			scale.Scale = math.clamp(available / totalHeight, 0.42, 1)
		end
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local dock = { Holder = holder, Buttons = buttons }
	function dock.SetBadge(name, on)
		if buttons[name] then
			buttons[name].SetBadge(on == true)
		end
	end
	function dock.SetHighlight(name)
		for tileName, ring in highlights do
			ring.Enabled = tileName == name
		end
	end
	function dock.PulseHighlight(alpha)
		for _, ring in highlights do
			if ring.Enabled then
				ring.Transparency = alpha
			end
		end
	end
	function dock.SetSelected(name)
		for tileName, b in buttons do
			b.SetSelected(tileName == name)
		end
	end
	return dock
end

return Dock
