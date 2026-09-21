--!nonstrict
-- The Daily tab of the menu panel. Split out of UI.luau (no behaviour change): UI.luau builds the row/header helpers and
-- passes them in through `c`; this file only lays out the rows for this tab.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grants = require(Shared.Grants)
local Remotes = require(Shared.Remotes)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)

return function(c)
	local d, titleLabel, row, header, commas, THEME = c.d, c.titleLabel, c.row, c.header, c.commas, c.THEME
	titleLabel.Text = "Daily objectives"
	local secs = math.max(0, math.floor((State.DailyResetAt or 0) - os.clock()))
	-- Free daily reward: claim once a day; consecutive days build a 7-day streak.
	if d.Streak then
		local sv = d.Streak
		local dayNo = sv.CycleDay > 0 and sv.CycleDay or 1
		header(-10, ("Daily reward  -  streak %d day%s"):format(sv.Count, sv.Count == 1 and "" or "s"))
		row(-9, ("Day %d of 7"):format(dayNo), Grants.Describe(Config.Streak.Days[dayNo]) .. (sv.CanClaim and "" or "   (tomorrow: " .. Grants.Describe(Config.Streak.Days[dayNo % 7 + 1]) .. ")"), sv.CanClaim and "Claim FREE" or "Claimed", sv.CanClaim, function()
			Remotes.StreakClaim:FireServer()
		end, nil, { Icon = "★", Accent = Color3.fromRGB(110, 230, 150), Dim = not sv.CanClaim, Progress = dayNo / 7 })
	end
	header(0, ("Resets in %dh %02dm (unclaimed rewards are lost)"):format(secs // 3600, (secs % 3600) // 60))
	for _, item in d.Dailies or {} do
		local done = item.Progress >= item.Target
		local btnText = item.Claimed and "Claimed" or (done and ("Claim  ◆ " .. commas(item.Reward)) or ("%d / %d"):format(item.Progress, item.Target))
		row(item.Slot, item.Text, ("Reward: ◆ %s"):format(commas(item.Reward)), btnText, done and not item.Claimed, function()
			if done and not item.Claimed then Remotes.Claim:FireServer(item.Slot) end
		end, nil, { Progress = item.Progress / math.max(1, item.Target), Icon = "★", Accent = item.Claimed and THEME.Dim or nil, Dim = item.Claimed })
	end
	-- Daily Puzzle: same grid for everyone, one try, medal by score against par.
	local pz = d.Puzzle
	if pz then
		header(20, ("Daily Puzzle  (streak %d, best %d)"):format(pz.Streak, pz.BestStreak))
		local medals = {}
		for _, m in Config.Puzzle.Medals do
			table.insert(medals, ("%s %d%%: %s"):format(m.Name, m.Ratio * 100, commas(m.Reward)))
		end
		local desc = "Stand at a blast pad. 3 Basic charges, one volley, everyone gets the same grid. Score vs par: " .. table.concat(medals, ", ") .. ". Streak adds +10% a day."
		local btn, canPlay = "Play", true
		if pz.Done then
			btn = (pz.Medal ~= "" and pz.Medal or "No medal") .. (" (%s / par %s)"):format(commas(pz.Score), commas(pz.Par))
			canPlay = false
		end
		row(21, "Today's puzzle", desc, btn, canPlay, function()
			if canPlay then Remotes.PuzzleStart:FireServer() end
		end, nil, { Icon = "P", Accent = Color3.fromRGB(255, 200, 60), Dim = not canPlay })
	end
	-- Notice Board: pick ONE contract at a time from three daily offers (Easy / Standard / Hard).
	if d.Contracts and #d.Contracts > 0 then
		local anyActive = false
		for _, c in d.Contracts do
			anyActive = anyActive or c.Active
		end
		header(30, anyActive and "Notice Board: finish your contract or give it up to take another" or "Notice Board: pick one contract (progress counts after you accept)")
		local tierIcons = { "E", "S", "H" }
		local tierColors = { Theme.Colors.Success, Theme.Colors.Warning, Theme.Colors.Danger }
		for _, c in d.Contracts do
			local rewards = Config.Contracts.Rewards[c.Tier] or {}
			local parts = {}
			for _, g in rewards do
				if g.Kind == "Shards" then
					table.insert(parts, "◆ " .. commas(g.Amount * math.max(1, d.Progress and d.Progress.StrataUnlocked or 1)))
				elseif g.Kind == "Tokens" then
					table.insert(parts, ("%d %s token%s"):format(g.Count, string.lower(g.Token), g.Count > 1 and "s" or ""))
				end
			end
			local done = c.Progress >= c.Target
			local btn, can, onClick
			if c.Done then
				btn, can = "Done", false
			elseif c.Active then
				if done then
					btn, can, onClick = "Claim", true, function() Remotes.ContractClaim:FireServer() end
				else
					btn, can = ("%d / %d"):format(c.Progress, c.Target), false
				end
			else
				btn, can = "Accept", not anyActive
				onClick = function() Remotes.ContractAccept:FireServer(c.Tier) end
			end
			row(30 + c.Tier, ("%s: %s"):format(c.TierName, c.Text), "Reward: " .. table.concat(parts, " + "), btn, can, onClick or function() end, nil, { Progress = c.Active and c.Progress / math.max(1, c.Target) or (c.Done and 1 or nil), Icon = tierIcons[c.Tier], Accent = tierColors[c.Tier], Dim = c.Done })
		end
		if anyActive then
			row(34, "Give up the current contract", "Its progress is lost, but you can take it (or another) again today.", "Give up", true, function() Remotes.ContractAccept:FireServer("abandon") end, nil, { Icon = "X", Accent = Theme.Colors.Neutral })
		end
	end
	-- Weekly challenges: bigger targets and rewards, reset Monday 00:00 UTC.
	local weekSecs = math.max(0, math.floor((State.WeeklyResetAt or 0) - os.clock()))
	header(10, ("Weekly challenges: reset in %dd %02dh (unclaimed rewards are lost)"):format(weekSecs // 86400, (weekSecs % 86400) // 3600))
	for _, item in d.Weeklies or {} do
		local done = item.Progress >= item.Target
		local btnText = item.Claimed and "Claimed" or (done and ("Claim  ◆ " .. commas(item.Reward)) or ("%s / %s"):format(commas(item.Progress), commas(item.Target)))
		row(10 + item.Slot, item.Text, ("Reward: ◆ %s"):format(commas(item.Reward)), btnText, done and not item.Claimed, function()
			if done and not item.Claimed then Remotes.ClaimWeekly:FireServer(item.Slot) end
		end, nil, { Progress = item.Progress / math.max(1, item.Target), Icon = "W", Accent = Color3.fromRGB(190, 120, 255), Dim = item.Claimed })
	end
end
