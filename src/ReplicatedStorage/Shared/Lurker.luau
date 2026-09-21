--!strict
-- Lurker (hidden monster) logic. Pure: no Roblox APIs and no clock; randomness arrives as a roll in [0, 1).
-- ctx = { Crystals, Charges, BlastCells, Size } (BlastCells is ChainSim.BlastCells, passed in so this file needs no
-- `script` require). The server owns monsters; clients only see them in the seam payload.
export type Monster = { Kind: string, X: number, Z: number, HP: number, MaxHP: number, Turn: number }

local Lurker = {}

local function key(size: number, x: number, z: number): number
	return (z - 1) * size + x
end

-- `firstFight` = the player has never slain a Lurker but knows the basics: a high pity chance so the combat side of the game
-- is met early instead of maybe never.
function Lurker.SpawnChance(stratum: number, floor: number, cfg: any, firstFight: boolean?): number
	local s = cfg.Spawn
	local chance = math.min(s.Cap, s.BaseChance + s.PerStratum * (stratum - 1) + s.PerFloor * floor)
	if firstFight then
		chance = math.max(chance, s.FirstFightChance)
	end
	return chance
end

-- Uniform pick among the kinds that appear in this area.
function Lurker.PickKind(stratum: number, roll: number, cfg: any): string
	local eligible = {}
	for _, id in cfg.Order do
		if cfg.Defs[id].Stratum <= stratum then
			table.insert(eligible, id)
		end
	end
	return eligible[math.min(#eligible, math.floor(roll * #eligible) + 1)]
end

-- The cell a Lurker hides under: one of the valuable crystals (never empty cells or hazards), chosen by `roll`.
function Lurker.Hide(grid: any, ctx: any, kind: string, roll: number): { Kind: string, X: number, Z: number }?
	local size = grid.Size
	local spots = {}
	for z = 1, size do
		for x = 1, size do
			local cell = grid.Cells[key(size, x, z)]
			if cell and ctx.Crystals[cell.Kind].Value > 0 then
				table.insert(spots, { X = x, Z = z })
			end
		end
	end
	if #spots == 0 then
		return nil
	end
	local spot = spots[math.min(#spots, math.floor(roll * #spots) + 1)]
	return { Kind = kind, X = spot.X, Z = spot.Z }
end

-- True when the volley popped the hidden Lurker's crystal.
function Lurker.Revealed(hidden: { X: number, Z: number }, events: { any }): boolean
	for _, ev in events do
		if ev.X == hidden.X and ev.Z == hidden.Z then
			return true
		end
	end
	return false
end

function Lurker.New(kind: string, x: number, z: number, cfg: any): Monster
	local hp = cfg.Defs[kind].HP
	return { Kind = kind, X = x, Z = z, HP = hp, MaxHP = hp, Turn = 0 }
end

-- Damage a volley does to a monster: each charge whose blast covers its cell hits it (armor cuts, a weakness doubles),
-- plus a little splash from crystals that popped right next to it.
function Lurker.Damage(m: Monster, volley: { any }, result: any, ctx: any, cfg: any): number
	local def = cfg.Defs[m.Kind]
	local size = ctx.Size or 9
	local total = 0
	for _, charge in volley do
		local cdef = ctx.Charges[charge.Kind]
		local direct = cfg.Damage.Direct[charge.Kind]
		if cdef and direct then
			for _, c in ctx.BlastCells(cdef.Shape, charge.X, charge.Z, cdef.Radius or 0, cdef.Range or 0, size) do
				if c.X == m.X and c.Z == m.Z then
					local dmg = math.max(1, direct - (def.Armor or 0))
					if def.Weak == charge.Kind then
						dmg *= 2
					end
					total += dmg
					break
				end
			end
		end
	end
	local near = 0
	for _, ev in result.Events do
		if math.abs(ev.X - m.X) <= 1 and math.abs(ev.Z - m.Z) <= 1 then
			near += 1
		end
	end
	return total + math.min(near, cfg.Damage.SplashCap) * cfg.Damage.Splash
end

-- Returns whether it is still alive.
function Lurker.Hit(m: Monster, damage: number): boolean
	m.HP = math.max(0, m.HP - damage)
	return m.HP > 0
end

function Lurker.Bounty(kind: string, cfg: any): number
	return cfg.Defs[kind].Bounty
end

function Lurker.RepairFee(earned: number, cfg: any): number
	return math.max(0, math.floor(earned * cfg.Defeat.RepairFraction))
end

-- True when the monster's NEXT turn will smash the rig (so the client can warn a turn ahead).
function Lurker.Telegraph(m: Monster, cfg: any): boolean
	local def = cfg.Defs[m.Kind]
	return def.Behavior == "Smash" and (m.Turn + 1) % def.Params.EveryTurns == 0
end

local function isValuable(grid: any, ctx: any, x: number, z: number): boolean
	local cell = grid.Cells[key(grid.Size, x, z)]
	return cell ~= nil and ctx.Crystals[cell.Kind].Value > 0
end

local function inBounds(size: number, x: number, z: number): boolean
	return x >= 1 and x <= size and z >= 1 and z <= size
end

-- The monster's turn. Mutates the monster and the grid. Returns what happened so the server can apply the rig effects:
-- { Eaten = { {X, Z} }, ChargesDrained = n, HeartsLost = n, Moved = bool, Stolen = fraction of the volley payout }
function Lurker.Act(m: Monster, grid: any, ctx: any, cfg: any)
	local def = cfg.Defs[m.Kind]
	local size = grid.Size
	local act = { Eaten = {}, ChargesDrained = 0, HeartsLost = 0, Moved = false, Stolen = 0 }
	m.Turn += 1
	if def.Behavior == "Drain" then
		act.ChargesDrained = def.Params.Amount
	elseif def.Behavior == "Smash" then
		if m.Turn % def.Params.EveryTurns == 0 then
			act.HeartsLost = 1
		end
	elseif def.Behavior == "Steal" then
		act.Stolen = def.Params.Fraction -- the server takes this share of the volley's payout
	elseif def.Behavior == "Eat" or def.Behavior == "Dash" then
		local perTurn = def.Params.PerTurn
		local steps = def.Behavior == "Dash" and def.Params.Steps or 1
		for _ = 1, steps do
			-- Scan row by row so ties always resolve the same way.
			for dz = -1, 1 do
				for dx = -1, 1 do
					local x, z = m.X + dx, m.Z + dz
					if (dx ~= 0 or dz ~= 0) and inBounds(size, x, z) and #act.Eaten < perTurn and isValuable(grid, ctx, x, z) then
						table.insert(act.Eaten, { X = x, Z = z })
					end
				end
			end
			for _, e in act.Eaten do
				grid.Cells[key(size, e.X, e.Z)] = nil
			end
			if #act.Eaten > 0 then
				break
			end
			-- Nothing to eat next to it: step toward the nearest valuable crystal, onto an empty cell.
			local target, best = nil, math.huge
			for z = 1, size do
				for x = 1, size do
					if isValuable(grid, ctx, x, z) then
						local d = math.max(math.abs(x - m.X), math.abs(z - m.Z))
						if d < best then
							target, best = { X = x, Z = z }, d
						end
					end
				end
			end
			if not target then
				break
			end
			local stepTo, stepScore = nil, math.huge
			for dz = -1, 1 do
				for dx = -1, 1 do
					local x, z = m.X + dx, m.Z + dz
					if (dx ~= 0 or dz ~= 0) and inBounds(size, x, z) and grid.Cells[key(size, x, z)] == nil then
						local cheb = math.max(math.abs(x - target.X), math.abs(z - target.Z))
						local score = cheb * 1000 + (x - target.X) ^ 2 + (z - target.Z) ^ 2
						if score < stepScore then
							stepTo, stepScore = { X = x, Z = z }, score
						end
					end
				end
			end
			if not stepTo then
				break
			end
			m.X, m.Z = stepTo.X, stepTo.Z
			act.Moved = true
		end
	end
	return act
end

return Lurker
