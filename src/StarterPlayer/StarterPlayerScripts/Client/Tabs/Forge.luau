--!nonstrict
-- The Forge tab of the menu panel. Split out of UI.luau (no behaviour change): UI.luau builds the row/header helpers and
-- passes them in through `c`; this file only lays out the rows for this tab.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

return function(c)
	local d, titleLabel, row, header, commas = c.d, c.titleLabel, c.row, c.header, c.commas
	titleLabel.Text = "Forge"
	local order = 0
	header(order, "Rig upgrades")
	for _, id in Config.Upgrades.Order do
		order += 1
		local def = Config.Upgrades.Defs[id]
		local level = d.Upgrades[id] or 0
		local cost = def.Costs[level + 1]
		row(order, ("%s  Lv %d/%d"):format(def.Name, level, #def.Costs), def.Description, cost and ("Buy  ◆ " .. commas(cost)) or "MAX", cost ~= nil and d.Shards >= cost, function()
			Remotes.Buy:FireServer("Upgrade", id)
		end, nil, { Progress = level / math.max(1, #def.Costs), Icon = "▲", Accent = Color3.fromRGB(255, 150, 60) })
	end
	order += 1
	header(order, "Charges")
	for _, id in Config.Charges.Order do
		local def = Config.Charges.Defs[id]
		if def.UnlockCost then
			order += 1
			local owned = d.UnlockedCharges[id]
			row(order, def.Name, def.Description, owned and "Owned" or ("Unlock  ◆ " .. commas(def.UnlockCost)), not owned and d.Shards >= def.UnlockCost, function()
				if not owned then Remotes.Buy:FireServer("Charge", id) end
			end, nil, { Icon = ({ Basic = "o", Shaft = "|", Cross = "+", Shock = "~" })[id] or "*", Accent = ({ Basic = Color3.fromRGB(255, 160, 60), Shaft = Color3.fromRGB(90, 200, 255), Cross = Color3.fromRGB(255, 100, 220), Shock = Color3.fromRGB(120, 230, 190) })[id], Dim = false })
		end
	end
	order += 1
	header(order, "Mine areas (unlock to blast there)")
	for n, s in Config.Strata do
		order += 1
		local unlocked = n <= d.StrataUnlocked
		local can = n == d.StrataUnlocked + 1 and d.Shards >= s.Cost
		row(order, ("%d. %s"):format(n, s.Name), s.Description, unlocked and "Open" or ("Unlock  ◆ " .. commas(s.Cost)), can, function()
			if not unlocked then Remotes.Buy:FireServer("Stratum", tostring(n)) end
		end, nil, { Icon = tostring(n), Accent = ({ Color3.fromRGB(90, 200, 255), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 120, 60), Color3.fromRGB(110, 230, 190) })[n], Dim = not unlocked and not can })
	end
end
