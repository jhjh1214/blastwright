--!nonstrict
-- The Loadout tab of the menu panel. Split out of UI.luau (no behaviour change): UI.luau builds the row/header helpers and
-- passes them in through `c`; this file only lays out the rows for this tab.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AscensionLogic = require(Shared.Ascension)
local ChainSim = require(Shared.ChainSim)
local Config = require(Shared.Config)
local Loadout = require(Shared.Loadout)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.Parent.State)

return function(c)
	local d, titleLabel, row, header, commas, THEME = c.d, c.titleLabel, c.row, c.header, c.commas, c.THEME
	titleLabel.Text = "Loadout"
	local order = 0
	header(order, "Each charge has its own upgrade path: pick ONE fork per branch")
	-- Expedition difficulty: opt-in tiers that add rules and pay a bigger haul. Unlocked by winning at your top tier.
	if d.Ascension then
		local asc = d.Ascension
		order += 1
		header(order, ("Expedition difficulty (Ascension)  -  highest unlocked: %d"):format(asc.Unlocked))
		local tiers = Config.Ascension.Tiers
		for tier = 0, math.min(asc.Unlocked + 1, #tiers) do
			order += 1
			local locked = tier > asc.Unlocked
			local selected = asc.Selected == tier
			local fx = AscensionLogic.Effects(tier, Config.Ascension)
			local title = tier == 0 and "Normal" or ("Ascension %d: %s"):format(tier, tiers[tier].Name)
			local desc
			if locked then
				desc = tier == 1 and "Win an Expedition on Normal to unlock." or ("Win an Expedition at Ascension %d to unlock."):format(tier - 1)
			elseif tier == 0 then
				desc = "The standard Expedition."
			else
				desc = ("%s  Total haul x%.2f."):format(tiers[tier].Description, fx.RewardMult)
			end
			row(order, title, desc, locked and "Locked" or (selected and "Selected" or "Select"), not locked and not selected, function()
				Remotes.AscensionSet:FireServer(tier)
			end, selected and THEME.Gold or nil, { Icon = tostring(tier), Accent = Color3.fromRGB(235, 90, 90), Dim = locked or not selected })
		end
	end
	local state = { Owned = d.Traits or {} }
	local charges = State.Charges()
	for _, branch in Config.Traits.BranchOrder do
		local def = Config.Charges.Defs[branch]
		local unlocked = d.UnlockedCharges[branch] == true
		local eff = charges[branch]
		local cells = #ChainSim.BlastCells(eff.Shape, 5, 5, eff.Radius or 0, eff.Range or 0, 9, eff)
		local direct = eff.DirectMult and eff.DirectMult > 1 and ("   direct hits x%.2f"):format(eff.DirectMult) or ""
		order += 1
		header(order, ("%s   %d cells%s"):format(def.Name, cells, direct))
		local anyOwned = false
		for _ in pairs(state.Owned) do anyOwned = true break end
		local ownedHere = false
		for id, node in Config.Traits.Nodes do
			if node.Branch == branch and state.Owned[id] then ownedHere = true end
		end
		order += 1
		local resetText = ownedHere and ("Reset  ◆ " .. commas(Config.Traits.Respec)) or nil
		row(order, unlocked and def.Role or "Locked: unlock this charge in the Forge", def.Description, resetText, ownedHere and d.Shards >= Config.Traits.Respec, function()
			Remotes.TraitAction:FireServer("respec", branch)
		end, nil, { Icon = ({ Basic = "o", Shaft = "|", Cross = "+", Shock = "~" })[branch] or "*", Accent = ({ Basic = Color3.fromRGB(255, 160, 60), Shaft = Color3.fromRGB(90, 200, 255), Cross = Color3.fromRGB(255, 100, 220), Shock = Color3.fromRGB(120, 230, 190) })[branch], Dim = not unlocked })
		for _, node in Loadout.BranchView(state, branch, Config.Traits, d.UnlockedCharges, d.Shards) do
			order += 1
			local cfgNode = Config.Traits.Nodes[node.Id]
			local btn
			if node.Owned then
				btn = "Owned"
			elseif node.CanBuy then
				btn = "Buy  ◆ " .. commas(node.Cost)
			elseif node.Reason == "Not enough shards." then
				btn = "◆ " .. commas(node.Cost)
			else
				btn = "Locked"
			end
			local tierText = cfgNode.Group and ("Tier %d, fork"):format(node.Tier) or ("Tier %d"):format(node.Tier)
			local desc = node.Description
			if not node.Owned and not node.CanBuy and node.Reason ~= "Not enough shards." then
				desc = desc .. "  (" .. node.Reason .. ")"
			end
			row(order, ("%s  [%s]"):format(node.Name, tierText), desc, btn, node.CanBuy, function()
				Remotes.TraitAction:FireServer("buy", node.Id)
			end, node.Owned and THEME.Gold or nil, { Icon = tostring(node.Tier), Accent = ({ Basic = Color3.fromRGB(255, 160, 60), Shaft = Color3.fromRGB(90, 200, 255), Cross = Color3.fromRGB(255, 100, 220), Shock = Color3.fromRGB(120, 230, 190) })[branch], Dim = not node.Owned and not node.CanBuy })
		end
	end
end
