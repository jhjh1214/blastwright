--!strict
-- Deterministic chain-reaction simulator. Pure: no Roblox APIs, does not mutate the grid.
-- The SERVER runs this to decide rewards; the CLIENT runs the same code for the chain preview.

export type Cell = { Kind: string, Mutated: boolean? }
export type Grid = { Size: number, Cells: { [number]: Cell } }
export type Charge = { X: number, Z: number, Kind: string }
export type Event = {
	T: number,
	X: number,
	Z: number,
	Kind: string,
	Value: number,
	Mult: number,
	Mutated: boolean,
	Cause: string, -- Charge | Chain | Beam
	SX: number, -- the cell that set this crystal off (the charge cell, or the crystal whose blast reached it)
	SZ: number,
	Lit: number?, -- Delayed crystals only: when the fuse was lit (T is when it actually pops)
}
export type Context = {
	Crystals: { [string]: any },
	Charges: { [string]: any },
	Tuning: any,
	RadiusBonus: number?,
	MomentumPops: number?,
}
export type Result = {
	Events: { Event },
	Pops: number,
	Raw: number,
	Bonus: number,
	Total: number,
	PeakMult: number,
	Tier: string?,
	Duration: number,
	Momentum: boolean,
}

type QueueItem = { T: number, Seq: number, X: number, Z: number, Cause: string, SX: number, SZ: number, Lit: number? }

local ChainSim = {}

function ChainSim.Key(size: number, x: number, z: number): number
	return (z - 1) * size + x
end

-- The cells a blast covers, clipped to the grid, with each cell's distance in cells from the origin (used for timing).
-- Shapes: Radius (round), Column (up and down the z axis), Row (along the x axis), Cross (row and column together). Shared by the sim and the preview.
function ChainSim.BlastCells(shape: string, ox: number, oz: number, radius: number, range: number, size: number): { { X: number, Z: number, D: number } }
	local cells = {}
	local function add(x: number, z: number, d: number)
		if x >= 1 and x <= size and z >= 1 and z <= size then
			table.insert(cells, { X = x, Z = z, D = d })
		end
	end
	if shape == "Radius" then
		local reach = math.ceil(radius)
		for dz = -reach, reach do
			for dx = -reach, reach do
				local d = math.sqrt(dx * dx + dz * dz)
				if d <= radius then
					add(ox + dx, oz + dz, d)
				end
			end
		end
	elseif shape == "Column" then
		for dz = -range, range do
			add(ox, oz + dz, math.abs(dz))
		end
	elseif shape == "Row" then
		for dx = -range, range do
			add(ox + dx, oz, math.abs(dx))
		end
	elseif shape == "Cross" then
		for d = -range, range do
			add(ox + d, oz, math.abs(d))
			if d ~= 0 then
				add(ox, oz + d, math.abs(d)) -- the center is already covered by the row arm
			end
		end
	end
	return cells
end

function ChainSim.Run(grid: Grid, charges: { Charge }, ctx: Context): Result
	local size = grid.Size
	local tuning = ctx.Tuning
	local dead: { [number]: boolean } = {}
	local pending: { [number]: number } = {}
	local queue: { QueueItem } = {}
	local seq = 0

	-- Schedule a cell to pop at time t; keeps only the earliest pending time per cell.
	local function schedule(x: number, z: number, t: number, cause: string, sx: number, sz: number)
		if x < 1 or x > size or z < 1 or z > size then
			return
		end
		local key = ChainSim.Key(size, x, z)
		local cell = grid.Cells[key]
		if cell == nil or dead[key] then
			return
		end
		-- Delayed crystals light a fuse when hit and pop later; t is the effective pop time.
		local lit: number? = nil
		local def = ctx.Crystals[cell.Kind]
		if def.Behavior == "Delayed" then
			lit = t
			t += def.Params.Delay
		end
		local existing = pending[key]
		if existing ~= nil and existing <= t then
			return
		end
		pending[key] = t
		seq += 1
		local lo, hi = 1, #queue + 1
		while lo < hi do
			local mid = (lo + hi) // 2
			local q = queue[mid]
			if q.T < t or (q.T == t and q.Seq < seq) then
				lo = mid + 1
			else
				hi = mid
			end
		end
		table.insert(queue, lo, { T = t, Seq = seq, X = x, Z = z, Cause = cause, SX = sx, SZ = sz, Lit = lit })
	end

	local function blast(ox: number, oz: number, t0: number, shape: string, radius: number, range: number, cause: string)
		local step = tuning.StepPerCell
		for _, c in ChainSim.BlastCells(shape, ox, oz, radius, range, size) do
			schedule(c.X, c.Z, t0 + c.D * step, cause, ox, oz)
		end
	end

	for _, c in charges do
		local def = ctx.Charges[c.Kind]
		if def ~= nil then
			local radius = (def.Radius or 0) + (def.Shape == "Radius" and (ctx.RadiusBonus or 0) or 0)
			blast(c.X, c.Z, 0, def.Shape, radius, def.Range or 0, "Charge")
		end
	end

	local events: { Event } = {}
	local mult = 1
	local peak = 1
	local raw = 0

	while #queue > 0 do
		local item = table.remove(queue, 1) :: QueueItem
		local key = ChainSim.Key(size, item.X, item.Z)
		if not dead[key] and pending[key] == item.T then
			dead[key] = true
			local cell = grid.Cells[key]
			local def = ctx.Crystals[cell.Kind]
			local behavior = def.Behavior
			local value = 0
			local mutMult = cell.Mutated and tuning.MutationValueMult or 1

			if behavior == "Unstable" then
				mult = math.max(1, mult * def.Params.MultScale)
			elseif behavior == "Amplifier" then
				mult += def.Params.MultAdd
				value = def.Value * mutMult * mult
			else
				value = def.Value * mutMult * mult
			end
			peak = math.max(peak, mult)

			if behavior == "Volatile" or behavior == "Delayed" then
				blast(item.X, item.Z, item.T + tuning.VolatileDelay, "Radius", def.Params.Radius, 0, "Chain")
			elseif behavior == "Relay" then
				blast(item.X, item.Z, item.T + tuning.VolatileDelay, "Radius", def.Params.Radius, 0, "Chain")
				-- Set off every other crystal of the same kind. Scanned by numeric key (not pairs) so the result never
				-- depends on how the grid table happens to be laid out in memory.
				for k = 1, size * size do
					local other = grid.Cells[k]
					if other ~= nil and other.Kind == cell.Kind and k ~= key and not dead[k] then
						schedule((k - 1) % size + 1, (k - 1) // size + 1, item.T + tuning.RelayDelay, "Chain", item.X, item.Z)
					end
				end
			elseif behavior == "Prism" then
				blast(item.X, item.Z, item.T + tuning.PrismDelay, "Row", 0, def.Params.Range, "Beam")
			end

			local rounded = math.floor(value + 0.5)
			raw += rounded
			table.insert(events, {
				T = item.T,
				X = item.X,
				Z = item.Z,
				Kind = cell.Kind,
				Value = rounded,
				Mult = mult,
				Mutated = cell.Mutated == true,
				Cause = item.Cause,
				SX = item.SX,
				SZ = item.SZ,
				Lit = item.Lit,
			})
		end
	end

	local pops = #events
	local tier: string? = nil
	local bonus = 0
	for _, t in tuning.ChainTiers do
		if pops >= t.Pops then
			tier = t.Name
			bonus = t.Bonus
		end
	end

	local duration = 0
	if pops > 0 then
		duration = events[pops].T + 0.4
	end

	return {
		Events = events,
		Pops = pops,
		Raw = raw,
		Bonus = bonus,
		Total = math.floor(raw * (1 + bonus)),
		PeakMult = peak,
		Tier = tier,
		Duration = duration,
		Momentum = pops >= (ctx.MomentumPops or tuning.MomentumPops),
	}
end

return ChainSim
