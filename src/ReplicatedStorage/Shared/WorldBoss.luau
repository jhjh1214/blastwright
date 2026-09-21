--!strict
-- The server-wide world boss. Pure (no Roblox APIs): the server owns the state and pays rewards, clients only display it.
-- State: { Cycle, MaxHP, HP, Damage = { [userId] = total }, Done, Settled }.

export type State = { Cycle: number, MaxHP: number, HP: number, Damage: { [number]: number }, Done: boolean, Settled: boolean }

local WorldBoss = {}

-- Is the boss up at time `now`, and which appearance is it? Cycles are aligned to the clock so every server agrees.
function WorldBoss.Window(now: number, cfg: any): { Active: boolean, Cycle: number, EndsIn: number, NextIn: number }
	local cycle = now // cfg.CycleSeconds
	local into = now % cfg.CycleSeconds
	local active = into < cfg.ActiveSeconds
	return {
		Active = active,
		Cycle = cycle,
		EndsIn = active and cfg.ActiveSeconds - into or 0,
		NextIn = active and 0 or cfg.CycleSeconds - into,
	}
end

function WorldBoss.MaxHP(players: number, cfg: any): number
	local n = math.max(cfg.MinPlayers, math.floor(players))
	return cfg.BaseHP + cfg.HPPerPlayer * n
end

function WorldBoss.New(cycle: number, players: number, cfg: any): State
	local hp = WorldBoss.MaxHP(players, cfg)
	return { Cycle = cycle, MaxHP = hp, HP = hp, Damage = {}, Done = false, Settled = false }
end

-- Damage one volley of `pops` pops does. Chains hit disproportionately hard.
function WorldBoss.VolleyDamage(pops: number, cfg: any): number
	if pops ~= pops or pops <= 0 then
		return 0
	end
	pops = math.min(pops, 500)
	return math.floor(pops * (1 + pops / cfg.ChainBonusPer))
end

-- A player's volley hits the boss. Returns the damage actually dealt (0 once it is down); marks it Done at 0 HP.
function WorldBoss.Hit(state: State, userId: number, pops: number, cfg: any): number
	if state.Done or type(userId) ~= "number" then
		return 0
	end
	local dealt = math.min(state.HP, WorldBoss.VolleyDamage(pops, cfg))
	if dealt <= 0 then
		return 0
	end
	state.HP -= dealt
	state.Damage[userId] = (state.Damage[userId] or 0) + dealt
	if state.HP <= 0 then
		state.HP, state.Done = 0, true
	end
	return dealt
end

-- Contributors ranked by damage (ties broken by user id so the order is the same every time).
function WorldBoss.Ranking(state: State): { { UserId: number, Damage: number } }
	local list = {}
	for userId, dmg in state.Damage do
		table.insert(list, { UserId = userId, Damage = dmg })
	end
	table.sort(list, function(a, b)
		if a.Damage ~= b.Damage then
			return a.Damage > b.Damage
		end
		return a.UserId < b.UserId
	end)
	return list
end

-- What each contributor is owed. Returns { { UserId, Rank, Damage, Grants } } where Grants is a list for Shared/Grants.
-- Everyone at or above MinDamage gets the participant grants; when the boss was beaten they also get the Defeated grants, and
-- the top TopCount get the Top grants. Marks the state Settled so it can only be paid once.
function WorldBoss.Settle(state: State, cfg: any): { any }
	if state.Settled then
		return {}
	end
	state.Settled = true
	local payouts = {}
	for rank, entry in WorldBoss.Ranking(state) do
		if entry.Damage >= cfg.MinDamage then
			local grants = {}
			for _, g in cfg.Rewards.Participant do
				table.insert(grants, g)
			end
			if state.Done then
				for _, g in cfg.Rewards.Defeated do
					table.insert(grants, g)
				end
				if rank <= cfg.TopCount then
					for _, g in cfg.Rewards.Top do
						table.insert(grants, g)
					end
				end
			end
			table.insert(payouts, { UserId = entry.UserId, Rank = rank, Damage = entry.Damage, Grants = grants })
		end
	end
	return payouts
end

-- What the client shows.
function WorldBoss.View(state: State?, now: number, cfg: any)
	local window = WorldBoss.Window(now, cfg)
	if not state or state.Settled then
		return { Active = false, NextIn = window.NextIn, Name = cfg.Name }
	end
	return { Active = not state.Done, Defeated = state.Done, Name = cfg.Name, HP = state.HP, MaxHP = state.MaxHP, EndsIn = window.EndsIn, NextIn = window.NextIn }
end

return WorldBoss
