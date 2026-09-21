--!strict
-- Server Goal logic. Pure: no Roblox APIs; the caller passes the clock. The server owns the state; clients only see View.

export type State = {
	Round: number,
	Progress: number,
	Target: number,
	Done: boolean,
	FrenzyUntil: number,
	Contributors: { [number]: number },
}

local Community = {}

-- Pops needed for a round given how many players are online (at least one).
function Community.Target(playerCount: number, cfg: any): number
	local players = math.max(1, math.floor(playerCount))
	return math.min(cfg.MaxTarget, cfg.BasePops + (players - 1) * cfg.PopsPerPlayer)
end

function Community.New(round: number, playerCount: number, cfg: any): State
	return {
		Round = round,
		Progress = 0,
		Target = Community.Target(playerCount, cfg),
		Done = false,
		FrenzyUntil = 0,
		Contributors = {},
	}
end

-- Adds a player's pops. Returns true only for the contribution that completes the goal (once per round).
function Community.Contribute(state: State, userId: number, pops: number): boolean
	if not (pops > 0 and pops < math.huge) then
		return false -- also rejects NaN
	end
	state.Contributors[userId] = (state.Contributors[userId] or 0) + pops
	state.Progress += pops
	if not state.Done and state.Progress >= state.Target then
		state.Done = true
		return true
	end
	return false
end

function Community.Rewardees(state: State): { number }
	local out = {}
	for userId in state.Contributors do
		table.insert(out, userId)
	end
	return out
end

function Community.StartFrenzy(state: State, now: number, cfg: any)
	state.FrenzyUntil = now + cfg.FrenzySeconds
end

function Community.FrenzyLeft(state: State, now: number): number
	return math.max(0, state.FrenzyUntil - now)
end

-- Payout multiplier from the frenzy (1 when none is running).
function Community.Mult(state: State, now: number, cfg: any): number
	return now < state.FrenzyUntil and cfg.FrenzyShardMult or 1
end

function Community.View(state: State, now: number, cfg: any)
	return {
		Round = state.Round,
		Progress = state.Progress,
		Target = state.Target,
		Done = state.Done,
		FrenzyLeft = Community.FrenzyLeft(state, now),
	}
end

return Community
