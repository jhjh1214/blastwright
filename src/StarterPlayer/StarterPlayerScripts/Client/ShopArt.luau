--!nonstrict
-- Shop product cards with procedural artwork (no asset ids): every offer gets animated art that shows what it is:
-- spinning gem piles for shards, ringed "x2" badges for boosts, a beating heart for revives, an exploding rings preview in
-- the finisher's own colours, glowing orbs for blast colours, a fanned stack of icons for bundles. Cosmetic only.
local Fx = require(script.Parent.Fx)

local ShopArt = {}

ShopArt.TierColor = {
	Tiny = Color3.fromRGB(120, 220, 170),
	Small = Color3.fromRGB(90, 190, 255),
	Medium = Color3.fromRGB(190, 120, 255),
	Large = Color3.fromRGB(255, 150, 60),
	Premium = Color3.fromRGB(255, 205, 90),
}

local GOLD = Color3.fromRGB(255, 205, 90)
local FONT = Enum.Font.FredokaOne

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function text(parent, str, size, color, props)
	local p = { BackgroundTransparency = 1, Font = FONT, Text = str, TextSize = size, TextColor3 = color, TextStrokeTransparency = 0.35, ZIndex = (parent.ZIndex or 1) + 3 }
	for k, v in props or {} do
		p[k] = v
	end
	return make("TextLabel", p, parent)
end

local function centred(parent, size, extra)
	local p = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size, BackgroundTransparency = 1, ZIndex = (parent.ZIndex or 1) + 2 }
	for k, v in extra or {} do
		p[k] = v
	end
	return make("Frame", p, parent)
end

-- The look of one grant, as art. `art` = { Kind, ... } (see fromGrant).
local BUILD = {}

BUILD.Gems = function(parent, art)
	local n = art.Count
	for i = 1, n do
		local offset = (i - (n + 1) / 2) * 34
		local size = 52 + (n == 1 and 20 or 0) - math.abs(i - (n + 1) / 2) * 6
		local holder = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, offset, 0.5, math.abs(i - (n + 1) / 2) * 8), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = (parent.ZIndex or 1) + 2 }, parent)
		Fx.Gem(holder, art.Color, size)
	end
	Fx.Sparkles(parent, 10, Color3.fromRGB(255, 240, 180))
end

BUILD.Boost = function(parent, art)
	Fx.Rings(parent, art.Color, 2, 2, 96)
	local holder = centred(parent, UDim2.fromOffset(100, 60))
	text(holder, "x" .. tostring(art.Mult), 46, art.Color, { Size = UDim2.fromScale(1, 0.75), TextStrokeColor3 = Fx.Darken(art.Color, 0.6) })
	text(holder, art.Label, 14, Color3.new(1, 1, 1), { Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(1, 0.28) })
	Fx.Float(holder, 3, 2.4)
	Fx.Sparkles(parent, 8, art.Color)
end

BUILD.Revive = function(parent, art)
	Fx.Rings(parent, Color3.fromRGB(255, 90, 110), 2, 1.4, 90)
	local heart = text(centred(parent, UDim2.fromOffset(80, 80)), "♥", 68, Color3.fromRGB(255, 80, 100), { Size = UDim2.fromScale(1, 1), TextStrokeColor3 = Color3.fromRGB(120, 10, 40) })
	Fx.Pulse(heart, 0.14, 4)
	Fx.Sparkles(parent, 8, Color3.fromRGB(255, 190, 200))
end

BUILD.Charge = function(parent, art)
	local row = centred(parent, UDim2.fromOffset(120, 50))
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8) }, row)
	for i = 1, 3 do
		local orb = make("Frame", { BackgroundColor3 = Color3.fromRGB(255, 170, 60), Size = UDim2.fromOffset(30, 30), BorderSizePixel = 0, LayoutOrder = i, ZIndex = (row.ZIndex or 1) + 1 }, row)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, orb)
		Fx.Depth(orb, 0.4)
		make("UIStroke", { Color = Color3.fromRGB(255, 230, 150), Thickness = 2, Transparency = 0.2 }, orb)
		Fx.Pulse(orb, 0.18, 3 + i * 0.6)
	end
	Fx.Sparkles(parent, 8, Color3.fromRGB(255, 220, 150))
end

BUILD.Finisher = function(parent, art)
	Fx.Rings(parent, art.Color, 3, 1.7, 120)
	local core = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Fx.Lighten(art.Color, 0.5), BorderSizePixel = 0, ZIndex = (parent.ZIndex or 1) + 3 }, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, core)
	Fx.Glow(core, art.Color, 4, 0.5)
	Fx.Pulse(core, 0.25, 5)
	Fx.Orbit(parent, art.Color, 6, 46, 2.2, 7)
	Fx.Sparkles(parent, 14, art.Color)
end

BUILD.Orb = function(parent, art)
	local orb = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = art.Color, BorderSizePixel = 0, ZIndex = (parent.ZIndex or 1) + 3 }, parent)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, orb)
	Fx.Gradient(orb, Fx.Lighten(art.Color, 0.5), Fx.Darken(art.Color, 0.35), 60)
	orb.BackgroundColor3 = Color3.new(1, 1, 1)
	Fx.Glow(orb, art.Color, 4, 1)
	Fx.Pulse(orb, 0.1, 2.5)
	Fx.Orbit(parent, Fx.Lighten(art.Color, 0.3), 4, 52, 1.8, 8)
	Fx.Sparkles(parent, 8, art.Color)
end

BUILD.Title = function(parent, art)
	local ribbon = centred(parent, UDim2.fromOffset(170, 40), { BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1) })
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, ribbon)
	Fx.Gradient(ribbon, Color3.fromRGB(120, 70, 20), Color3.fromRGB(60, 30, 10), 90)
	Fx.AnimatedBorder(ribbon, { GOLD, Color3.fromRGB(255, 100, 200), GOLD }, 2, 4)
	text(ribbon, art.Text, 18, GOLD, { Size = UDim2.fromScale(1, 1) })
	Fx.Shimmer(ribbon, 2.2, 0.5)
	Fx.Sparkles(parent, 10, GOLD)
end

BUILD.Crown = function(parent, art)
	Fx.Rings(parent, GOLD, 2, 2.2, 100)
	local star = text(centred(parent, UDim2.fromOffset(90, 90)), "★", 76, GOLD, { Size = UDim2.fromScale(1, 1), TextStrokeColor3 = Color3.fromRGB(120, 70, 0) })
	Fx.Pulse(star, 0.12, 2.5)
	Fx.Orbit(parent, Color3.fromRGB(255, 240, 170), 5, 48, 1.4, 7)
end

-- Bundles: a fanned stack of small tiles, one per thing inside.
BUILD.Bundle = function(parent, art)
	local items = art.Items
	local n = #items
	for i, item in items do
		local tile = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (i - (n + 1) / 2) * 34, 0.5, math.abs(i - (n + 1) / 2) * 6),
			Rotation = (i - (n + 1) / 2) * 12,
			Size = UDim2.fromOffset(52, 64),
			BackgroundColor3 = item.Color,
			BorderSizePixel = 0,
			ZIndex = (parent.ZIndex or 1) + 2 + i,
		}, parent)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, tile)
		Fx.Depth(tile, 0.45)
		make("UIStroke", { Color = Fx.Lighten(item.Color, 0.5), Thickness = 2, Transparency = 0.2 }, tile)
		text(tile, item.Glyph, 24, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 0.7) })
		text(tile, item.Label or "", 11, Color3.new(1, 1, 1), { Position = UDim2.fromScale(0, 0.68), Size = UDim2.fromScale(1, 0.3) })
	end
	Fx.Rings(parent, GOLD, 2, 2.4, 110)
	Fx.Sparkles(parent, 14, Color3.fromRGB(255, 235, 170))
end

-- One grant -> an art spec ------------------------------------------------------------------------------------------------

local function shardCount(amount)
	if amount <= 3000 then
		return 1
	elseif amount <= 15000 then
		return 2
	elseif amount <= 60000 then
		return 3
	end
	return 5
end

local function short(n)
	if n >= 1000 then
		return ("%dk"):format(n // 1000)
	end
	return tostring(n)
end

-- ctx = { Cosmetics = Config.Cosmetics.Defs, Finishers = Config.Finishers.Defs }
local function fromGrant(g, ctx)
	if g.Kind == "Shards" then
		return { Kind = "Gems", Count = shardCount(g.Amount), Color = GOLD, Glyph = "◆", Label = short(g.Amount) .. (g.Scaled and "+" or ""), TileColor = Color3.fromRGB(230, 170, 40) }
	elseif g.Kind == "Boost" then
		local color = g.Boost == "Luck" and Color3.fromRGB(255, 110, 230) or GOLD
		return { Kind = "Boost", Color = color, Mult = g.Mult, Label = ("%d min"):format(g.Seconds // 60), Glyph = "x" .. tostring(g.Mult), TileColor = Fx.Darken(color, 0.15) }
	elseif g.Kind == "Tokens" and g.Token == "Revive" then
		return { Kind = "Revive", Glyph = "♥", Label = "x" .. g.Count, TileColor = Color3.fromRGB(220, 60, 90) }
	elseif g.Kind == "Tokens" then
		return { Kind = "Charge", Glyph = "●", Label = "x" .. g.Count, TileColor = Color3.fromRGB(240, 150, 40) }
	elseif g.Kind == "Finisher" then
		local color = Color3.fromRGB(255, 205, 90)
		for _, def in ctx.Finishers do
			if def.Id == g.Id then color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]) end
		end
		return { Kind = "Finisher", Color = color, Glyph = "✦", Label = "Finish", TileColor = Fx.Darken(color, 0.2) }
	elseif g.Kind == "Cosmetic" then
		local color = Color3.fromRGB(255, 170, 60)
		for _, def in ctx.Cosmetics do
			if def.Id == g.Id then color = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]) end
		end
		return { Kind = "Orb", Color = color, Glyph = "●", Label = "Blast", TileColor = Fx.Darken(color, 0.2) }
	elseif g.Kind == "Title" then
		return { Kind = "Title", Text = g.Title, Glyph = "★", Label = "Title", TileColor = Color3.fromRGB(190, 130, 30) }
	end
	return { Kind = "Crown", Glyph = "◆", TileColor = GOLD }
end

-- Art for a list of grants: one grant gets its own art, several make a bundle fan.
function ShopArt.FromGrants(grants, ctx)
	if #grants == 1 then
		return fromGrant(grants[1], ctx)
	end
	local items = {}
	for _, g in grants do
		local a = fromGrant(g, ctx)
		table.insert(items, { Glyph = a.Glyph, Label = a.Label, Color = a.TileColor })
		if #items == 5 then
			break
		end
	end
	return { Kind = "Bundle", Items = items }
end

function ShopArt.Boost(mult, label, color)
	return { Kind = "Boost", Color = color, Mult = mult, Label = label }
end

function ShopArt.Orb(color)
	return { Kind = "Orb", Color = color }
end

function ShopArt.Gems(count, color)
	return { Kind = "Gems", Count = count, Color = color or GOLD }
end

function ShopArt.Crown()
	return { Kind = "Crown" }
end

-- A product card in a grid: art on top, name, description, a price hint and the buy button.
-- spec = { Name, Description, Art, Tier, Badge, Hint = "≈ R$ 49", Button, Enabled, OnClick, Order }
function ShopArt.Card(parent, spec)
	local color = ShopArt.TierColor[spec.Tier] or Color3.fromRGB(120, 200, 255)
	local card = make("Frame", { BackgroundColor3 = Color3.fromRGB(34, 40, 62), LayoutOrder = spec.Order or 0, ClipsDescendants = true, ZIndex = 12 }, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, card)
	Fx.Depth(card, 0.25)
	Fx.AnimatedBorder(card, { color, Fx.Lighten(color, 0.5), color }, 2.5, 5)

	local art = make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 108), ClipsDescendants = true, ZIndex = 12 }, card)
	Fx.Gradient(art, Fx.Darken(color, 0.55), Fx.Darken(color, 0.85), 90)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, art)
	local build = BUILD[spec.Art.Kind]
	if build then
		pcall(build, art, spec.Art)
	end

	-- tier ribbon (top left) and badge (top right)
	local ribbon = make("Frame", { BackgroundColor3 = color, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(64, 20), BorderSizePixel = 0, ZIndex = 20 }, card)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, ribbon)
	text(ribbon, string.upper(spec.Tier or ""), 11, Color3.fromRGB(20, 22, 34), { Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 1, ZIndex = 21 })
	if spec.Badge then
		local badge = make("Frame", { AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(255, 70, 110), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(#spec.Badge * 8 + 16, 20), BorderSizePixel = 0, ZIndex = 20 }, card)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, badge)
		text(badge, spec.Badge, 11, Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 1), ZIndex = 21 })
		Fx.Shimmer(badge, 1.8, 0.7)
		Fx.Pulse(badge, 0.06, 3)
	end

	text(card, spec.Name, 17, Color3.fromRGB(240, 244, 255), { Position = UDim2.fromOffset(10, 112), Size = UDim2.new(1, -20, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 14, TextTruncate = Enum.TextTruncate.AtEnd })
	text(card, spec.Description, 12, Color3.fromRGB(160, 170, 195), { Font = Enum.Font.BuilderSansMedium, Position = UDim2.fromOffset(10, 134), Size = UDim2.new(1, -20, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextStrokeTransparency = 1, ZIndex = 14 })

	if spec.Hint then
		local chip = make("Frame", { AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.fromRGB(20, 24, 38), Position = UDim2.new(0, 10, 1, -8), Size = UDim2.fromOffset(74, 30), BorderSizePixel = 0, ZIndex = 14 }, card)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, chip)
		make("UIStroke", { Color = color, Thickness = 1.5, Transparency = 0.5 }, chip)
		text(chip, spec.Hint, 14, Fx.Lighten(color, 0.3), { Size = UDim2.fromScale(1, 1), ZIndex = 15 })
	end
	local button = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = spec.Enabled and Fx.Lighten(color, 0.1) or Color3.fromRGB(44, 50, 74),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.new(1, -100, 0, 30),
		Font = FONT,
		Text = spec.Button,
		TextSize = 15,
		TextColor3 = spec.Enabled and Color3.fromRGB(20, 22, 34) or Color3.fromRGB(150, 160, 185),
		AutoButtonColor = true,
		ZIndex = 15,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
	Fx.Depth(button, 0.28)
	Fx.Hover(button)
	if spec.Enabled then
		Fx.Shimmer(button, 2.4, 0.6)
		Fx.Glow(button, Fx.Lighten(color, 0.5), 2, 1.1)
	end
	button.Activated:Connect(function()
		if spec.OnClick then
			spec.OnClick()
		end
	end)
	return card
end

return ShopArt
