--!strict
-- Free daily reward streak. Pure (no Roblox APIs). State (save data `Streak`): { LastDay = UTC day of the last claim,
-- Count = current streak length (1 = claimed today after a break) }.
local Streak = {}

function Streak.Default()
	return { LastDay = 0, Count = 0 }
end

-- Which day of the 7-day cycle a streak length is on (1..cycle).
function Streak.CycleDay(count: number, cfg: any): number
	return (math.max(1, count) - 1) % #cfg.Days + 1
end

-- What the streak would be if the player claimed on `day` (without changing anything).
function Streak.NextCount(state: any, day: number, plus: boolean): number
	if state.LastDay == 0 then
		return 1
	end
	local gap = day - state.LastDay
	if gap == 1 or (gap == 2 and plus) then
		return state.Count + 1
	end
	return 1
end

function Streak.CanClaim(state: any, day: any): boolean
	return type(day) == "number" and day == day and day > state.LastDay
end

-- Claim today's reward. Returns the grants, or nil when already claimed today (or the clock went backwards).
function Streak.Claim(state: any, day: any, plus: boolean, cfg: any): { any }?
	if not Streak.CanClaim(state, day) then
		return nil
	end
	local count = Streak.NextCount(state, day :: number, plus)
	state.LastDay, state.Count = day :: number, count
	return cfg.Days[Streak.CycleDay(count, cfg)]
end

-- What the client shows: today's state, the streak and the reward list with the current day marked.
function Streak.View(state: any, day: number, plus: boolean, cfg: any)
	local claimable = Streak.CanClaim(state, day)
	local upcoming = claimable and Streak.NextCount(state, day, plus) or state.Count
	return { CanClaim = claimable, Count = upcoming, CycleDay = upcoming > 0 and Streak.CycleDay(upcoming, cfg) or 0 }
end

return Streak
