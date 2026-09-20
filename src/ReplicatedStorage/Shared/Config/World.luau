--!strict
-- World layout: hub, four biomes with four blast sites each, hidden geode caches, and the paths between them.
-- Pure data and math (no Roblox types) so the Luau CLI tests can check the layout.
-- Coordinates are {x, z} studs on flat ground (y = 0). X east, Z south.

local SITE_OFFSET = 55 -- diagonal offset of sites from a biome center; keeps sites clear of the entry path

export type Biome = { Id: string, Name: string, Stratum: number, X: number, Z: number, Color: { number } }
export type Site = { Id: number, Biome: string, BiomeName: string, Stratum: number, X: number, Z: number, Name: string }
export type Cache = { Id: string, Biome: string, X: number, Z: number, Reward: number }

local Hub = { X = 0, Z = 0, Radius = 45 }

local Biomes: { Biome } = {
	{ Id = "Shallows", Name = "Glimmer Shallows", Stratum = 1, X = -190, Z = 0, Color = { 90, 200, 255 } },
	{ Id = "Prism", Name = "Prism Veins", Stratum = 2, X = 190, Z = 0, Color = { 255, 220, 120 } },
	{ Id = "Ember", Name = "Ember Hollows", Stratum = 3, X = 0, Z = -230, Color = { 255, 80, 170 } },
	{ Id = "Echo", Name = "Echo Caverns", Stratum = 4, X = 0, Z = 230, Color = { 120, 255, 190 } },
}

local Sites: { Site } = {}
for _, biome in Biomes do
	local n = 0
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			n += 1
			table.insert(Sites, {
				Id = #Sites + 1,
				Biome = biome.Id,
				BiomeName = biome.Name,
				Stratum = biome.Stratum,
				X = biome.X + dx * SITE_OFFSET,
				Z = biome.Z + dz * SITE_OFFSET,
				Name = ("%s Site %d"):format(biome.Name, n),
			})
		end
	end
end

local function cache(id: string, biome: string, x: number, z: number, reward: number): Cache
	return { Id = id, Biome = biome, X = x, Z = z, Reward = reward }
end

local Caches: { Cache } = {
	cache("H1", "Hub", -70, 80, 100),
	cache("H2", "Hub", 80, 90, 100),
	cache("S1", "Shallows", -300, -80, 60),
	cache("S2", "Shallows", -270, 95, 60),
	cache("S3", "Shallows", -110, -120, 60),
	cache("S4", "Shallows", -100, 100, 60),
	cache("S5", "Shallows", -190, -140, 60),
	cache("P1", "Prism", 300, -90, 150),
	cache("P2", "Prism", 270, 100, 150),
	cache("P3", "Prism", 110, -120, 150),
	cache("P4", "Prism", 100, 110, 150),
	cache("P5", "Prism", 190, -145, 150),
	cache("E1", "Ember", -140, -230, 400),
	cache("E2", "Ember", 140, -250, 400),
	cache("E3", "Ember", -90, -330, 400),
	cache("E4", "Ember", 90, -335, 400),
	cache("E5", "Ember", 0, -345, 400),
	cache("C1", "Echo", -140, 230, 800),
	cache("C2", "Echo", 140, 250, 800),
	cache("C3", "Echo", -90, 330, 800),
	cache("C4", "Echo", 90, 335, 800),
	cache("C5", "Echo", 0, 345, 800),
}

-- Straight paths from the hub to each biome center. Used to keep terrain features and caches off the roads.
local Paths = {}
for _, biome in Biomes do
	table.insert(Paths, { AX = Hub.X, AZ = Hub.Z, BX = biome.X, BZ = biome.Z })
end

local World = {
	Hub = Hub,
	Biomes = Biomes,
	Sites = Sites,
	Caches = Caches,
	Paths = Paths,
	Spawn = { X = 0, Z = 24 },
	Bounds = { MinX = -340, MaxX = 340, MinZ = -350, MaxZ = 350 }, -- playable area; walls sit outside
	PadRadius = 34, -- blast pads are round; the 9x9 grid corners sit ~28 studs from the center
	SiteClearRadius = 44,
	PathHalfWidth = 12,
}

function World.DistToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = len2 > 0 and math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) or 0
	local cx, cz = ax + t * dx, az + t * dz
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

function World.DistToPath(x: number, z: number): number
	local best = math.huge
	for _, p in Paths do
		best = math.min(best, World.DistToSegment(x, z, p.AX, p.AZ, p.BX, p.BZ))
	end
	return best
end

-- Name of the area a point is in, for the location label.
function World.AreaName(x: number, z: number): string
	if math.sqrt((x - Hub.X) ^ 2 + (z - Hub.Z) ^ 2) <= Hub.Radius + 15 then
		return "Blastwright Depot"
	end
	for _, b in Biomes do
		if math.sqrt((x - b.X) ^ 2 + (z - b.Z) ^ 2) <= 125 then
			return b.Name
		end
	end
	return "The Deep Roads"
end

return World
