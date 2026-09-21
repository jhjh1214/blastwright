--!nonstrict
-- Client-side rendering of every player's cavern. The server only sends grid data; visuals are built here,
-- which keeps hundreds of parts off the server and out of replication.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Creatures = require(script.Parent.Creatures)

local Crystals = Config.Crystals
local CellSize = Config.Tuning.CellSize

local CavernView = {}
local views = {}

local root = Instance.new("Folder")
root.Name = "Caverns"
root.Parent = workspace

-- Slightly darker than the config color so Neon reads as a glow accent, not a blown-out white.
local function color(def)
	return Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]):Lerp(Color3.new(0, 0, 0), 0.22)
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

-- Matte shards with small glowing accents: the crystals read clearly without radiating light.
local SHARD = Config.Tuning.NeonShards and Enum.Material.Neon or Enum.Material.SmoothPlastic
local function glow(c)
	return c:Lerp(Color3.new(0, 0, 0), Config.Tuning.AccentDarken)
end

-- A lumpy half-buried rock instead of a square slab, so the grid does not read as a checkerboard.
local function rockBase(model, pos, rng, color)
	local w = 2.8 + rng:NextNumber() * 1.2
	return part(
		model,
		Vector3.new(w, 1.0 + rng:NextNumber() * 0.6, w * (0.8 + rng:NextNumber() * 0.3)),
		CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0),
		color:Lerp(Color3.new(1, 1, 1), rng:NextNumber() * 0.12),
		Enum.Material.Slate,
		Enum.PartType.Ball
	)
end

-- Rotate and scale a finished model about `pivot` (cosmetic variety only; game logic never uses model positions).
local function transformModel(model, pivot, yaw, scale)
	local origin = CFrame.new(pivot)
	local rot = origin * CFrame.Angles(0, yaw, 0)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local rel = origin:ToObjectSpace(p.CFrame)
			-- CFrame.new(-position) * rel leaves only the rotation (the translations cancel).
			p.CFrame = rot * CFrame.new(rel.Position * scale) * (CFrame.new(-rel.Position) * rel)
			p.Size = p.Size * scale
		end
	end
end

-- One silhouette per behavior so crystal types read at a glance.
local builders = {}

function builders.Inert(model, pos, col, rng)
	rockBase(model, pos, rng, ROCK)
	for i, h in { 3.0, 2.1, 1.6 } do
		local a = (i / 3) * math.pi * 2 + rng:NextNumber() * 0.6
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (i == 1 and 0 or 0.9)
		part(model, Vector3.new(0.8, h, 0.8), CFrame.new(pos + off + Vector3.new(0, 0.6 + h / 2, 0)) * CFrame.Angles(math.rad((rng:NextNumber() - 0.5) * 30), a, math.rad((rng:NextNumber() - 0.5) * 30)), col, SHARD)
	end
end

function builders.Volatile(model, pos, col, rng)
	rockBase(model, pos, rng, ROCK)
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * 0.8
		part(model, Vector3.new(1.1, 1.7, 1.1), CFrame.new(pos + off + Vector3.new(0, 1.5, 0)) * CFrame.Angles(math.rad(20) * math.cos(a), a, math.rad(20) * math.sin(a)), col, SHARD)
	end
	part(model, Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0.6, 0.6, 0), glow(Color3.fromRGB(255, 230, 160)), Enum.Material.Neon)
end

function builders.Amplifier(model, pos, col, rng)
	rockBase(model, pos, rng, ROCK)
	part(model, Vector3.new(1, 4.4, 1), CFrame.new(pos + Vector3.new(0, 2.9, 0)), col, SHARD)
	part(model, Vector3.new(0.25, 3, 3), CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), glow(col:Lerp(Color3.new(1, 1, 1), 0.4)), Enum.Material.Neon, Enum.PartType.Cylinder)
end

function builders.Prism(model, pos, col, rng)
	rockBase(model, pos, rng, ROCK)
	local disc = part(model, Vector3.new(0.5, 3.4, 3.4), CFrame.new(pos + Vector3.new(0, 2.4, 0)), col, Enum.Material.Glass, Enum.PartType.Cylinder)
	disc.Transparency = 0.15
	part(model, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0.7, 0.7, 0), glow(Color3.new(1, 1, 1)), Enum.Material.Neon)
end

-- Slowburn: dark egg-shaped body with a glowing fuse ring, so it reads as "a bomb waiting to go".
function builders.Delayed(model, pos, col, rng)
	rockBase(model, pos, rng, ROCK)
	part(model, Vector3.new(2.6, 2.6, 2.6), CFrame.new(pos + Vector3.new(0, 1.9, 0)), Color3.fromRGB(34, 22, 38), Enum.Material.Slate, Enum.PartType.Ball)
	part(model, Vector3.new(0.3, 3.0, 3.0), CFrame.new(pos + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), glow(col), Enum.Material.Neon, Enum.PartType.Cylinder)
	part(model, Vector3.new(0.35, 1.0, 0.35), CFrame.new(pos + Vector3.new(0, 3.6, 0)), glow(col), Enum.Material.Neon)
end

-- Echostone: a slim obelisk with a floating ring and a bright tip, so relays read as a matching set across the grid.
function builders.Relay(model, pos, col, rng)
	rockBase(model, pos, rng, ROCK)
	part(model, Vector3.new(1.1, 4.2, 1.1), CFrame.new(pos + Vector3.new(0, 2.7, 0)), col, SHARD)
	part(model, Vector3.new(0.25, 3.2, 3.2), CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), glow(col), Enum.Material.Neon, Enum.PartType.Cylinder)
	part(model, Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 5.1, 0)) * CFrame.Angles(0.7, 0.7, 0), glow(Color3.new(1, 1, 1)), Enum.Material.Neon)
end

function builders.Unstable(model, pos, col, rng)
	rockBase(model, pos, rng, Color3.fromRGB(20, 16, 22))
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (i == 5 and 0 or 0.9)
		local h = 1.6 + rng:NextNumber() * 1.6
		part(model, Vector3.new(0.6, h, 0.6), CFrame.new(pos + off + Vector3.new(0, 0.6 + h / 2, 0)) * CFrame.Angles(math.rad((rng:NextNumber() - 0.5) * 50), a, math.rad((rng:NextNumber() - 0.5) * 50)), Color3.fromRGB(28, 20, 30), Enum.Material.Slate)
		part(model, Vector3.new(0.35, 0.5, 0.35), CFrame.new(pos + off + Vector3.new(0, 0.6 + h, 0)), glow(col), Enum.Material.Neon)
	end
end

local function buildCrystal(parent, kind, mutated, pos, key)
	local def = Crystals.Defs[kind]
	local model = Instance.new("Model")
	model.Name = "C" .. key
	local rng = Random.new(key * 977)
	-- Small random offset, turn and size so neighbours never line up like a grid (cosmetic only).
	local center = pos + Vector3.new((rng:NextNumber() - 0.5) * 1.5, 0, (rng:NextNumber() - 0.5) * 1.5)
	local build = builders[def.Behavior] or builders.Inert
	build(model, center, color(def), rng)
	if mutated then
		part(model, Vector3.new(0.9, 0.9, 0.9), CFrame.new(center + Vector3.new(0, 4.8, 0)), glow(Color3.fromRGB(255, 150, 230)), Enum.Material.Neon, Enum.PartType.Ball)
	end
	transformModel(model, center, rng:NextNumber() * math.pi * 2, 0.9 + rng:NextNumber() * 0.22)
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

local function buildVisuals(view)
	if view.Built then
		return
	end
	view.Built = true
	for key, cell in view.Grid.Cells do
		local x = (key - 1) % view.Size + 1
		local z = (key - 1) // view.Size + 1
		view.Models[key] = buildCrystal(view.Folder, cell.Kind, cell.Mutated, Geometry.CellPosition(view.Origin, x, z), key)
	end
end

local function dropVisuals(view)
	if not view.Built then
		return
	end
	view.Built = false
	for _, model in view.Models do
		model:Destroy()
	end
	table.clear(view.Models)
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
	view.Built = false
	for _, cell in payload.Cells do
		view.Grid.Cells[cell.K] = { Kind = cell.Kind, Mutated = cell.M }
	end
	views[payload.UserId] = view
	if payload.UserId == Players.LocalPlayer.UserId then
		buildVisuals(view) -- your own grid is always built; other players' grids build only when you are near them
	end
	return view
end

-- Level of detail: building ~400 parts per grid for every player, including grids hundreds of studs away, would waste
-- client memory and frame time. Far grids keep their data (so they are correct the moment you get close) but no models.
local LOD_BUILD, LOD_DROP = 190, 240 -- studs; the gap stops grids flickering at the boundary

local function updateLod()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local ref = camera.CFrame.Position
	local builtOne = false
	for userId, view in views do
		if userId == Players.LocalPlayer.UserId then
			buildVisuals(view)
		else
			local dist = math.sqrt((view.Origin.X - ref.X) ^ 2 + (view.Origin.Z - ref.Z) ^ 2)
			if dist > LOD_DROP then
				dropVisuals(view)
			elseif dist < LOD_BUILD and not view.Built and not builtOne then
				buildVisuals(view) -- at most one grid per pass, so walking into a biome does not hitch
				builtOne = true
			end
		end
	end
end

local lodClock = 0
RunService.Heartbeat:Connect(function(dt)
	lodClock += dt
	if lodClock >= 1 then
		lodClock = 0
		updateLod()
	end
end)

-- Creatures: each Lurker kind and the boss has its own procedural model (Creatures.luau). They idle (bob and sway), rise out
-- of the rock when they appear, and flash when hit. One shared loop animates every creature that exists.
local GROUND = { Gnasher = 2.2, Skitter = 1.1, Leech = 1.5, Sapper = 2.2, Brute = 2.6, Titan = 4, Warden = 8 }
local creatureLoop = nil

local function ensureCreatureLoop()
	if creatureLoop then
		return
	end
	creatureLoop = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, view in views do
			for _, entry in view.ThreatLabels or {} do
				if entry.Label.Parent then
					entry.Label.Text = ("%s  %.1f"):format(entry.Name, math.max(0, entry.LandsAt - t))
				end
			end
			local m = view.MonsterModel
			if m and m.Parent and view.MonsterBase then
				local rise = math.clamp((t - view.MonsterBorn) / 0.5, 0, 1)
				local bob = math.sin(t * 3 + view.UserId) * 0.25
				m:PivotTo(view.MonsterBase * CFrame.new(0, bob - (1 - rise) * 4, 0) * CFrame.Angles(0, math.sin(t * 1.5) * 0.2, 0))
			end
			local boss = view.BossModel
			if boss and boss.Parent and view.BossBase then
				local kick = view.BossKick and math.max(0, 1 - (t - view.BossKick) / 0.4) or 0 -- recoil when hit
				boss:PivotTo(view.BossBase * CFrame.new(0, math.sin(t * 1.4) * 0.35, kick * 1.6) * CFrame.Angles(kick * 0.05, math.sin(t * 0.7) * 0.06, 0))
			end
		end
	end)
end

-- A Lurker on the grid, with a name and health bar. monster = nil removes it.
function CavernView.SetMonster(view, monster)
	if not monster then
		if view.MonsterModel then
			view.MonsterModel:Destroy()
			view.MonsterModel = nil
			view.MonsterKind = nil
		end
		return
	end
	if view.MonsterModel and view.MonsterKind ~= monster.Kind then
		view.MonsterModel:Destroy()
		view.MonsterModel = nil
	end
	if not view.MonsterModel then
		local model = Creatures.Build(monster.Kind)
		model.Parent = view.Folder
		local body = model.PrimaryPart
		local gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		gui.Size = UDim2.fromOffset(150, 46)
		gui.StudsOffset = Vector3.new(0, 4.2, 0)
		gui.AlwaysOnTop = true
		gui.Parent = body
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0, 22)
		name.Font = Enum.Font.BuilderSansBold
		name.TextSize = 16
		name.TextColor3 = Color3.fromRGB(255, 120, 120)
		name.TextStrokeTransparency = 0.4
		name.Parent = gui
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Position = UDim2.fromOffset(15, 26)
		back.Size = UDim2.fromOffset(120, 10)
		back.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		back.BorderSizePixel = 0
		back.Parent = gui
		local backCorner = Instance.new("UICorner")
		backCorner.CornerRadius = UDim.new(0, 5)
		backCorner.Parent = back
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
		fill.BorderSizePixel = 0
		fill.Parent = back
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0, 5)
		fillCorner.Parent = fill
		view.MonsterModel = model
		view.MonsterKind = monster.Kind
		view.MonsterBorn = os.clock()
		view.MonsterHP = monster.HP
		ensureCreatureLoop()
	end
	local model = view.MonsterModel
	local offset = GROUND[monster.Kind] or 2.4
	view.MonsterBase = CFrame.new(Geometry.CellPosition(view.Origin, monster.X, monster.Z) + Vector3.new(0, offset, 0))
	if view.MonsterHP and monster.HP < view.MonsterHP then
		Creatures.Flash(model, Color3.fromRGB(255, 80, 80)) -- a hit
	end
	view.MonsterHP = monster.HP
	local gui = model.PrimaryPart:FindFirstChild("Tag")
	gui:FindFirstChild("Name").Text = monster.Warn and (monster.Kind .. "  !! SMASH NEXT !!") or monster.Kind -- (gui.Name is the instance's own name, hence FindFirstChild)
	gui.Back.Fill.Size = UDim2.fromScale(math.clamp(monster.HP / monster.MaxHP, 0, 1), 1)
end

-- A floating diamond above a cell: unlike a flat tile it is never hidden by the rock and crystal on the cell, so armor nodes
-- and weak points can always be seen from the tilted camera.
local function gemMarker(view, cell, color, height)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.05
	p.Size = Vector3.new(1.9, 1.9, 1.9)
	p.CFrame = CFrame.new(Geometry.CellPosition(view.Origin, cell.X, cell.Z) + Vector3.new(0, height, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0)
	p.Parent = view.BossFx
	return p
end

-- The boss on the grid: the Titan model over the middle 3x3, plus marker parts: gold armor nodes, magenta weak points and
-- red flat tiles on the cells its next attack will hit. The model persists between updates; only the markers are rebuilt.
local function marker(view, cell, color, height, size, transparency)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(size, height, size)
	p.Position = Geometry.CellPosition(view.Origin, cell.X, cell.Z) + Vector3.new(0, height / 2 + 0.3, 0)
	p.Parent = view.BossFx
	return p
end

function CavernView.SetBoss(view, boss)
	if view.BossFx then
		view.BossFx:Destroy()
		view.BossFx = nil
	end
	if not boss then
		if view.BossModel then
			view.BossModel:Destroy()
			view.BossModel = nil
			view.BossBase = nil
		end
		return
	end
	local fx = Instance.new("Folder")
	fx.Name = "BossFx"
	fx.Parent = view.Folder
	view.BossFx = fx
	if not view.BossModel then
		local model = Creatures.Build(boss.Kind)
		model.Parent = view.Folder
		local body = model.PrimaryPart
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(240, 30)
		gui.StudsOffset = Vector3.new(0, boss.Kind == "Warden" and 15 or 14, 0)
		gui.AlwaysOnTop = true
		gui.Parent = body
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.TextSize = 18
		text.TextColor3 = Color3.fromRGB(255, 200, 90)
		text.TextStrokeTransparency = 0.3
		text.Parent = gui
		view.BossModel = model
		view.BossBase = CFrame.new(Geometry.CellPosition(view.Origin, boss.Core.X, boss.Core.Z) + Vector3.new(0, GROUND[boss.Kind] or 4, 0))
		view.MonsterBorn = view.MonsterBorn or os.clock()
		view.BossHP = boss.HP
		ensureCreatureLoop()
	end
	local model = view.BossModel
	if view.BossHP and boss.HP < view.BossHP then
		Creatures.Flash(model, Color3.fromRGB(255, 255, 255))
	end
	view.BossHP = boss.HP
	Creatures.SetPhase(model, boss.Phase)
	-- the arena: a coloured border around the grid and a sigil under the boss, both in the phase colour
	local phaseColor = ({ Armor = Color3.fromRGB(240, 190, 60), Attack = Color3.fromRGB(232, 92, 84), Weak = Color3.fromRGB(226, 90, 200), Enrage = Color3.fromRGB(236, 56, 56), Finisher = Color3.fromRGB(96, 214, 230) })[boss.Phase] or Color3.fromRGB(232, 92, 84)
	local mid = (view.Size + 1) / 2
	local centre = Geometry.CellPosition(view.Origin, mid, mid)
	local half = view.Extent / 2 + 1
	for _, side in { { 0, -half, view.Extent + 3, 1.4 }, { 0, half, view.Extent + 3, 1.4 }, { -half, 0, 1.4, view.Extent + 3 }, { half, 0, 1.4, view.Extent + 3 } } do
		local strip = Instance.new("Part")
		strip.Anchored, strip.CanCollide, strip.CanQuery, strip.CastShadow = true, false, false, false
		strip.Material = Enum.Material.Neon
		strip.Color = phaseColor
		strip.Transparency = 0.45
		strip.Size = Vector3.new(side[3], 0.3, side[4])
		strip.Position = centre + Vector3.new(side[1], 0.25, side[2])
		strip.Parent = view.BossFx
	end
	local sigil = Instance.new("Part")
	sigil.Anchored, sigil.CanCollide, sigil.CanQuery, sigil.CastShadow = true, false, false, false
	sigil.Shape = Enum.PartType.Cylinder
	sigil.Material = Enum.Material.Neon
	sigil.Color = phaseColor
	sigil.Transparency = 0.7
	sigil.Size = Vector3.new(0.2, CellSize * 3.6, CellSize * 3.6)
	sigil.CFrame = CFrame.new(centre + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, 0, math.rad(90))
	sigil.Parent = view.BossFx
	model.PrimaryPart:FindFirstChildOfClass("BillboardGui").Text.Text = ("%s  %d/%d"):format(boss.Name, boss.HP, boss.MaxHP)
	for _, cell in boss.Nodes do
		-- armor node: break these (a flat tile plus a thin marker beam, never a wide pillar that hides the crystals behind it)
		marker(view, cell, Color3.fromRGB(255, 200, 60), 0.3, CellSize * 0.9, 0.35)
		marker(view, cell, Color3.fromRGB(255, 200, 60), 5, 0.5, 0.45)
		gemMarker(view, cell, Color3.fromRGB(255, 200, 60), 5.6)
	end
	for _, cell in boss.Weak do
		marker(view, cell, Color3.fromRGB(255, 70, 230), 0.3, CellSize * 0.9, 0.3) -- weak point: chain through BOTH
		marker(view, cell, Color3.fromRGB(255, 70, 230), 6, 0.5, 0.4)
		gemMarker(view, cell, Color3.fromRGB(255, 70, 230), 6.6)
	end
	-- real-time threats: every wound-up attack is drawn on the grid with a live countdown
	view.ThreatLabels = {}
	local function pulse(part, speed)
		pcall(function()
			TweenService:Create(part, TweenInfo.new(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.4 }):Play()
		end)
	end
	local function countdown(centre, text, color, landsAt)
		local anchor = Instance.new("Part")
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency, anchor.Size = true, false, false, 1, Vector3.new(1, 1, 1)
		anchor.Position = centre + Vector3.new(0, 9, 0)
		anchor.Parent = view.BossFx
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(200, 28)
		gui.AlwaysOnTop = true
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.BuilderSansBold
		label.TextSize = 18
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.5
		label.Parent = gui
		table.insert(view.ThreatLabels, { Label = label, Name = text, LandsAt = landsAt })
	end
	local receivedAt = os.clock()
	for _, threat in ((boss.RT and boss.RT.Threats) or {}) do
		local landsAt = receivedAt + threat.LandsIn
		local speed = math.clamp(threat.LandsIn / 4, 0.25, 0.7) -- it blinks faster as it gets closer
		if threat.Type == "Slam" then
			for _, cell in threat.Cells do
				pulse(marker(view, cell, threat.Cancelled and Color3.fromRGB(80, 255, 150) or Color3.fromRGB(255, 40, 40), 0.3, CellSize * 0.95, 0.55), speed)
			end
			local mid = threat.Cells[math.ceil(#threat.Cells / 2)]
			countdown(Geometry.CellPosition(view.Origin, mid.X, mid.Z), threat.Cancelled and "SLAM CUT" or "SLAM", threat.Cancelled and Color3.fromRGB(120, 255, 170) or Color3.fromRGB(255, 120, 120), landsAt)
		elseif threat.Type == "Meteor" then
			for _, zone in threat.Zones do
				local color = zone.Cancelled and Color3.fromRGB(90, 220, 255) or Color3.fromRGB(255, 130, 40)
				local disc = marker(view, { X = zone.X, Z = zone.Z }, color, 0.3, CellSize * 2.9, 0.5)
				pulse(disc, speed)
				countdown(Geometry.CellPosition(view.Origin, zone.X, zone.Z), zone.Cancelled and "DEFLECTED" or "METEOR", color, landsAt)
			end
		elseif threat.Type == "Corruption" then
			for _, cell in threat.Marks do
				pulse(marker(view, cell, Color3.fromRGB(190, 70, 255), 0.3, CellSize * 0.9, 0.4), speed)
				marker(view, cell, Color3.fromRGB(190, 70, 255), 7, 0.5, 0.5)
				gemMarker(view, cell, Color3.fromRGB(190, 70, 255), 7.6)
			end
			if threat.Marks[1] then
				countdown(Geometry.CellPosition(view.Origin, threat.Marks[1].X, threat.Marks[1].Z), "CORRUPTION", Color3.fromRGB(215, 130, 255), landsAt)
			end
		end
	end
end

-- A crystal corrupted into a Dreadgeode by the boss: the old model pops, a hazard crystal takes its place.
function CavernView.Corrupt(view, x, z)
	local key = (z - 1) * view.Size + x
	CavernView.Pop(view, key)
	view.Grid.Cells[key] = { Kind = "Dreadgeode" }
	if view.Built then
		view.Models[key] = buildCrystal(view.Folder, "Dreadgeode", false, Geometry.CellPosition(view.Origin, x, z), key)
	end
end

-- Where a creature stands (for floating numbers and bursts), or nil.
function CavernView.MonsterPosition(view)
	return view.MonsterBase and view.MonsterBase.Position or nil
end

function CavernView.BossHit(view)
	view.BossKick = os.clock()
end

function CavernView.BossPosition(view)
	return view.BossBase and view.BossBase.Position or nil
end

-- An eaten crystal disappears without a chain.
function CavernView.Eat(view, x, z)
	local key = (z - 1) * view.Size + x
	view.Grid.Cells[key] = nil
	CavernView.Pop(view, key)
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
