--!nonstrict
-- Procedural models for Lurkers and bosses (no asset ids): each kind has its own silhouette, colours and glowing eyes so
-- they read at a glance. Models are built around the origin (PrimaryPart = "Body") and moved with PivotTo. Cosmetic only.
local Creatures = {}

local function part(model, name, shape, size, offset, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Transparency = transparency or 0
	p.CFrame = CFrame.new(offset)
	p.Parent = model
	return p
end

local BALL, BLOCK, CYL = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder

local function eyes(model, y, z, spread, size, color)
	for _, sx in { -1, 1 } do
		part(model, "Eye", BALL, Vector3.new(size, size, size), Vector3.new(sx * spread, y, z), color, Enum.Material.Neon)
	end
end

local function teeth(model, y, z, count, width, color)
	for i = 1, count do
		local x = (i - (count + 1) / 2) * width
		part(model, "Tooth", BLOCK, Vector3.new(width * 0.6, 0.8, 0.5), Vector3.new(x, y, z), color, Enum.Material.SmoothPlastic)
	end
end

local BUILDERS = {}

BUILDERS.Gnasher = function(m)
	local body = part(m, "Body", BALL, Vector3.new(4.4, 3.8, 4.4), Vector3.new(0, 0, 0), Color3.fromRGB(70, 92, 52), Enum.Material.Slate)
	part(m, "Belly", BALL, Vector3.new(3.4, 2.4, 3.4), Vector3.new(0, -0.7, 0.5), Color3.fromRGB(120, 140, 70), Enum.Material.Slate)
	eyes(m, 0.9, 1.9, 1.0, 0.8, Color3.fromRGB(255, 70, 50))
	teeth(m, -0.6, 2.05, 5, 0.75, Color3.fromRGB(240, 235, 210))
	for _, sx in { -1, 1 } do
		part(m, "Claw", BLOCK, Vector3.new(0.5, 0.5, 1.6), Vector3.new(sx * 2.3, -1.2, 0.8), Color3.fromRGB(230, 220, 190), Enum.Material.SmoothPlastic)
	end
	return body
end

BUILDERS.Skitter = function(m)
	local body = part(m, "Body", BALL, Vector3.new(3.0, 1.8, 3.4), Vector3.new(0, 0, 0), Color3.fromRGB(230, 190, 60), Enum.Material.Neon, 0.1)
	part(m, "Shell", BALL, Vector3.new(3.3, 2.0, 3.6), Vector3.new(0, 0.15, 0), Color3.fromRGB(150, 110, 30), Enum.Material.Slate, 0.15)
	eyes(m, 0.2, 1.5, 0.7, 0.6, Color3.fromRGB(255, 255, 140))
	for i = 0, 5 do
		local side = (i % 2 == 0) and -1 or 1
		local z = (math.floor(i / 2) - 1) * 1.1
		part(m, "Leg", BLOCK, Vector3.new(1.8, 0.28, 0.28), Vector3.new(side * 2.2, -0.6, z), Color3.fromRGB(90, 70, 20), Enum.Material.Metal)
	end
	return body
end

BUILDERS.Leech = function(m)
	local body = part(m, "Body", BALL, Vector3.new(5.0, 2.6, 2.8), Vector3.new(0, 0, 0), Color3.fromRGB(120, 50, 150), Enum.Material.SmoothPlastic)
	part(m, "Tail", BALL, Vector3.new(2.2, 1.6, 1.8), Vector3.new(-2.6, -0.2, 0), Color3.fromRGB(95, 35, 125), Enum.Material.SmoothPlastic)
	part(m, "Mouth", CYL, Vector3.new(0.5, 1.5, 1.5), Vector3.new(2.6, 0, 0), Color3.fromRGB(255, 120, 190), Enum.Material.Neon)
	for i = 1, 4 do
		part(m, "Stripe", BLOCK, Vector3.new(0.35, 2.7, 2.9), Vector3.new(-1.6 + i * 0.75, 0, 0), Color3.fromRGB(200, 90, 230), Enum.Material.Neon, 0.3)
	end
	eyes(m, 0.9, 1.0, 1.0, 0.55, Color3.fromRGB(255, 240, 120))
	return body
end

BUILDERS.Sapper = function(m)
	local body = part(m, "Body", BALL, Vector3.new(4.0, 4.0, 4.0), Vector3.new(0, 0, 0), Color3.fromRGB(40, 70, 110), Enum.Material.Metal)
	part(m, "Core", BALL, Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 0, 0), Color3.fromRGB(90, 220, 255), Enum.Material.Neon, 0.25)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0.35 * ((i % 2 == 0) and 1 or -1), math.sin(a)).Unit
		local spike = part(m, "Spike", BLOCK, Vector3.new(0.35, 0.35, 2.2), dir * 3, Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
		spike.CFrame = CFrame.lookAt(dir * 3, dir * 6)
	end
	eyes(m, 0.6, 1.85, 0.8, 0.6, Color3.fromRGB(255, 255, 255))
	return body
end

BUILDERS.Brute = function(m)
	local body = part(m, "Body", BLOCK, Vector3.new(5.6, 4.6, 4.6), Vector3.new(0, 0, 0), Color3.fromRGB(90, 70, 80), Enum.Material.Slate)
	part(m, "Plate", BLOCK, Vector3.new(6.0, 1.6, 5.0), Vector3.new(0, 1.9, 0), Color3.fromRGB(60, 55, 70), Enum.Material.Metal)
	for _, sx in { -1, 1 } do
		local horn = part(m, "Horn", BLOCK, Vector3.new(0.7, 0.7, 2.4), Vector3.new(sx * 2.4, 3.0, 0.4), Color3.fromRGB(235, 225, 200), Enum.Material.SmoothPlastic)
		horn.CFrame = CFrame.new(horn.Position) * CFrame.Angles(math.rad(-40), 0, math.rad(sx * 25))
		part(m, "Fist", BLOCK, Vector3.new(1.8, 1.8, 1.8), Vector3.new(sx * 3.6, -1.2, 0.9), Color3.fromRGB(110, 85, 95), Enum.Material.Slate)
	end
	eyes(m, 0.7, 2.35, 1.3, 0.75, Color3.fromRGB(255, 60, 40))
	teeth(m, -1.0, 2.35, 4, 1.0, Color3.fromRGB(240, 235, 210))
	return body
end

BUILDERS.Titan = function(m)
	local body = part(m, "Body", BLOCK, Vector3.new(11.5, 8, 11.5), Vector3.new(0, 4, 0), Color3.fromRGB(60, 52, 96), Enum.Material.Slate)
	part(m, "Base", BLOCK, Vector3.new(14, 2, 14), Vector3.new(0, 1, 0), Color3.fromRGB(38, 34, 64), Enum.Material.Slate)
	part(m, "Chest", BLOCK, Vector3.new(8, 5, 8), Vector3.new(0, 10.5, 0), Color3.fromRGB(72, 62, 116), Enum.Material.Slate)
	part(m, "Head", BLOCK, Vector3.new(5, 4, 5), Vector3.new(0, 15, 0), Color3.fromRGB(84, 72, 130), Enum.Material.Slate)
	part(m, "Core", BALL, Vector3.new(4.2, 4.2, 4.2), Vector3.new(0, 9.5, 4.2), Color3.fromRGB(255, 200, 60), Enum.Material.Neon)
	eyes(m, 15.3, 2.6, 1.3, 1.0, Color3.fromRGB(255, 220, 80))
	for _, sx in { -1, 1 } do
		part(m, "Arm", BLOCK, Vector3.new(2.6, 9, 2.6), Vector3.new(sx * 7.5, 8, 0), Color3.fromRGB(66, 58, 106), Enum.Material.Slate)
		part(m, "Fist", BLOCK, Vector3.new(3.6, 3.6, 3.6), Vector3.new(sx * 7.5, 2.4, 0), Color3.fromRGB(80, 70, 124), Enum.Material.Slate)
	end
	-- crystal spikes growing out of its back and shoulders
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		local base = Vector3.new(math.cos(a) * 4.5, 12 + (i % 3) * 1.4, math.sin(a) * 4.5 - 1)
		local crystal = part(m, "Crystal", BLOCK, Vector3.new(1.1, 1.1, 4 + (i % 3)), base, Color3.fromRGB(150, 110, 255), Enum.Material.Neon, 0.2)
		crystal.CFrame = CFrame.lookAt(base, base + Vector3.new(math.cos(a) * 3, 4, math.sin(a) * 3))
	end
	return body
end

-- Build a creature model centred on the origin (its "Body" is the PrimaryPart). Unknown kinds get a plain dark ball.
function Creatures.Build(kind)
	local model = Instance.new("Model")
	model.Name = "Creature_" .. tostring(kind)
	local builder = BUILDERS[kind]
	local body
	if builder then
		body = builder(model)
	else
		body = part(model, "Body", BALL, Vector3.new(4.2, 4.2, 4.2), Vector3.new(0, 0, 0), Color3.fromRGB(70, 30, 40), Enum.Material.Slate)
	end
	model.PrimaryPart = body
	return model
end

-- Briefly flash every part of the creature (a hit) by tinting it and letting it fade back.
function Creatures.Flash(model, color)
	local TweenService = game:GetService("TweenService")
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			local original = p.Color
			p.Color = color
			pcall(function()
				TweenService:Create(p, TweenInfo.new(0.25), { Color = original }):Play()
			end)
		end
	end
end

-- The core glows differently per boss phase.
function Creatures.SetPhase(model, phase)
	local core = model:FindFirstChild("Core")
	if not core then
		return
	end
	local colors = {
		Armor = Color3.fromRGB(255, 200, 60),
		Attack = Color3.fromRGB(255, 90, 60),
		Weak = Color3.fromRGB(255, 70, 220),
		Enrage = Color3.fromRGB(255, 30, 30),
		Finisher = Color3.fromRGB(120, 255, 255),
	}
	core.Color = colors[phase] or core.Color
	local body = model:FindFirstChild("Body")
	if body then
		body.Color = phase == "Enrage" and Color3.fromRGB(110, 40, 60) or Color3.fromRGB(60, 52, 96)
	end
end

return Creatures
