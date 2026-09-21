--!nonstrict
-- Specimen reveals. Finding a specimen should feel like an event, and the bigger the grade, the bigger the moment:
--   Rough / Polished  a feed card (never interrupts play)
--   Faceted           a banner
--   Flawless          a full reveal card: spinning crystal, light rays, shimmering grade name
--   Radiant           the same with a bigger crystal, more rays, a longer hold and a stronger camera punch
--   Celestial         everything above plus a screen flash, the longest hold and the loudest sound
-- Reveals wait for calm mode to end (boss floors and Expeditions) so they never cover the field, and only one shows at a time.
-- Display only: the server rolled the drop and stored it (Shared/Specimens.luau).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TweenService = game:GetService("TweenService")

local Kit = require(script.Parent.Kit)
local Fx = require(script.Parent.Fx)
local Theme = require(script.Parent.Theme)
local Feed = require(script.Parent.Feed)
local Calm = require(script.Parent.Calm)
local AudioManager = require(script.Parent.AudioManager)
local CameraFeedback = require(script.Parent.CameraFeedback)

local Reveal = {}

local gui
local queue = {}
local busy = false

local INDEX = {}
for i, r in Config.Specimens.Rarities do
	INDEX[r.Id] = i
end

local function color(r)
	return Color3.fromRGB(r.Color[1], r.Color[2], r.Color[3])
end

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function gradeOf(id)
	return Config.Specimens.Rarities[INDEX[id] or 1]
end

local function titleFor(drop)
	local grade = gradeOf(drop.Rarity)
	local crystal = Config.Crystals.Defs[drop.Kind]
	return grade.Name .. " " .. (crystal and crystal.Name or drop.Kind), grade
end

local function commas(n)
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- One sound signature per grade, built only from the verified cues in Config/Sounds.luau by pitch, volume and layering:
-- Rough: a soft coin; Polished: a brighter coin; Faceted: the diamond bling; Flawless: bling plus coin; Radiant: a rising
-- three-note bling with a coin on top; Celestial: a longer rising run of blings under a deep boom. Never fails gameplay.
local SIGNATURES = {
	{ { "Reward", 0, 0.35, 0.9 } },
	{ { "Reward", 0, 0.5, 1.2 } },
	{ { "Tier", 0, 0.6, 1.0 } },
	{ { "Tier", 0, 0.8, 1.1 }, { "Reward", 0.12, 0.6, 1.4 } },
	{ { "Tier", 0, 0.8, 1.0 }, { "Tier", 0.16, 0.85, 1.25 }, { "Tier", 0.32, 0.9, 1.5 }, { "Reward", 0.4, 0.7, 1.7 } },
	{ { "Detonate", 0, 0.45, 0.5 }, { "Tier", 0.05, 0.9, 0.9 }, { "Tier", 0.22, 0.9, 1.1 }, { "Tier", 0.39, 0.95, 1.35 }, { "Tier", 0.56, 1, 1.7 }, { "Reward", 0.7, 0.8, 1.9 } },
}
local function playSignature(index)
	for _, note in SIGNATURES[math.clamp(index, 1, #SIGNATURES)] do
		local cue, delay, volume, pitch = note[1], note[2], note[3], note[4]
		task.delay(delay, function()
			pcall(AudioManager.Play, cue, { Volume = volume, Pitch = pitch })
		end)
	end
end

-- The full reveal card (Flawless and up).
local function card(drop, done)
	local index = INDEX[drop.Rarity] or 4
	local name, grade = titleFor(drop)
	local col = color(grade)
	local top = index >= 6
	local big = index >= 5
	local hold = top and 6.5 or (big and 5 or 4)

	local dim = make("Frame", { Name = "SpecimenReveal", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = Theme.Z.Modal, Active = true }, gui)
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()

	-- light rays behind the card, slowly turning
	local rays = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(700, 700), ZIndex = Theme.Z.Modal + 1 }, dim)
	local rayCount = top and 14 or (big and 10 or 8)
	for i = 1, rayCount do
		local ray = make("Frame", { BackgroundColor3 = col, BackgroundTransparency = 0.72, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 14), Rotation = (i - 1) * (180 / rayCount), BorderSizePixel = 0, ZIndex = Theme.Z.Modal + 1 }, rays)
		make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, ray)
	end
	Fx.OnFrame(rays, function(t)
		rays.Rotation = t * (top and 24 or 14)
	end)

	local panel = make("Frame", { BackgroundColor3 = Theme.Colors.Panel, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 380), ZIndex = Theme.Z.Modal + 2 }, dim)
	make("UISizeConstraint", { MaxSize = Vector2.new(420, 420) }, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 24) }, panel)
	local stroke = make("UIStroke", { Color = col, Thickness = 6, LineJoinMode = Enum.LineJoinMode.Round }, panel)
	make("UIGradient", { Color = ColorSequence.new(Theme.Tint(Theme.Colors.Panel, 0.14), Theme.Shade(Theme.Colors.Panel, 0.35)), Rotation = 90 }, panel)
	local scale = make("UIScale", { Scale = 0.4 }, panel)
	Fx.OnFrame(stroke, function(t)
		stroke.Thickness = 5 + math.sin(t * 5) * 1.5
	end)

	-- grade name: big, outlined, with a moving shine
	local head = make("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.new(0.92, 0, 0, 50), Font = Theme.Font.Display, Text = string.upper(drop.Rarity == "Mythic" and "Celestial find!" or (grade.Name .. " find!")), TextSize = 40, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = Theme.Z.Modal + 3 }, panel)
	make("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 16 }, head)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round }, head)
	local shine = make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, col), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, col) }) }, head)
	Fx.OnFrame(head, function(t)
		shine.Offset = Vector2.new(math.sin(t * 2.2) * 0.7, 0)
	end)

	local gemHolder = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 68), Size = UDim2.fromOffset(top and 190 or 160, top and 190 or 160), ZIndex = Theme.Z.Modal + 3 }, panel)
	local crystal = Config.Crystals.Defs[drop.Kind]
	local gemColor = crystal and Color3.fromRGB(crystal.Color[1], crystal.Color[2], crystal.Color[3]) or col
	local gem = Fx.Gem(gemHolder, gemColor:Lerp(col, 0.35), top and 190 or 160)
	gem.ZIndex = Theme.Z.Modal + 4

	local nameLabel = make("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 236), Size = UDim2.new(0.94, 0, 0, 30), Font = Theme.Font.Display, Text = name, TextSize = 24, TextColor3 = col:Lerp(Color3.new(1, 1, 1), 0.35), TextScaled = true, ZIndex = Theme.Z.Modal + 3 }, panel)
	make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 12 }, nameLabel)
	make("UIStroke", { Color = Theme.Colors.Outline, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round }, nameLabel)

	local sub = drop.New and "NEW! Added to your Specimen Cabinet" or ("Duplicate x%d: +%s shards"):format(drop.Count, commas(drop.Dust))
	make("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 272), Size = UDim2.new(0.92, 0, 0, 22), Font = Theme.Font.Body, Text = sub, TextSize = 16, TextColor3 = drop.New and Theme.Colors.Success or Color3.fromRGB(230, 236, 255), TextWrapped = true, ZIndex = Theme.Z.Modal + 3 }, panel)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.2 }):Play()
		TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		task.delay(0.28, function()
			dim:Destroy()
			done()
		end)
	end
	Kit.Button(panel, { Name = "Nice", Size = UDim2.fromOffset(170, 54), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Color = Theme.Colors.Success, Text = "NICE!", TextSize = 26, Depth = 6, Corner = 14, OnClick = close })

	-- pop in with a bounce, then the effects
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	pcall(function()
		playSignature(index)
		CameraFeedback.Punch(top and 6 or (big and 4 or 2))
	end)
	if top then
		-- a white flash that fades: the only place the whole screen is covered, for the rarest find in the game
		local flash = make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1), ZIndex = Theme.Z.Modal + 6, Active = false }, dim)
		TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
		task.delay(0.8, function()
			flash:Destroy()
		end)
	end
	task.delay(hold, close)
end

local function pump()
	if busy or #queue == 0 or not gui then
		return
	end
	-- never cover a boss fight or an Expedition: wait until it is over
	if Calm.On then
		task.delay(2, pump)
		return
	end
	local drop = table.remove(queue, 1)
	local index = INDEX[drop.Rarity] or 1
	local name, grade = titleFor(drop)
	local tail = drop.New and "New in your cabinet!" or ("Duplicate: +%s shards"):format(commas(drop.Dust))
	if index <= 3 then
		playSignature(index)
	end
	if index <= 2 then
		pcall(Feed.Push, "Reward", name, tail)
		task.defer(pump)
	elseif index == 3 then
		pcall(Feed.Banner, "FACETED FIND", name .. "  -  " .. tail, color(grade), 2.2, true)
		task.defer(pump)
	else
		busy = true
		local ok = pcall(card, drop, function()
			busy = false
			pump()
		end)
		if not ok then
			busy = false
		end
	end
end

function Reveal.Init(screenGui)
	gui = screenGui
end

function Reveal.Show(drop)
	if type(drop) ~= "table" or not INDEX[drop.Rarity] then
		return
	end
	if #queue >= 6 then
		table.remove(queue, 1) -- a long backlog drops the oldest waiting reveal
	end
	table.insert(queue, drop)
	pump()
end

return Reveal
