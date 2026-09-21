--!nonstrict
-- The Farm tab of the menu panel. Split out of UI.luau (no behaviour change): UI.luau builds the row/header helpers and
-- passes them in through `c`; this file only lays out the rows for this tab.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

return function(c)
	local d, titleLabel, row, header, commas = c.d, c.titleLabel, c.row, c.header, c.commas
	local f = d.Farm
	titleLabel.Text = "Crystal Farm"
	if f then
		header(0, ("Level %d / %d: produces %s shards an hour, stores up to %d hours (even while you are away)"):format(f.Level, f.MaxLevel, commas(f.PerHour), f.CapHours))
		local full = f.Pending >= f.PerHour * f.CapHours
		row(1, "Store", full and "The store is full: collect it so it keeps producing!" or "Shards waiting for you.", f.Pending > 0 and ("Collect  ◆ " .. commas(f.Pending)) or "Empty", f.Pending > 0, function()
			Remotes.FarmAction:FireServer("collect")
		end)
		if f.NextCost then
			row(2, ("Upgrade to level %d"):format(f.Level + 1), ("Produces %s shards an hour. Collects the store first."):format(commas(f.NextPerHour)), "Upgrade  ◆ " .. commas(f.NextCost), d.Shards >= f.NextCost, function()
				Remotes.FarmAction:FireServer("upgrade")
			end)
		else
			row(2, "Fully upgraded", "Nothing left to build here.", "Max", false, function() end)
		end
	end
end
