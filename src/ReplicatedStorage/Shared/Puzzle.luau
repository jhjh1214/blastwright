--!strict
-- Daily Puzzle logic. Pure: no Roblox APIs. The grid comes from Seam.Generate with Puzzle.Seed(day); everything else here
-- scores a result against a greedy par and works out streaks and rewards.
local Puzzle = {}

-- Any fixed scramble of the day number works; it just has to be the same for everyone and differ day to day.
function Puzzle.Seed(day: number): number
	return (day * 7919 + 104729) % 2147483646
end

-- Greedy par: choose each charge as the cell that maximises the total so far. Returns the par score and the picks.
-- `run` is ChainSim.Run (passed in so this module needs no `script` require and loads in the CLI tests).
function Puzzle.Par(grid: any, ctx: any, charges: number, run: (any, any, any) -> any): (number, { { X: number, Z: number, Kind: string } })
	local size = grid.Size
	local picks = {}
	local best = 0
	for _ = 1, charges do
		local bestCell, bestTotal = nil, best
		for z = 1, size do
			for x = 1, size do
				local trial = table.clone(picks)
				table.insert(trial, { X = x, Z = z, Kind = "Basic" })
				local total = run(grid, trial, ctx).Total
				if total > bestTotal then
					bestCell, bestTotal = { X = x, Z = z, Kind = "Basic" }, total
				end
			end
		end
		if not bestCell then
			break -- no cell improves the score
		end
		table.insert(picks, bestCell)
		best = bestTotal
	end
	return best, picks
end

-- The highest medal whose ratio the score reaches, or nil.
function Puzzle.Medal(score: number, par: number, cfg: any): string?
	if score <= 0 then
		return nil
	end
	local reference = math.max(par, 1)
	local earned = nil
	for _, medal in cfg.Medals do
		if score >= medal.Ratio * reference then
			earned = medal.Name
		end
	end
	return earned
end

function Puzzle.MedalReward(name: string, cfg: any): number
	for _, medal in cfg.Medals do
		if medal.Name == name then
			return medal.Reward
		end
	end
	return 0
end

-- Streak after playing on `today`, given the last day played and the streak then.
function Puzzle.Streak(lastDay: number, streak: number, today: number): number
	if lastDay == today then
		return streak
	end
	if lastDay == today - 1 and streak > 0 then
		return streak + 1
	end
	return 1
end

function Puzzle.Reward(base: number, streak: number, cfg: any): number
	local days = math.min(math.max(streak, 1), cfg.MaxStreakDays)
	return math.floor(base * (1 + (days - 1) * cfg.StreakBonusPerDay) + 0.5)
end

return Puzzle
