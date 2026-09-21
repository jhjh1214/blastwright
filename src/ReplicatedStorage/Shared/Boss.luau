--!strict
-- Boss fight logic (crystal puzzles under pressure). Pure: no Roblox APIs, no clock; randomness is a function -> [0, 1).
-- ctx = { Crystals, Charges, BlastCells, Size }. The server owns the state; clients only receive Boss.View.
--
-- Phases: Armor (pop the armor nodes; the boss takes no damage) -> Attack (chains and charges near the core hurt it while
-- it telegraphs slams) -> Weak (chain through BOTH weak points for a massive hit) -> Enrage (two slams at once) ->
-- Finisher (one huge chain, or Critical Mass, ends it).
export type Cell = { X: number, Z: number }
export type State = {
	Kind: string,
	HP: number,
	MaxHP: number,
	Phase: string, -- Armor | Attack | Weak | Enrage | Finisher | Dead
	Nodes: { Cell },
	Weak: { Cell },
	Telegraph: { Cell }, -- cells the NEXT attack will hit
	Turn: number,
	DodgeCooldown: number,
	FinisherTries: number,
}

local Boss = {}

local function key(size: number, x: number, z: number): number
	return (z - 1) * size + x
end

local function shuffle(list: { any }, rng: () -> number)
	for i = #list, 2, -1 do
		local j = math.floor(rng() * i) + 1
		list[i], list[j] = list[j], list[i]
	end
end

local function valuableCells(grid: any, ctx: any, avoid: (number, number) -> boolean): { Cell }
	local out = {}
	for z = 1, grid.Size do
		for x = 1, grid.Size do
			local cell = grid.Cells[key(grid.Size, x, z)]
			if cell and ctx.Crystals[cell.Kind].Value > 0 and not avoid(x, z) then
				table.insert(out, { X = x, Z = z })
			end
		end
	end
	return out
end

-- `count` valuable crystal cells, at least `minDist` apart (Chebyshev) where the grid allows it.
local function pickSpread(grid: any, ctx: any, count: number, minDist: number, rng: () -> number, avoid: (number, number) -> boolean): { Cell }
	local pool = valuableCells(grid, ctx, avoid)
	shuffle(pool, rng)
	local picked: { Cell } = {}
	for _, c in pool do
		local ok = true
		for _, p in picked do
			if math.max(math.abs(c.X - p.X), math.abs(c.Z - p.Z)) < minDist then
				ok = false
				break
			end
		end
		if ok then
			table.insert(picked, c)
			if #picked == count then
				return picked
			end
		end
	end
	for _, c in pool do -- not enough spread-out cells: fill up with whatever is left
		if #picked == count then
			break
		end
		local dup = false
		for _, p in picked do
			if p.X == c.X and p.Z == c.Z then
				dup = true
			end
		end
		if not dup then
			table.insert(picked, c)
		end
	end
	return picked
end

local function inCore(def: any, x: number, z: number, reach: number): boolean
	return math.abs(x - def.Core.X) <= reach and math.abs(z - def.Core.Z) <= reach
end

-- Start a fight on `grid`: the 3x3 core is cleared (so charges can reach it) and the armor nodes are chosen.
function Boss.New(kind: string, grid: any, ctx: any, cfg: any, rng: () -> number): State
	local def = cfg.Defs[kind]
	for dz = -1, 1 do
		for dx = -1, 1 do
			grid.Cells[key(grid.Size, def.Core.X + dx, def.Core.Z + dz)] = nil
		end
	end
	return {
		Kind = kind,
		HP = def.MaxHP,
		MaxHP = def.MaxHP,
		Phase = "Armor",
		Nodes = pickSpread(grid, ctx, def.Nodes, 2, rng, function()
			return false
		end),
		Weak = {},
		Telegraph = {},
		Turn = 0,
		DodgeCooldown = 0,
		FinisherTries = 0,
	}
end

local function popped(events: { any }, cell: Cell): boolean
	for _, ev in events do
		if ev.X == cell.X and ev.Z == cell.Z then
			return true
		end
	end
	return false
end

local function phaseFor(state: State, def: any): string
	local f = state.HP / state.MaxHP
	if f <= def.FinisherAt then
		return "Finisher"
	elseif f <= def.WeakEnd then
		return "Enrage"
	elseif f <= def.AttackEnd then
		return "Weak"
	end
	return "Attack"
end

-- Damage from charges reaching the core, splash from crystals popping near it, and a bonus for long chains.
local function coreDamage(state: State, volley: { any }, result: any, ctx: any, def: any): number
	local total = 0
	for _, charge in volley do
		local cdef = ctx.Charges[charge.Kind]
		local direct = def.Direct[charge.Kind]
		if cdef and direct then
			for _, c in ctx.BlastCells(cdef.Shape, charge.X, charge.Z, cdef.Radius or 0, cdef.Range or 0, ctx.Size) do
				if inCore(def, c.X, c.Z, 1) then
					total += direct
					break
				end
			end
		end
	end
	local near = 0
	for _, ev in result.Events do
		if inCore(def, ev.X, ev.Z, 2) then
			near += 1
		end
	end
	return total + math.min(near, def.SplashCap) * def.Splash + result.Pops // def.PopsPerBonus
end

-- Resolve a volley against the boss. `power` multiplies damage (Power.Multiplier). Returns
-- { Damage, NodesBroken, Refund, PhaseChanged, Killed, WeakHit } and mutates the state.
function Boss.Apply(state: State, volley: { any }, result: any, ctx: any, cfg: any, power: number, grid: any, rng: () -> number)
	local def = cfg.Defs[state.Kind]
	local out = { Damage = 0, NodesBroken = 0, Refund = 0, PhaseChanged = false, Killed = false, WeakHit = 0 }
	local before = state.Phase

	if state.Phase == "Armor" then
		local left = {}
		for _, node in state.Nodes do
			if popped(result.Events, node) then
				out.NodesBroken += 1
			else
				table.insert(left, node)
			end
		end
		state.Nodes = left
		if #left == 0 then
			-- Armor broken: the boss takes a hit and the fight opens up.
			out.Damage = math.floor(def.ArmorBreakDamage * power)
			state.HP = math.max(1, state.HP - out.Damage)
			state.Phase = "Attack"
		end
	elseif state.Phase == "Attack" or state.Phase == "Enrage" then
		out.Damage = math.floor(coreDamage(state, volley, result, ctx, def) * power)
		state.HP = math.max(0, state.HP - out.Damage)
	elseif state.Phase == "Weak" then
		local hit = 0
		for _, w in state.Weak do
			if popped(result.Events, w) then
				hit += 1
			end
		end
		out.WeakHit = hit
		local base
		if hit >= #state.Weak and hit > 0 then
			base = def.Weak.Both
		elseif hit > 0 then
			base = def.Weak.One
		else
			base = result.Pops // def.Weak.PopsPerMiss
		end
		out.Damage = math.floor(base * power)
		state.HP = math.max(0, state.HP - out.Damage)
	elseif state.Phase == "Finisher" then
		if result.Pops >= def.Finisher.Pops or power >= 2 then
			out.Damage = state.HP
			state.HP = 0
		else
			state.FinisherTries += 1
			state.HP = math.min(state.MaxHP, state.HP + def.Finisher.HealOnFail)
			out.Damage = 0
		end
	end

	if state.HP <= 0 then
		state.Phase = "Dead"
		out.Killed = true
		out.PhaseChanged = true
	else
		if before ~= "Armor" and before ~= "Finisher" then
			state.Phase = phaseFor(state, def) -- once the armor is off, HP decides the phase (a failed finisher stays one)
		end
		if state.Phase ~= before then
			out.PhaseChanged = true
			out.Refund = def.PhaseRefund
		end
	end

	-- New weak points whenever the boss is in (or has just entered) the weak-point phase.
	if state.Phase == "Weak" then
		state.Weak = pickSpread(grid, ctx, def.Weak.Count, def.Weak.MinDist, rng, function(x, z)
			return inCore(def, x, z, 1)
		end)
	else
		state.Weak = {}
	end
	return out
end

local function lineCells(size: number, horizontal: boolean, index: number): { Cell }
	local cells = {}
	for i = 1, size do
		table.insert(cells, horizontal and { X = i, Z = index } or { X = index, Z = i })
	end
	return cells
end

-- The boss's turn. The attack telegraphed LAST turn lands now (unless dodged), destroying the crystals on it; then it
-- telegraphs the next one. Returns { Hit = { cells }, HeartsLost, Dodged, Eaten = { cells } }.
-- True when the volley popped enough crystals on the marked cells to cut the attack before it lands.
function Boss.Cut(state: State, result: any, cfg: any): boolean
	local def = cfg.Defs[state.Kind]
	if #state.Telegraph == 0 then
		return false
	end
	local n = 0
	for _, ev in result.Events do
		for _, c in state.Telegraph do
			if c.X == ev.X and c.Z == ev.Z then
				n += 1
				break
			end
		end
	end
	return n >= def.CutPops
end

function Boss.Act(state: State, grid: any, ctx: any, cfg: any, dodged: boolean, rng: () -> number, cut: boolean?)
	local def = cfg.Defs[state.Kind]
	local out = { Hit = {}, HeartsLost = 0, Dodged = false, Cut = false, Eaten = {} }
	state.Turn += 1
	state.DodgeCooldown = math.max(0, state.DodgeCooldown - 1)

	if #state.Telegraph > 0 then
		out.Hit = state.Telegraph
		if cut then
			out.Cut = true -- the player's chain broke the attack apart
		else
			for _, c in state.Telegraph do
				local k = key(grid.Size, c.X, c.Z)
				if grid.Cells[k] then
					grid.Cells[k] = nil
					table.insert(out.Eaten, { X = c.X, Z = c.Z })
				end
			end
			if dodged then
				out.Dodged = true
			else
				out.HeartsLost = 1
			end
		end
	end
	if dodged and not cut then
		state.DodgeCooldown = def.Dodge.Cooldown
	end

	state.Telegraph = {}
	local lines = 0
	if state.Phase == "Attack" and state.Turn % def.AttackEvery == 0 then
		lines = 1
	elseif state.Phase == "Enrage" then
		lines = def.EnrageLines
	elseif state.Phase == "Weak" and state.Turn % 2 == 0 then
		lines = 1
	elseif state.Phase == "Finisher" then
		lines = 1
	end
	local used = {}
	for _ = 1, lines do
		local horizontal = rng() < 0.5
		local index = math.floor(rng() * grid.Size) + 1
		local id = (horizontal and "h" or "v") .. index
		if not used[id] then
			used[id] = true
			for _, c in lineCells(grid.Size, horizontal, index) do
				table.insert(state.Telegraph, c)
			end
		end
	end
	return out
end

function Boss.CanDodge(state: State): boolean
	return state.DodgeCooldown <= 0 and #state.Telegraph > 0
end

-- What the client needs: bar, phase, and the marked cells.
function Boss.View(state: State, cfg: any)
	local def = cfg.Defs[state.Kind]
	return {
		Kind = state.Kind,
		Name = def.Name,
		HP = state.HP,
		MaxHP = state.MaxHP,
		Phase = state.Phase,
		Nodes = state.Nodes,
		Weak = state.Weak,
		Telegraph = state.Telegraph,
		Core = def.Core,
		DodgeReady = Boss.CanDodge(state),
		DodgeCooldown = state.DodgeCooldown,
	}
end

return Boss
