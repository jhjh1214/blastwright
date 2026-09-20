--!strict
-- World-space layout of per-player caverns. Server and client must agree, so it lives in Shared.
local Tuning = require(script.Parent.Config.Tuning)

local Geometry = {}

function Geometry.Origin(slot: number): Vector3
	return Vector3.new(slot * Tuning.SlotSpacing, 0, 0)
end

function Geometry.Extent(): number
	return Tuning.GridSize * Tuning.CellSize
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
