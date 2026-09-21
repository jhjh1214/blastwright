--!strict
-- Real-time boss attacks. Pure: no Roblox APIs; `now` is a clock in seconds passed in, randomness is a function -> [0, 1).
-- The boss winds up attacks on a timer; each is telegraphed on the grid and lands after a delay. Every attack is answered
-- by the crystal system you already know:
--   SLAM        a marked row/column       -> pop enough crystals on it (cut) or use Dodge
--   METEOR      marked 3x3 impact zones   -> pop a PRISM crystal (Lensglass): its beam deflects one zone per pop, or Dodge
--   CORRUPTION  purple-marked crystals    -> pop the marked crystals before it lands (each survivor becomes a Dreadgeode)
-- Dodge is a short shield window (real-time reaction) with a cooldown. The turn-based Boss.Act in Boss.luau is unused now.
export type Threat = {
	Id: number,
	Type: string,
	LandsAt: number,
	Cancelled: boolean,
	Cells: { { X: number, Z: number } }, -- Slam: the line
	Zones: { { X: number, Z: number, Cancelled: boolean } }, -- Meteor: impact centres (3x3 each)
	Marks: { { X: number, Z: number } }, -- Corruption: crystals that will be corrupted
}
export type State = { NextAt: number, Threats: { Threat }, ShieldUntil: number, DodgeReadyAt: number, NextId: number }

local BossRT = {}

local function key(size: number, x: number, z: number): number
	return (z - 1) * size + x
end

function BossRT.New(now: number, kind: string, cfg: any): State
	return { NextAt = now + cfg.Defs[kind].RT.FirstAttackDelay, Threats = {}, ShieldUntil = 0, DodgeReadyAt = 0, NextId = 1 }
end

local function shuffle(list: { any }, rng: () -> number)
	for i = #list, 2, -1 do
		local j = math.floor(rng() * i) + 1
		list[i], list[j] = list[j], list[i]
	end
end

local function valuable(grid: any, ctx: any, core: { X: number, Z: number }): { { X: number, Z: number } }
	local out = {}
	for z = 1, grid.Size do
		for x = 1, grid.Size do
			local cell = grid.Cells[key(grid.Size, x, z)]
			if cell and ctx.Crystals[cell.Kind].Value > 0 and not (math.abs(x - core.X) <= 1 and math.abs(z - core.Z) <= 1) then
				table.insert(out, { X = x, Z = z })
			end
		end
	end
	return out
end

-- Start the next attack if one is due and the phase allows more. Returns the new threat or nil.
function BossRT.Spawn(state: State, phase: string, kind: string, grid: any, ctx: any, now: number, rng: () -> number, cfg: any): Threat?
	local def = cfg.Defs[kind]
	local rt = def.RT
	local allowed = rt.Attacks[phase]
	if not allowed or now < state.NextAt or #state.Threats >= (rt.MaxThreats[phase] or 1) then
		return nil
	end
	local kindName = allowed[math.min(#allowed, math.floor(rng() * #allowed) + 1)]
	local threat: Threat = { Id = state.NextId, Type = kindName, LandsAt = now + rt[kindName].Delay, Cancelled = false, Cells = {}, Zones = {}, Marks = {} }
	if kindName == "Slam" then
		local horizontal = rng() < 0.5
		local index = math.floor(rng() * grid.Size) + 1
		for i = 1, grid.Size do
			table.insert(threat.Cells, horizontal and { X = i, Z = index } or { X = index, Z = i })
		end
	elseif kindName == "Meteor" then
		local pool = valuable(grid, ctx, def.Core)
		shuffle(pool, rng)
		for _, c in pool do
			local apart = true
			for _, z in threat.Zones do
				if math.max(math.abs(z.X - c.X), math.abs(z.Z - c.Z)) < 3 then
					apart = false
				end
			end
			if apart then
				table.insert(threat.Zones, { X = c.X, Z = c.Z, Cancelled = false })
				if #threat.Zones == rt.Meteor.Zones then
					break
				end
			end
		end
		if #threat.Zones == 0 then
			return nil -- nothing to aim at
		end
	else -- Corruption
		local pool = valuable(grid, ctx, def.Core)
		shuffle(pool, rng)
		for i = 1, math.min(rt.Corruption.Marks, #pool) do
			table.insert(threat.Marks, pool[i])
		end
		if #threat.Marks == 0 then
			return nil
		end
	end
	state.NextId += 1
	state.NextAt = now + rt.Interval[phase]
	table.insert(state.Threats, threat)
	return threat
end

local function popped(events: { any }, x: number, z: number): boolean
	for _, ev in events do
		if ev.X == x and ev.Z == z then
			return true
		end
	end
	return false
end

-- A volley resolved: apply what it did to every waiting threat. Returns { Cut, Deflected, Purified } counts.
function BossRT.Counter(state: State, events: { any }, ctx: any, kind: string, cfg: any)
	local def = cfg.Defs[kind]
	local out = { Cut = 0, Deflected = 0, Purified = 0 }
	local prismPops = 0
	for _, ev in events do
		if ctx.Crystals[ev.Kind] and ctx.Crystals[ev.Kind].Behavior == "Prism" then
			prismPops += 1
		end
	end
	for _, t in state.Threats do
		if t.Type == "Slam" and not t.Cancelled then
			local n = 0
			for _, c in t.Cells do
				if popped(events, c.X, c.Z) then
					n += 1
				end
			end
			if n >= def.CutPops then
				t.Cancelled = true
				out.Cut += 1
			end
		elseif t.Type == "Meteor" then
			for _, zone in t.Zones do
				if prismPops > 0 and not zone.Cancelled then
					zone.Cancelled = true
					prismPops -= 1
					out.Deflected += 1
				end
			end
		elseif t.Type == "Corruption" then
			local left = {}
			for _, m in t.Marks do
				if popped(events, m.X, m.Z) then
					out.Purified += 1
				else
					table.insert(left, m)
				end
			end
			t.Marks = left
		end
	end
	return out
end

-- Threats whose time has come are removed from the state and returned.
function BossRT.Due(state: State, now: number): { Threat }
	local due, keep = {}, {}
	for _, t in state.Threats do
		if t.LandsAt <= now then
			table.insert(due, t)
		else
			table.insert(keep, t)
		end
	end
	state.Threats = keep
	return due
end

function BossRT.IsShielded(state: State, now: number): boolean
	return now < state.ShieldUntil
end

-- Dodge: a short shield window with a cooldown. Returns whether it started.
function BossRT.Shield(state: State, now: number, kind: string, cfg: any): boolean
	if now < state.DodgeReadyAt then
		return false
	end
	local rt = cfg.Defs[kind].RT
	state.ShieldUntil = now + rt.ShieldSeconds
	state.DodgeReadyAt = now + rt.DodgeCooldown
	return true
end

-- What a landing threat does. Mutates the grid (crystals destroyed or corrupted into Dreadgeodes).
-- Returns { HeartsLost, Destroyed = { cells }, Corrupted = { cells }, Blocked = bool }.
function BossRT.Resolve(threat: Threat, grid: any, ctx: any, shielded: boolean, cfg: any)
	local out = { HeartsLost = 0, Destroyed = {}, Corrupted = {}, Blocked = false, Cancelled = false }
	local function destroy(x: number, z: number)
		if x >= 1 and x <= grid.Size and z >= 1 and z <= grid.Size then
			local k = key(grid.Size, x, z)
			if grid.Cells[k] then
				grid.Cells[k] = nil
				table.insert(out.Destroyed, { X = x, Z = z })
			end
		end
	end
	local hits = false
	if threat.Type == "Slam" then
		if threat.Cancelled then
			out.Cancelled = true
			return out
		end
		for _, c in threat.Cells do
			destroy(c.X, c.Z)
		end
		hits = true
	elseif threat.Type == "Meteor" then
		for _, zone in threat.Zones do
			if not zone.Cancelled then
				hits = true
				for dz = -1, 1 do
					for dx = -1, 1 do
						destroy(zone.X + dx, zone.Z + dz)
					end
				end
			end
		end
		if not hits then
			out.Cancelled = true
			return out
		end
	else -- Corruption
		if #threat.Marks == 0 then
			out.Cancelled = true
			return out
		end
		for _, m in threat.Marks do
			local k = key(grid.Size, m.X, m.Z)
			if grid.Cells[k] then
				grid.Cells[k] = { Kind = "Dreadgeode" }
				table.insert(out.Corrupted, { X = m.X, Z = m.Z })
			end
		end
		return out -- corruption costs crystals, not hearts
	end
	if hits then
		if shielded then
			out.Blocked = true
		else
			out.HeartsLost = 1
		end
	end
	return out
end

-- For the client: what is coming and how long until it lands.
function BossRT.View(state: State, now: number, cfg: any, kind: string)
	local rt = cfg.Defs[kind].RT
	local threats = {}
	for _, t in state.Threats do
		table.insert(threats, {
			Id = t.Id,
			Type = t.Type,
			LandsIn = math.max(0, t.LandsAt - now),
			Total = rt[t.Type].Delay,
			Cancelled = t.Cancelled,
			Cells = t.Cells,
			Zones = t.Zones,
			Marks = t.Marks,
		})
	end
	return {
		Threats = threats,
		Shielded = BossRT.IsShielded(state, now),
		ShieldLeft = math.max(0, state.ShieldUntil - now),
		DodgeReady = now >= state.DodgeReadyAt,
		DodgeLeft = math.max(0, state.DodgeReadyAt - now),
	}
end

return BossRT
