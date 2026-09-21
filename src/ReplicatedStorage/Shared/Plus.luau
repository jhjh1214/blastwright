--!strict
-- Blastwright Plus daily supply drop. Pure (no Roblox APIs). State (save data `Plus`): { LastDay = UTC day number of the last gift }.
local Plus = {}

function Plus.Default()
	return { LastDay = 0 }
end

-- True (and remembers the day) when a gift is due today. Never twice in a day, and a clock that goes backwards pays nothing.
function Plus.ClaimDaily(state: any, day: number): boolean
	if type(day) ~= "number" or day ~= day or day <= state.LastDay then
		return false
	end
	state.LastDay = day
	return true
end

return Plus
