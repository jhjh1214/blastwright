--!nonstrict
-- The world HUD's main navigation, in the chunky style:
--   * a big red SHOP action button (icon + huge label), the primary thing to press;
--   * a vertical stack of square icon buttons above it: Forge, Loadout, Daily, Goals, Codex, Farm, each its own colour with a big
--     outlined icon and a caption.
-- The whole stack scales down to fit short screens (phone landscape) so the world stays visible. Same API as before:
-- SetBadge, SetHighlight, PulseHighlight, SetSelected.
local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)

local Dock = {}

local SIDE = { "Forge", "Loadout", "Daily", "Goals", "Codex", "Farm" }
local COLORS = {
	Forge = Theme.Colors.Forge,
	Loadout = Color3.fromRGB(255, 96, 76),
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
-- getTopCard: returns the objective card above the stack (or nil); the stack shrinks to stay clear of it.
function Dock.Build(parent, getTopCard, onPress)
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

	-- fit: stay below the shards, cave counter and objective card; shrink on short screens
	local function fit()
		local h = parent.AbsoluteSize.Y
		if h <= 0 then
			return
		end
		local top = 96 -- shards pill and cave counter
		local card = getTopCard and getTopCard()
		if card and card.Visible and card.AbsoluteSize.Y > 0 then
			top = math.max(top, card.AbsolutePosition.Y - parent.AbsolutePosition.Y + card.AbsoluteSize.Y + 6)
		end
		local available = h - 12 - top
		scale.Scale = math.clamp(available / totalHeight, 0.4, 1)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	local card = getTopCard and getTopCard()
	if card then
		card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		card:GetPropertyChangedSignal("Visible"):Connect(fit)
	end
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
