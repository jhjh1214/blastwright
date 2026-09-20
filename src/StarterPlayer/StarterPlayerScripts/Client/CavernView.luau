--!nonstrict
-- Client-side rendering of every player's cavern. The server only sends grid data; visuals are built here,
-- which keeps hundreds of parts off the server and out of replication.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)

local Crystals = Config.Crystals
local CellSize = Config.Tuning.CellSize

local CavernView = {}
local views = {}

local root = Instance.new("Folder")
root.Name = "Caverns"
root.Parent = workspace

local function color(def)
	return Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3])
end

local function part(parent, size, cf, col, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = col
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local ROCK = Color3.fromRGB(38, 42, 56)

-- One silhouette per behavior so crystal types read at a glance.
local builders = {}

function builders.Inert(model, pos, col, rng)
	part(model, Vector3.new(3.4, 0.7, 3.4), CFrame.new(pos + Vector3.new(0, 0.35, 0)), ROCK, Enum.Material.Slate)
	for i, h in { 3.0, 2.1, 1.6 } do
		local a = (i / 3) * math.pi * 2 + rng:NextNumber() * 0.6
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (i == 1 and 0 or 0.9)
		part(model, Vector3.new(0.8, h, 0.8), CFrame.new(pos + off + Vector3.new(0, 0.6 + h / 2, 0)) * CFrame.Angles(math.rad((rng:NextNumber() - 0.5) * 30), a, math.rad((rng:NextNumber() - 0.5) * 30)), col, Enum.Material.Neon)
	end
end

function builders.Volatile(model, pos, col, rng)
	part(model, Vector3.new(3.4, 0.7, 3.4), CFrame.new(pos + Vector3.new(0, 0.35, 0)), ROCK, Enum.Material.Slate)
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * 0.8
		part(model, Vector3.new(1.1, 1.7, 1.1), CFrame.new(pos + off + Vector3.new(0, 1.5, 0)) * CFrame.Angles(math.rad(20) * math.cos(a), a, math.rad(20) * math.sin(a)), col, Enum.Material.Neon)
	end
	part(model, Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0.6, 0.6, 0), Color3.fromRGB(255, 230, 160), Enum.Material.Neon)
end

function builders.Amplifier(model, pos, col, rng)
	part(model, Vector3.new(3.4, 0.7, 3.4), CFrame.new(pos + Vector3.new(0, 0.35, 0)), ROCK, Enum.Material.Slate)
	part(model, Vector3.new(1, 4.4, 1), CFrame.new(pos + Vector3.new(0, 2.9, 0)), col, Enum.Material.Neon)
	part(model, Vector3.new(0.25, 3, 3), CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), col:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Neon, Enum.PartType.Cylinder)
end

function builders.Prism(model, pos, col, rng)
	part(model, Vector3.new(3.4, 0.7, 3.4), CFrame.new(pos + Vector3.new(0, 0.35, 0)), ROCK, Enum.Material.Slate)
	local disc = part(model, Vector3.new(0.5, 3.4, 3.4), CFrame.new(pos + Vector3.new(0, 2.4, 0)), col, Enum.Material.Glass, Enum.PartType.Cylinder)
	disc.Transparency = 0.15
	part(model, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0.7, 0.7, 0), Color3.new(1, 1, 1), Enum.Material.Neon)
end

-- Slowburn: dark egg-shaped body with a glowing fuse ring, so it reads as "a bomb waiting to go".
function builders.Delayed(model, pos, col, rng)
	part(model, Vector3.new(3.4, 0.7, 3.4), CFrame.new(pos + Vector3.new(0, 0.35, 0)), ROCK, Enum.Material.Slate)
	part(model, Vector3.new(2.6, 2.6, 2.6), CFrame.new(pos + Vector3.new(0, 1.9, 0)), Color3.fromRGB(34, 22, 38), Enum.Material.Slate, Enum.PartType.Ball)
	part(model, Vector3.new(0.3, 3.0, 3.0), CFrame.new(pos + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), col, Enum.Material.Neon, Enum.PartType.Cylinder)
	part(model, Vector3.new(0.35, 1.0, 0.35), CFrame.new(pos + Vector3.new(0, 3.6, 0)), col, Enum.Material.Neon)
end

function builders.Unstable(model, pos, col, rng)
	part(model, Vector3.new(3.4, 0.7, 3.4), CFrame.new(pos + Vector3.new(0, 0.35, 0)), Color3.fromRGB(20, 16, 22), Enum.Material.Slate)
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (i == 5 and 0 or 0.9)
		local h = 1.6 + rng:NextNumber() * 1.6
		part(model, Vector3.new(0.6, h, 0.6), CFrame.new(pos + off + Vector3.new(0, 0.6 + h / 2, 0)) * CFrame.Angles(math.rad((rng:NextNumber() - 0.5) * 50), a, math.rad((rng:NextNumber() - 0.5) * 50)), Color3.fromRGB(28, 20, 30), Enum.Material.Slate)
		part(model, Vector3.new(0.35, 0.5, 0.35), CFrame.new(pos + off + Vector3.new(0, 0.6 + h, 0)), col, Enum.Material.Neon)
	end
end

local function buildCrystal(parent, kind, mutated, pos, key)
	local def = Crystals.Defs[kind]
	local model = Instance.new("Model")
	model.Name = "C" .. key
	local rng = Random.new(key * 977)
	local build = builders[def.Behavior] or builders.Inert
	build(model, pos, color(def), rng)
	if mutated then
		part(model, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 4.8, 0)), Color3.fromRGB(255, 150, 230), Enum.Material.Neon, Enum.PartType.Ball)
	end
	model.Parent = parent
	return model
end

function CavernView.Get(userId)
	return views[userId]
end

function CavernView.Remove(userId)
	local view = views[userId]
	if view then
		view.Folder:Destroy()
		views[userId] = nil
	end
end

-- payload from the server's SeamStart remote.
function CavernView.Build(payload)
	CavernView.Remove(payload.UserId)

	local origin = Geometry.Origin(payload.SiteId)
	local size = payload.Size
	local extent = size * CellSize

	local folder = Instance.new("Folder")
	folder.Name = "Cavern_" .. payload.UserId
	folder.Parent = root

	local view = {
		UserId = payload.UserId,
		SiteId = payload.SiteId,
		Origin = origin,
		Size = size,
		Extent = extent,
		Folder = folder,
		Models = {},
		Grid = { Size = size, Cells = {} },
	}
	for _, cell in payload.Cells do
		local key = cell.K
		local x = (key - 1) % size + 1
		local z = (key - 1) // size + 1
		view.Grid.Cells[key] = { Kind = cell.Kind, Mutated = cell.M }
		view.Models[key] = buildCrystal(folder, cell.Kind, cell.M, Geometry.CellPosition(origin, x, z), key)
	end
	views[payload.UserId] = view
	return view
end

-- Visual pop only; grid removal is handled by the caller (Playback).
function CavernView.Pop(view, key)
	local model = view.Models[key]
	if not model then
		return
	end
	view.Models[key] = nil
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			TweenService:Create(p, info, { Size = p.Size * 0.05, Transparency = 1 }):Play()
		end
	end
	task.delay(0.25, function()
		model:Destroy()
	end)
end

return CavernView
