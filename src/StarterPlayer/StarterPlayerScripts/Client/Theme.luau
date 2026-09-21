--!nonstrict
-- One place for the look of the whole UI: a chunky, cartoonish, thick-outlined style. Every colour, outline, font and timing
-- used by Kit.luau and the screens comes from here, so the game reads as one design.
local Theme = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- Semantic colours (each system keeps its colour everywhere: dock, cards, banners).
Theme.Colors = {
	Outline = rgb(26, 18, 40), -- the thick dark outline around everything chunky
	Ink = rgb(255, 255, 255), -- text
	Panel = rgb(44, 52, 96), -- menu backing
	PanelDark = rgb(28, 32, 64),
	Shop = rgb(238, 62, 78),
	Forge = rgb(255, 146, 40),
	Daily = rgb(70, 198, 96),
	Goals = rgb(255, 202, 40),
	Codex = rgb(58, 150, 255),
	Farm = rgb(142, 206, 58),
	Boost = rgb(170, 90, 255),
	Action = rgb(255, 98, 54), -- the main "do it" colour (detonate)
	Success = rgb(70, 200, 96),
	Warning = rgb(255, 186, 40),
	Danger = rgb(238, 62, 78),
	Info = rgb(58, 150, 255),
	Premium = rgb(255, 210, 60),
	Neutral = rgb(120, 130, 170),
}

Theme.Stroke = {
	Outer = 4, -- outline of big buttons and panels
	Small = 3, -- outline of small buttons and chips
	Text = 3, -- outline of primary text
	TextSmall = 2,
}

Theme.Font = {
	Display = Enum.Font.FredokaOne, -- huge labels, numbers
	Body = Enum.Font.BuilderSansBold, -- supporting text (kept bold so it stays readable on colour)
}

-- Text sizes: primary is huge, secondary medium, supporting small.
Theme.Type = { Primary = 30, Secondary = 20, Supporting = 15 }

Theme.Anim = {
	Hover = 0.10,
	Press = 0.06,
	Release = 0.14,
	Popup = 0.22,
	Close = 0.14,
	Fill = 0.35,
}

-- Draw order of the big layers (ZIndexBehavior is Sibling, so these order siblings inside the ScreenGui).
Theme.Z = { Hud = 5, Panel = 10, Popup = 20, Feed = 30, Banner = 40, Modal = 50 }

-- Slightly darker / lighter version of a colour (used for button edges and highlights).
function Theme.Shade(c, amount)
	return c:Lerp(Color3.new(0, 0, 0), amount)
end

function Theme.Tint(c, amount)
	return c:Lerp(Color3.new(1, 1, 1), amount)
end

return Theme
