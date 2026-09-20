--!nonstrict
-- Builds the explorable mine from code (Rojo stays the source of truth): terrain, lighting, hub, biomes,
-- blast pads with stations, geode caches. Layout data lives in Shared/Config/World.luau (tested).
-- Everything here is deterministic (fixed seed) so every server builds the identical world.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Props = require(script.Parent.Props)

local W = Config.World
local Terrain = workspace.Terrain

local World = {
	-- Filled by Build(): live instances the Game module needs.
	Registry = { Sites = {}, Caches = {} },
}

local root

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function mk(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.CanQuery = true
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function decorPart(parent, size, cf, color, material, shape)
	local p = mk(parent, size, cf, color, material, shape)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function dist2(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Keep terrain features and decor off pads, roads, hub, landmarks and caches.
local function blocked(x, z, margin)
	margin = margin or 0
	if dist2(x, z, W.Hub.X, W.Hub.Z) < W.Hub.Radius + 20 + margin then
		return true
	end
	for _, s in W.Sites do
		if dist2(x, z, s.X, s.Z) < W.SiteClearRadius + margin then
			return true
		end
	end
	for _, b in W.Biomes do
		if dist2(x, z, b.X, b.Z) < 32 + margin then
			return true
		end
	end
	for _, c in W.Caches do
		if dist2(x, z, c.X, c.Z) < 14 + margin then
			return true
		end
	end
	return W.DistToPath(x, z) < W.PathHalfWidth + 12 + margin
end

local function areaColor(x, z)
	local best, bestD = nil, 190
	for _, b in W.Biomes do
		local d = dist2(x, z, b.X, b.Z)
		if d < bestD then
			best, bestD = b, d
		end
	end
	return best and c3(best.Color) or Color3.fromRGB(120, 170, 255)
end

---------------------------------------------------------------- lighting

local function buildLighting()
	-- Tuned from playtest feedback: the first pass was too dark. Ambient carries the scene; crystals only accent it.
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(96, 108, 146)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 108, 146)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.ExposureCompensation = 0.6
	Lighting.GlobalShadows = false

	local function ensure(class, name)
		local inst = Lighting:FindFirstChild(name)
		if not inst or inst.ClassName ~= class then
			inst = Instance.new(class)
			inst.Name = name
			inst.Parent = Lighting
		end
		return inst
	end
	local bloom = ensure("BloomEffect", "CaveBloom")
	bloom.Intensity = 0.2
	bloom.Size = 20
	bloom.Threshold = 2.2
	local cc = ensure("ColorCorrectionEffect", "CaveGrade")
	cc.Brightness = 0.04
	cc.Saturation = 0.1
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(238, 242, 255)
	local atmo = ensure("Atmosphere", "CaveAtmosphere")
	atmo.Density = 0.22
	atmo.Offset = 0
	atmo.Color = Color3.fromRGB(80, 92, 140)
	atmo.Decay = Color3.fromRGB(50, 58, 96)
	atmo.Glare = 0
	atmo.Haze = 0.8
end

---------------------------------------------------------------- terrain

local function buildTerrain()
	Terrain:Clear()
	Terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(62, 70, 94))
	Terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(44, 48, 66))
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(82, 90, 118))

	local rng = Random.new(20260921)
	local b = W.Bounds
	local pad = 20
	local x0, x1, z0, z1 = b.MinX - pad, b.MaxX + pad, b.MinZ - pad, b.MaxZ + pad

	Terrain:FillBlock(CFrame.new((x0 + x1) / 2, -6, (z0 + z1) / 2), Vector3.new(x1 - x0, 12, z1 - z0), Enum.Material.Slate)

	-- Perimeter cliffs: slabs plus ragged boulders so the boundary reads as cave wall, not a fence.
	local wallH = 90
	Terrain:FillBlock(CFrame.new((x0 + x1) / 2, wallH / 2 - 6, z0 - 25), Vector3.new(x1 - x0 + 100, wallH, 50), Enum.Material.Basalt)
	Terrain:FillBlock(CFrame.new((x0 + x1) / 2, wallH / 2 - 6, z1 + 25), Vector3.new(x1 - x0 + 100, wallH, 50), Enum.Material.Basalt)
	Terrain:FillBlock(CFrame.new(x0 - 25, wallH / 2 - 6, (z0 + z1) / 2), Vector3.new(50, wallH, z1 - z0 + 100), Enum.Material.Basalt)
	Terrain:FillBlock(CFrame.new(x1 + 25, wallH / 2 - 6, (z0 + z1) / 2), Vector3.new(50, wallH, z1 - z0 + 100), Enum.Material.Basalt)

	local n = 0
	local function boulder(x, y, z, r)
		Terrain:FillBall(Vector3.new(x, y, z), r, Enum.Material.Basalt)
		n += 1
		if n % 15 == 0 then
			task.wait()
		end
	end
	for x = x0, x1, 28 do
		boulder(x + rng:NextNumber(-8, 8), rng:NextNumber(4, 38), z0 + rng:NextNumber(0, 12), rng:NextNumber(14, 30))
		boulder(x + rng:NextNumber(-8, 8), rng:NextNumber(4, 38), z1 - rng:NextNumber(0, 12), rng:NextNumber(14, 30))
	end
	for z = z0, z1, 28 do
		boulder(x0 + rng:NextNumber(0, 12), rng:NextNumber(4, 38), z + rng:NextNumber(-8, 8), rng:NextNumber(14, 30))
		boulder(x1 - rng:NextNumber(0, 12), rng:NextNumber(4, 38), z + rng:NextNumber(-8, 8), rng:NextNumber(14, 30))
	end

	-- Interior rocks: mounds and stacked-cylinder spires, kept off pads, roads, hub and caches.
	local spires = {}
	for _ = 1, 420 do
		local x = rng:NextNumber(b.MinX + 10, b.MaxX - 10)
		local z = rng:NextNumber(b.MinZ + 10, b.MaxZ - 10)
		if not blocked(x, z, 0) then
			if rng:NextNumber() < 0.5 then
				local r = rng:NextNumber(7, 20)
				Terrain:FillBall(Vector3.new(x, r * 0.1, z), r, Enum.Material.Rock)
			else
				local r = rng:NextNumber(3.5, 8)
				local h = rng:NextNumber(16, 46)
				local y = 0
				for _, seg in { { 0.5, 1 }, { 0.3, 0.62 }, { 0.2, 0.3 } } do
					local hh, rr = h * seg[1], r * seg[2]
					Terrain:FillCylinder(CFrame.new(x, y + hh / 2, z), hh, rr, Enum.Material.Basalt)
					y += hh
				end
				table.insert(spires, { x = x, z = z, r = r })
			end
			n += 1
			if n % 12 == 0 then
				task.wait()
			end
		end
	end
	-- Rocky rim around each blast pad, open on the station side (toward -Z), so the pad reads as a cavern chamber.
	for _, site in W.Sites do
		for i = 1, 18 do
			local a = (i / 18) * math.pi * 2 + rng:NextNumber() * 0.15
			if math.abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) > 0.7 then
				local r = rng:NextNumber(2.8, 5.5)
				local d = W.PadRadius + 2 + rng:NextNumber(0, 3)
				Terrain:FillBall(Vector3.new(site.X + math.cos(a) * d, r * 0.3, site.Z + math.sin(a) * d), r, Enum.Material.Rock)
				n += 1
				if n % 12 == 0 then
					task.wait()
				end
			end
		end
	end
	return spires, rng
end

---------------------------------------------------------------- crystal decor

local function cluster(parent, pos, color, scale, rng, withLight)
	local model = Instance.new("Model")
	model.Name = "Crystals"
	local first
	local real = nil
	if Props.Has("CrystalA") and rng:NextNumber() < 0.7 then
		local key = (Props.Has("CrystalB") and rng:NextNumber() < 0.5) and "CrystalB" or "CrystalA"
		real = Props.Place(key, pos, (3 + rng:NextNumber() * 4) * scale, rng:NextNumber() * math.pi * 2, color:Lerp(Color3.new(0, 0, 0), 0.3), model)
		if real then
			first = real:FindFirstChildWhichIsA("BasePart", true)
		end
	end
	local count = real and 0 or rng:NextInteger(3, 5)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber() * 0.5
		local h = (2 + rng:NextNumber() * 3.5) * scale
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (i == 1 and 0 or 0.8 * scale)
		local tilt = math.rad(rng:NextNumber(8, 26))
		-- Slightly darkened so Neon glows as an accent instead of blowing out.
		local col = color:Lerp(Color3.new(0, 0, 0), 0.3):Lerp(Color3.new(1, 1, 1), rng:NextNumber() * 0.1)
		local p = decorPart(model, Vector3.new(0.9 * scale, h, 0.9 * scale), CFrame.new(pos + off + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.sin(a) * tilt, a, -math.cos(a) * tilt), col, Enum.Material.Neon)
		first = first or p
	end
	if withLight and first then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 8 + 6 * scale
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = first
	end
	model.Parent = parent
	return model
end

local function buildDecor(spires, rng)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = root

	local placed = 0
	local function place(x, z, scale)
		if blocked(x, z, -8) then
			return
		end
		placed += 1
		cluster(decor, Vector3.new(x, 0, z), areaColor(x, z), scale, rng, placed % 6 == 0)
	end

	for _, s in spires do
		local a = rng:NextNumber(0, math.pi * 2)
		place(s.x + math.cos(a) * (s.r + 3), s.z + math.sin(a) * (s.r + 3), rng:NextNumber(0.9, 1.7))
	end
	local b = W.Bounds
	for x = b.MinX, b.MaxX, 26 do
		place(x + rng:NextNumber(-6, 6), b.MinZ + rng:NextNumber(4, 14), rng:NextNumber(1.4, 2.6))
		place(x + rng:NextNumber(-6, 6), b.MaxZ - rng:NextNumber(4, 14), rng:NextNumber(1.4, 2.6))
	end
	for z = b.MinZ, b.MaxZ, 26 do
		place(b.MinX + rng:NextNumber(4, 14), z + rng:NextNumber(-6, 6), rng:NextNumber(1.4, 2.6))
		place(b.MaxX - rng:NextNumber(4, 14), z + rng:NextNumber(-6, 6), rng:NextNumber(1.4, 2.6))
	end
end

---------------------------------------------------------------- flora and rock decor (real models)

local function buildFlora()
	local folder = Instance.new("Folder")
	folder.Name = "Flora"
	folder.Parent = root
	local rng = Random.new(4242)

	local function scatter(keys, attempts, minH, maxH, lightEvery)
		local placed = 0
		for _ = 1, attempts do
			local x = rng:NextNumber(W.Bounds.MinX + 12, W.Bounds.MaxX - 12)
			local z = rng:NextNumber(W.Bounds.MinZ + 12, W.Bounds.MaxZ - 12)
			if not blocked(x, z, -6) then
				local key = keys[rng:NextInteger(1, #keys)]
				if Props.Has(key) then
					local model = Props.Place(key, Vector3.new(x, 0, z), rng:NextNumber(minH, maxH), rng:NextNumber(0, math.pi * 2), nil, folder)
					if model then
						placed += 1
						if lightEvery and placed % lightEvery == 0 then
							local part = model:FindFirstChildWhichIsA("BasePart", true)
							if part then
								local light = Instance.new("PointLight")
								light.Color = Color3.fromRGB(90, 220, 230)
								light.Range = 12
								light.Brightness = 0.6
								light.Shadows = false
								light.Parent = part
							end
						end
					end
				end
			end
		end
	end

	scatter({ "MushroomA", "MushroomB" }, 90, 2.5, 5.5, 4)
	scatter({ "StalagmiteA", "StalagmiteB" }, 60, 7, 15, nil)
end

---------------------------------------------------------------- roads and lanterns

local function buildRoads()
	local folder = Instance.new("Folder")
	folder.Name = "Roads"
	folder.Parent = root
	local lamp = Color3.fromRGB(255, 200, 120)
	for _, p in W.Paths do
		local a, b = Vector3.new(p.AX, 0, p.AZ), Vector3.new(p.BX, 0, p.BZ)
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local road = decorPart(folder, Vector3.new(W.PathHalfWidth * 2 - 4, 0.5, len), CFrame.lookAt(mid + Vector3.new(0, 0.1, 0), b + Vector3.new(0, 0.1, 0)), Color3.fromRGB(84, 92, 120), Enum.Material.Cobblestone)
		road.CanCollide = true
		local dir = (b - a).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local step = 34
		local count = math.floor(len / step)
		for i = 1, count do
			local pos = a + dir * (i * step)
			if dist2(pos.X, pos.Z, W.Hub.X, W.Hub.Z) > W.Hub.Radius + 4 then
				for sgn = -1, 1, 2 do
					local base = pos + side * (W.PathHalfWidth - 1) * sgn
					local head
					if Props.Place("Lamp", base, 9.5, math.atan2(dir.X, dir.Z) + (sgn > 0 and math.pi or 0), nil, folder) then
						-- Invisible emitter part carries the light; the model supplies the look.
						head = decorPart(folder, Vector3.new(0.6, 0.6, 0.6), CFrame.new(base + Vector3.new(0, 7.6, 0)), lamp, Enum.Material.Neon)
						head.Transparency = 1
					else
						decorPart(folder, Vector3.new(0.6, 7, 0.6), CFrame.new(base + Vector3.new(0, 3.5, 0)), Color3.fromRGB(30, 32, 44), Enum.Material.Metal)
						head = decorPart(folder, Vector3.new(1.5, 1.5, 1.5), CFrame.new(base + Vector3.new(0, 7.4, 0)), lamp, Enum.Material.Neon)
					end
					if (i + (sgn + 1) / 2) % 2 == 0 then
						local light = Instance.new("PointLight")
						light.Color = lamp
						light.Range = 26
						light.Brightness = 1.2
						light.Shadows = false
						light.Parent = head
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- hub and landmarks

local function beacon(parent, x, z, color, scale, name)
	local rng = Random.new(x * 31 + z)
	local group = Instance.new("Model")
	group.Name = name
	group.Parent = parent
	local plat = decorPart(group, Vector3.new(0.6, 44, 44), CFrame.new(x, 0.15, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(46, 52, 72), Enum.Material.Slate, Enum.PartType.Cylinder)
	plat.CanCollide = true
	decorPart(group, Vector3.new(0.2, 47, 47), CFrame.new(x, 0.05, z) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, Enum.PartType.Cylinder)
	for i = 1, 7 do
		local a = (i / 7) * math.pi * 2
		cluster(group, Vector3.new(x + math.cos(a) * 7, 0.4, z + math.sin(a) * 7), color, scale * 0.7, rng, false)
	end
	local core = cluster(group, Vector3.new(x, 0.4, z), color, scale, rng, true)
	local light = core:FindFirstChildWhichIsA("PointLight", true)
	if light then
		light.Range = 60
		light.Brightness = 1.1
	end
end

local function buildHub()
	local folder = Instance.new("Folder")
	folder.Name = "Hub"
	folder.Parent = root

	local r = W.Hub.Radius
	local plaza = decorPart(folder, Vector3.new(0.6, r * 2, r * 2), CFrame.new(W.Hub.X, 0.15, W.Hub.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(80, 88, 116), Enum.Material.Cobblestone, Enum.PartType.Cylinder)
	plaza.CanCollide = true
	decorPart(folder, Vector3.new(0.2, r * 2 + 3, r * 2 + 3), CFrame.new(W.Hub.X, 0.05, W.Hub.Z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(110, 150, 220), Enum.Material.Neon, Enum.PartType.Cylinder)
	beacon(folder, W.Hub.X, W.Hub.Z - 4, Color3.fromRGB(150, 190, 255), 4.5, "DepotBeacon")

	for _, biome in W.Biomes do
		local dx, dz = biome.X - W.Hub.X, biome.Z - W.Hub.Z
		local len = math.sqrt(dx * dx + dz * dz)
		local dir = Vector3.new(dx / len, 0, dz / len)
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local pos = Vector3.new(W.Hub.X, 0, W.Hub.Z) + dir * (r - 9) + side * 11
		local face = Vector3.new(W.Hub.X, 0, W.Hub.Z) + dir * 6
		decorPart(folder, Vector3.new(0.7, 6, 0.7), CFrame.new(pos + Vector3.new(0, 3, 0)), Color3.fromRGB(30, 32, 44), Enum.Material.Metal)
		local sign = decorPart(folder, Vector3.new(13, 3.4, 0.5), CFrame.lookAt(pos + Vector3.new(0, 6.6, 0), Vector3.new(face.X, 6.6, face.Z)), Color3.fromRGB(24, 28, 42), Enum.Material.Metal)
		local compass = math.abs(dx) > math.abs(dz) and (dx < 0 and "West" or "East") or (dz < 0 and "North" or "South")
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextColor3 = c3(biome.Color)
		label.Text = ("%s\n%s"):format(biome.Name:upper(), compass:upper())
		label.Parent = gui
	end

	if Props.Has("Crate") then
		for _, off in { { -24, 28 }, { -28, 31 }, { 24, 27 } } do
			Props.Place("Crate", Vector3.new(W.Hub.X + off[1], 0, W.Hub.Z + off[2]), 3.4, off[1] * 0.1, nil, folder)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(W.Spawn.X, 0.6, W.Spawn.Z)
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = folder
end

---------------------------------------------------------------- blast sites

local function buildSites()
	local folder = Instance.new("Folder")
	folder.Name = "Sites"
	folder.Parent = root
	local radius = W.PadRadius
	local dark = Color3.fromRGB(30, 34, 46)

	for _, biome in W.Biomes do
		beacon(folder, biome.X, biome.Z, c3(biome.Color), 5, biome.Id .. "Beacon")
	end

	for _, site in W.Sites do
		local biome
		for _, b in W.Biomes do
			if b.Id == site.Biome then
				biome = b
			end
		end
		local color = c3(biome.Color)
		local origin = Geometry.Origin(site.Id)

		-- Round cavern floor with a soft glowing edge (a wider, lower disc peeking out under the floor).
		local padPart = mk(folder, Vector3.new(0.9, radius * 2, radius * 2), CFrame.new(origin + Vector3.new(0, -0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(46, 52, 72), Enum.Material.Slate, Enum.PartType.Cylinder)
		padPart.Name = "Pad" .. site.Id
		decorPart(folder, Vector3.new(0.6, (radius + 1.4) * 2, (radius + 1.4) * 2), CFrame.new(origin + Vector3.new(0, -0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), color:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Neon, Enum.PartType.Cylinder)

		-- A few crystal clusters just outside the rim, leaving the station side (toward -Z) open.
		local prng = Random.new(site.Id * 13)
		for i = 1, 6 do
			local a = (i / 6) * math.pi * 2 + prng:NextNumber() * 0.4
			if math.abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) > 0.7 then
				local r = radius + 5 + prng:NextNumber() * 3
				cluster(folder, origin + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), color, 1.2 + prng:NextNumber() * 0.6, prng, false)
			end
		end

		local stationPos = Geometry.Station(site.Id)
		mk(folder, Vector3.new(4.5, 0.6, 4.5), CFrame.new(stationPos + Vector3.new(0, 0.3, 0)), dark, Enum.Material.Metal)
		mk(folder, Vector3.new(3, 1.4, 3), CFrame.new(stationPos + Vector3.new(0, 1.2, 0)), Color3.fromRGB(46, 52, 72), Enum.Material.Metal)
		local plunger = mk(folder, Vector3.new(1.2, 2.2, 1.2), CFrame.new(stationPos + Vector3.new(0, 2.9, 0)), color, Enum.Material.Neon)
		if Props.Has("Crate") then
			Props.Place("Crate", stationPos + Vector3.new(6, 0, 1), 3.6, 0.3, nil, folder)
			Props.Place("Crate", stationPos + Vector3.new(-6.5, 0, 0), 3.2, -0.4, nil, folder)
		end
		plunger.Name = "Station" .. site.Id
		plunger:SetAttribute("SiteId", site.Id)
		CollectionService:AddTag(plunger, "SiteStation")

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Start blasting"
		prompt.ObjectText = site.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = plunger

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(260, 56)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
		gui.MaxDistance = 120
		gui.LightInfluence = 0
		gui.Adornee = plunger
		gui.Parent = plunger
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 17
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.4
		label.Text = site.Name .. "\nFree"
		label.Parent = gui

		World.Registry.Sites[site.Id] = { Station = plunger, Prompt = prompt, Label = label, Name = site.Name }
	end
end

function World.SetSiteStatus(siteId, status)
	local entry = World.Registry.Sites[siteId]
	if entry then
		entry.Label.Text = entry.Name .. "\n" .. status
	end
end

---------------------------------------------------------------- caches

local function buildCaches()
	local folder = Instance.new("Folder")
	folder.Name = "Caches"
	folder.Parent = root
	local rng = Random.new(777)

	for _, cache in W.Caches do
		local color = areaColor(cache.X, cache.Z)
		local model = Instance.new("Model")
		model.Name = "Cache_" .. cache.Id
		local pos = Vector3.new(cache.X, 0, cache.Z)
		local shell = decorPart(model, Vector3.new(4, 3.2, 4), CFrame.new(pos + Vector3.new(0, 1, 0)), Color3.fromRGB(40, 44, 60), Enum.Material.Slate, Enum.PartType.Ball)
		for i = 1, 4 do
			local a = (i / 4) * math.pi * 2
			local h = 2.2 + rng:NextNumber() * 1.6
			decorPart(model, Vector3.new(0.8, h, 0.8), CFrame.new(pos + Vector3.new(math.cos(a) * 0.9, 1.6 + h / 2, math.sin(a) * 0.9)) * CFrame.Angles(math.sin(a) * 0.35, a, -math.cos(a) * 0.35), color, Enum.Material.Neon)
		end
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 14
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = shell

		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Rate = 5
		sparkle.Lifetime = NumberRange.new(1.5, 2.5)
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.Size = NumberSequence.new(0.5, 0)
		sparkle.LightEmission = 1
		sparkle.Color = ColorSequence.new(color)
		sparkle.Parent = shell

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Crack open"
		prompt.ObjectText = "Geode cache"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = shell

		model:SetAttribute("CacheId", cache.Id)
		CollectionService:AddTag(model, "Cache")
		model.Parent = folder
		World.Registry.Caches[cache.Id] = { Model = model, Prompt = prompt }
	end
end

---------------------------------------------------------------- entry point

function World.Build()
	root = workspace:FindFirstChild("World")
	if root then
		root:Destroy()
	end
	root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = workspace

	local old = workspace:FindFirstChild("Ground")
	if old then
		old:Destroy()
	end
	local oldSpawn = workspace:FindFirstChild("Spawn")
	if oldSpawn then
		oldSpawn:Destroy()
	end

	buildLighting()
	local spires, rng = buildTerrain()
	Props.Load() -- third-party decor models (sanitized); procedural fallbacks are used for any that fail
	buildDecor(spires, rng)
	buildFlora()
	buildRoads()
	buildHub()
	buildSites()
	buildCaches()
end

return World
