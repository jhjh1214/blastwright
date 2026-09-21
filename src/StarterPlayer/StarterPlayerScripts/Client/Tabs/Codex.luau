--!nonstrict
-- The Codex tab of the menu panel. Split out of UI.luau (no behaviour change): UI.luau builds the row/header helpers and
-- passes them in through `c`; this file only lays out the rows for this tab.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Fx = require(script.Parent.Parent.Fx)
local Remotes = require(Shared.Remotes)
local SpecimensLogic = require(Shared.Specimens)

return function(c)
	local d, titleLabel, row, header, commas, THEME = c.d, c.titleLabel, c.row, c.header, c.commas, c.THEME
	titleLabel.Text = "Codex"
	local found = 0
	for index, id in Config.Crystals.Order do
		local def = Config.Crystals.Defs[id]
		local known = d.Codex.Discovered[id]
		if known then found += 1 end
		local rc = Config.Rarities.Info[def.Rarity].Color
		local mut = d.Codex.Mutated[id] and "   Prismatic found" or ""
		row(index, known and (def.Name .. "  (" .. def.Rarity .. ")" .. mut) or "???", known and def.Description or ("Found in stratum " .. def.Stratum), nil, false, nil, known and Color3.fromRGB(rc[1], rc[2], rc[3]) or THEME.Dim, { Gem = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]), Dim = not known, Accent = Color3.fromRGB(rc[1], rc[2], rc[3]) })
	end
	-- Blast colors: owned styles can be equipped; locked ones say how to get them.
	local order = #Config.Crystals.Order + 1
	-- Specimen Cabinet: every crystal kind in six grades; big chains find better grades.
	if d.Specimens then
		local have = 0
		for _, count in d.Specimens.Found do
			if count > 0 then have += 1 end
		end
		local totalSlots = #Config.Crystals.Order * #Config.Specimens.Rarities
		header(order, ("Specimen Cabinet  %d/%d  (find them by blasting; big chains find rarer grades)"):format(have, totalSlots))
		for _, entry in SpecimensLogic.View({ Found = d.Specimens.Found }, Config.Crystals.Order, Config.Specimens) do
			order += 1
			local def = Config.Crystals.Defs[entry.Kind]
			local parts = {}
			for _, g in entry.Grades do
				table.insert(parts, g.Count > 0 and ("%s x%d"):format(g.Name, g.Count) or "?")
			end
			local c = def and Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]) or THEME.Accent
			row(order, (def and def.Name or entry.Kind) .. ("   %d/%d"):format(entry.Have, entry.Of), table.concat(parts, "  |  "), nil, false, nil, entry.Have >= entry.Of and THEME.Gold or nil, { Gem = c, Accent = c, Progress = entry.Have / entry.Of, Dim = entry.Have == 0 })
		end
		order += 1
	end
	-- Assay Office: pop each crystal kind to reach milestones; claim the rewards here.
	if d.Assay and #d.Assay > 0 then
		header(order, "Assay Office: every crystal kind has its own pop milestones")
		for _, a in d.Assay do
			order += 1
			local def = Config.Crystals.Defs[a.Kind]
			local first = a.Claimable[1]
			local btn, can, onClick
			if first then
				local tier = Config.Assay.Tiers[first]
				btn, can = "Claim  ◆ " .. commas(tier.Reward * math.max(1, d.Progress and d.Progress.StrataUnlocked or 1)), true
				onClick = function() Remotes.AssayClaim:FireServer(a.Kind, first) end
			elseif a.Next then
				btn, can = ("%s / %s"):format(commas(a.Pops), commas(a.Next.Pops)), false
			else
				btn, can = "Grandmaster", false
			end
			local c = def and Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]) or THEME.Accent
			local goal = a.Next and ("Next: %s at %s pops"):format(a.Next.Id, commas(a.Next.Pops)) or "Every milestone reached"
			row(order, (def and def.Name or a.Kind) .. ("  (%s popped)"):format(commas(a.Pops)), goal, btn, can, onClick or function() end, nil, { Gem = c, Accent = c, Progress = a.Next and a.Pops / math.max(1, a.Next.Pops) or 1 })
		end
		order += 1
	end
	header(order, "Blast colors")
	for _, style in d.Styles or {} do
		order += 1
		local c = style.Color
		local btnText = style.Equipped and "Equipped" or (style.Owned and "Equip" or "Locked")
		row(order, style.Name, style.Owned and "Owned" or style.Unlock, btnText, style.Owned and not style.Equipped, function()
			if style.Owned and not style.Equipped then Remotes.Equip:FireServer(style.Id) end
		end, Color3.fromRGB(c[1], c[2], c[3]), { Icon = "●", Accent = Color3.fromRGB(c[1], c[2], c[3]), Dim = not style.Owned })
	end
	-- Monsters, bosses, relics and boss mastery: the long-term "I have not seen everything yet" list.
	local col = d.Collection
	if col then
		order += 1
		header(order, "Lurkers (kills)")
		for _, r in col.Lurkers do
			order += 1
			row(order, r.Found and ("%s  x%d"):format(r.Name, r.Kills) or "???", r.Found and r.Description or "Not met yet", nil, false, nil, r.Found and THEME.Text or THEME.Dim, { Icon = string.sub(r.Name, 1, 1), Accent = Color3.fromRGB(235, 90, 90), Dim = not r.Found })
		end
		order += 1
		header(order, "Bosses")
		for _, r in col.Bosses do
			order += 1
			row(order, r.Found and ("%s  x%d"):format(r.Name, r.Kills) or "???", r.Found and r.Description or "Reach a boss floor of an Expedition (floor 4 or 8)", nil, false, nil, r.Found and THEME.Gold or THEME.Dim, { Icon = "★", Accent = Color3.fromRGB(200, 40, 60), Dim = not r.Found })
		end
		order += 1
		header(order, ("Relics found %d/%d"):format(col.RelicsFound, col.RelicsTotal))
		for _, r in col.Relics do
			order += 1
			row(order, r.Found and ("%s  [%s]"):format(r.Name, r.Family) or "???", r.Found and r.Description or "Find it in an Expedition", nil, false, nil, r.Found and THEME.Text or THEME.Dim, { Icon = "◆", Accent = Fx.Family[r.Family] or THEME.Accent, Dim = not r.Found })
		end
	end
	local fin = d.Finishers
	if fin then
		order += 1
		header(order, "Boss finishers (the look of your FINAL BLAST)")
		for _, def in Config.Finishers.Defs do
			order += 1
			local owned = def.Id == Config.Finishers.DefaultId or fin.Owned[def.Id] == true
			local worn = fin.Equipped == def.Id
			row(order, def.Name, owned and "Owned" or "Sold in the Shop", worn and "Worn" or (owned and "Wear" or "Locked"), owned and not worn, function()
				if owned and not worn then Remotes.EquipFinisher:FireServer(def.Id) end
			end, Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]), { Icon = "✦", Accent = Color3.fromRGB(def.Color[1], def.Color[2], def.Color[3]), Dim = not owned })
		end
	end
	local mastery = d.Mastery
	if mastery then
		order += 1
		header(order, "Boss mastery (each one gives a title to wear)")
		for _, obj in mastery.Objectives do
			order += 1
			local worn = mastery.Title == obj.Title
			local btnText = not obj.Done and "Locked" or (worn and "Worn" or "Wear")
			row(order, obj.Name .. "  [" .. obj.Title .. "]", obj.Description .. ("  Reward: %s"):format(commas(obj.Reward)), btnText, obj.Done and not worn, function()
				if obj.Done and not worn then Remotes.EquipTitle:FireServer(obj.Title) end
			end, obj.Done and THEME.Gold or THEME.Dim, { Icon = obj.Done and "★" or "?", Accent = THEME.Gold, Dim = not obj.Done })
		end
		if mastery.Title ~= "" then
			order += 1
			row(order, "Take off title", "Remove the title above your head.", "Remove", true, function()
				Remotes.EquipTitle:FireServer("")
			end)
		end
	end
	titleLabel.Text = ("Codex  %d/%d"):format(found, #Config.Crystals.Order)
end
