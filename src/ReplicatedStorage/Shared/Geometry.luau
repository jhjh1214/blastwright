--!strict
-- World-space layout of blast sites and their cavern grids. Server and client must agree, so it lives in Shared.
local Config = script.Parent.Config
local Tuning = require(Config.Tuning)
local WorldConfig = require(Config.World)

local Geometry = {}

function Geometry.Extent(): number
	return Tuning.GridSize * Tuning.CellSize
end

-- Center of a site's cavern grid.
function Geometry.Origin(siteId: number): Vector3
	local site = WorldConfig.Sites[siteId]
	return Vector3.new(site.X, 0, site.Z)
end

-- Where the player stands (and the blast prompt lives) for a site: just off the pad's south edge.
function Geometry.Station(siteId: number): Vector3
	return Geometry.Origin(siteId) + Vector3.new(0, 0, -(Geometry.Extent() / 2) - 7)
end

function Geometry.CellPosition(origin: Vector3, x: number, z: number): Vector3
	local center = (Tuning.GridSize + 1) / 2
	return origin + Vector3.new((x - center) * Tuning.CellSize, 0, (z - center) * Tuning.CellSize)
end

-- Returns integer cell coords, or nil when the point is outside the grid.
function Geometry.WorldToCell(origin: Vector3, pos: Vector3): (number?, number?)
	local center = (Tuning.GridSize + 1) / 2
	local x = math.floor((pos.X - origin.X) / Tuning.CellSize + center + 0.5)
	local z = math.floor((pos.Z - origin.Z) / Tuning.CellSize + center + 0.5)
	if x < 1 or x > Tuning.GridSize or z < 1 or z > Tuning.GridSize then
		return nil, nil
	end
	return x, z
end

return Geometry
