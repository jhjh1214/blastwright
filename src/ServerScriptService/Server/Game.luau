--!strict
-- Server-authoritative game loop: blast sites, seams, volleys, rewards, caches, purchases, state sync.
-- The client only ever sends intents (Detonate cells, Buy ids, prompt triggers); everything else is decided here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChainSim = require(Shared.ChainSim)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)

local Achievements = require(Shared.Achievements)
local Community = require(Shared.Community)
local Cosmetics = require(Shared.Cosmetics)
local Dailies = require(Shared.Dailies)
local Events = require(Shared.Events)
local Expedition = require(Shared.Expedition)
local Puzzle = require(Shared.Puzzle)
local Farm = require(Shared.Farm)
local Data = require(script.Parent.Data)
local Leaderboard = require(script.Parent.Leaderboard)
local Purchases = require(script.Parent.Purchases)
local RateLimiter = require(script.Parent.RateLimiter)
local Seam = require(script.Parent.Seam)
local Validate = require(script.Parent.Validate)
local World = require(script.Parent.World)

local Tuning = Config.Tuning
local Crystals = Config.Crystals
local Upgrades = Config.Upgrades
local Charges = Config.Charges
local Strata = Config.Strata
local WorldConfig = Config.World
local DailiesConfig = Config.Dailies
local WeekliesConfig = Config.Weeklies
local AchievementsConfig = Config.Achievements
local CosmeticsConfig = Config.Cosmetics
local EventsConfig = Config.Events
local CommunityConfig = Config.Community
local ExpeditionConfig = Config.Expedition
local PuzzleConfig = Config.Puzzle
local FarmConfig = Config.Farm

local BUY_COOLDOWN = 0.2
local DETONATE_COOLDOWN = 0.15
local DETONATE_LEASH = 45 -- max studs between the player and the site's station to blast
local PROMPT_LEASH = 30
local CACHE_LEASH = 25
local IDLE_RELEASE_SECONDS = 60
local IDLE_DISTANCE = 130

type SeamState = {
	Id: number,
	SiteId: number,
	Grid: ChainSim.Grid,
	Stratum: number,
	Charges: number,
	ChargesMax: number,
	Earned: number,
	Popped: number,
	Valuable: number,
	InFlight: boolean,
	Run: Expedition.Run?, -- set while this seam is a floor of an Expedition
	Puzzle: { Day: number, Par: number }?, -- set while this seam is the Daily Puzzle
}

local Game = {}
local seams: { [Player]: SeamState } = {}
local siteOwner: { [number]: Player } = {}
local playerSite: { [Player]: number } = {}
local awaySince: { [Player]: number } = {}
local lastAction: { [Player]: { Buy: number, Detonate: number } } = {}
local seenGoals: { [Player]: { [string]: boolean } } = {}
local seamCounter = 0
local limiter = RateLimiter.new()
local goal = Community.New(1, 1, CommunityConfig) -- the shared Server Goal for this server
local goalDirty = true
local runRandom = Random.new()
local function runRng(): number
	return runRandom:NextNumber()
end

-- Every remote and prompt handler goes through here: a per-player, per-remote token bucket drops floods (an exploiter
-- spamming a remote) before any work is done. Legitimate play stays far below these limits.
local function guarded(name: string, rate: number, burst: number, handler: (Player, ...any) -> ())
	return function(player: Player, ...: any)
		if limiter:Allow(player.UserId, name, os.clock(), rate, burst) then
			handler(player, ...)
		end
	end
end

local cachesById: { [string]: any } = {}
for _, cache in WorldConfig.Caches do
	cachesById[cache.Id] = cache
end

local function upgradeLevel(data: any, id: string): number
	return data.Upgrades[id] or 0
end

-- What the calendar currently changes for everyone (see Config/Events.luau).
local function activeEvents()
	return Events.Active(os.time(), EventsConfig)
end

-- Today's objectives (same for everyone) and this player's record, reset if the UTC day rolled over.
local function todaysDefs()
	return Dailies.ForDay(Dailies.DayNumber(os.time()), DailiesConfig)
end

local function ensureDaily(data: any)
	Dailies.Refresh(data.Daily, Dailies.DayNumber(os.time()))
end

local function weeklyDefs()
	return Dailies.ForDay(Dailies.WeekNumber(os.time()), WeekliesConfig)
end

local function ensureWeekly(data: any)
	Dailies.Refresh(data.Weekly, Dailies.WeekNumber(os.time()))
end

-- Gameplay progress feeds both today's objectives and this week's challenges.
local function recordDaily(data: any, kind: string, amount: number)
	ensureDaily(data)
	Dailies.Record(data.Daily, todaysDefs(), kind, amount)
	ensureWeekly(data)
	Dailies.Record(data.Weekly, weeklyDefs(), kind, amount)
end

local function notify(player: Player, text: string, kind: string)
	Remotes.Notify:FireClient(player, text, kind)
end

-- Tell the player the moment a goal becomes claimable (not for ones that were already done when they joined).
local function announceGoals(player: Player)
	local data = Data.Get(player)
	local seen = seenGoals[player]
	if not data or not seen then
		return
	end
	for _, def in Achievements.NewlyComplete(data, AchievementsConfig, seen) do
		notify(player, ("Goal ready: %s  (Menu > Goals)"):format(def.Name), "Reward")
	end
end

local function isNear(player: Player, position: Vector3, maxDistance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and ((root :: BasePart).Position - position).Magnitude <= maxDistance
end

local function snapshot(player: Player): { [string]: any }?
	local data = Data.Get(player)
	if not data then
		return nil
	end
	local seam = seams[player]
	ensureDaily(data)
	ensureWeekly(data)
	local passes = {}
	for key in Config.Products.Gamepasses do
		passes[key] = Purchases.Owns(player, key)
	end
	return {
		Passes = passes,
		Events = (function()
			local list = {}
			for _, e in activeEvents() do
				table.insert(list, { Name = e.Name, Description = e.Description, EndsIn = e.EndsIn })
			end
			return list
		end)(),
		Goals = Achievements.View(data, AchievementsConfig),
		Styles = Cosmetics.View(data, CosmeticsConfig, AchievementsConfig),
		ActiveStyle = Cosmetics.Active(data, CosmeticsConfig).Id,
		Settings = data.Settings,
		Dailies = Dailies.View(data.Daily, todaysDefs(), data.Progress.StrataUnlocked),
		Weeklies = Dailies.View(data.Weekly, weeklyDefs(), data.Progress.StrataUnlocked),
		WeeklyResetIn = Dailies.SecondsUntilWeekReset(os.time()),
		DailyResetIn = Dailies.SecondsUntilReset(os.time()),
		Shards = data.Shards,
		Upgrades = data.Upgrades,
		UnlockedCharges = data.UnlockedCharges,
		StrataUnlocked = data.Progress.StrataUnlocked,
		Codex = data.Codex,
		Caches = data.Caches,
		BestChain = data.Stats.BestChain,
		Stats = data.Stats,
		ChargesLeft = seam and seam.Charges or 0,
		ChargesMax = seam and seam.ChargesMax or 0,
		Farm = (function()
			local f = data.Farm
			local now = os.time()
			local nextDef = FarmConfig.Levels[f.Level + 1]
			return {
				Level = f.Level,
				MaxLevel = #FarmConfig.Levels,
				PerHour = FarmConfig.Levels[f.Level].PerHour,
				CapHours = FarmConfig.CapHours,
				Pending = Farm.Pending(f, now, FarmConfig),
				NextCost = nextDef and nextDef.Cost or nil,
				NextPerHour = nextDef and nextDef.PerHour or nil,
			}
		end)(),
		Puzzle = (function()
			local today = Dailies.DayNumber(os.time())
			local p = data.Puzzle
			local done = p.Day == today
			return {
				Done = done,
				Medal = done and p.Medal or "",
				Score = done and p.Score or 0,
				Par = done and p.Par or 0,
				Streak = p.LastDay >= today - 1 and p.Streak or 0, -- a missed day already broke it
				BestStreak = p.BestStreak,
				Active = seam ~= nil and seam.Puzzle ~= nil,
			}
		end)(),
	}
end

local function sync(player: Player)
	local snap = snapshot(player)
	if snap then
		Remotes.Sync:FireClient(player, snap)
	end
end

local function seamPayload(player: Player, seam: SeamState): { [string]: any }
	local cells = {}
	for key, cell in seam.Grid.Cells do
		table.insert(cells, { K = key, Kind = cell.Kind, M = cell.Mutated })
	end
	return {
		UserId = player.UserId,
		SiteId = seam.SiteId,
		Size = seam.Grid.Size,
		Stratum = seam.Stratum,
		Cells = cells,
	}
end

-- Server Goal: reward everyone who contributed, start the frenzy, and open the next round a little later.
local function finishGoal()
	for _, userId in Community.Rewardees(goal) do
		local player = Players:GetPlayerByUserId(userId)
		local data = player and Data.Get(player)
		if player and data then
			data.Shards += CommunityConfig.RewardShards
			data.Stats.TotalShards += CommunityConfig.RewardShards
			notify(player, ("Server goal reached! +%d shards, and a server-wide frenzy!"):format(CommunityConfig.RewardShards), "Reward")
			sync(player)
		end
	end
	Community.StartFrenzy(goal, os.clock(), CommunityConfig)
	goalDirty = true
	local finished = goal
	task.delay(CommunityConfig.NewRoundDelay, function()
		if goal ~= finished then
			return
		end
		local nextGoal = Community.New(finished.Round + 1, #Players:GetPlayers(), CommunityConfig)
		nextGoal.FrenzyUntil = finished.FrenzyUntil -- the frenzy outlives the round that earned it
		goal = nextGoal
		goalDirty = true
	end)
end

-- Tell the client about the Expedition it is on (or that it is not on one).
local function sendRunState(player: Player)
	local seam = seams[player]
	if seam and seam.Run then
		local view = Expedition.View(seam.Run, ExpeditionConfig)
		view.Active = true
		Remotes.RunState:FireClient(player, view)
	else
		Remotes.RunState:FireClient(player, { Active = false })
	end
end

-- run = nil starts a normal seam; otherwise the next floor of that Expedition. puzzle = the Daily Puzzle (day + par).
local function startSeam(player: Player, run: Expedition.Run?, puzzle: { Day: number, Par: number }?)
	local data = Data.Get(player)
	local siteId = playerSite[player]
	if not data or not siteId then
		return
	end
	seamCounter += 1
	local stratum = run and Expedition.FloorStratum(run.Floor, data.Progress.StrataUnlocked, ExpeditionConfig) or WorldConfig.Sites[siteId].Stratum
	local fx = Events.Combine(activeEvents())
	local chance = Tuning.MutationChance * (Purchases.Owns(player, "PrismaticLuck") and 2 or 1) * fx.MutationMult * (run and Expedition.Modifiers(run, ExpeditionConfig).MutationChanceMult or 1)
	local grid
	if puzzle then
		stratum = PuzzleConfig.Stratum
		grid = Seam.Generate(Crystals, Tuning, stratum, Puzzle.Seed(puzzle.Day), PuzzleConfig.MutationChance) -- the same for everyone
	else
		grid = Seam.Generate(Crystals, Tuning, stratum, seamCounter * 7919 + player.UserId % 100003 + os.time(), chance)
	end
	local max = Tuning.BaseCharges + upgradeLevel(data, "ExtraCharge") * Upgrades.Defs.ExtraCharge.PerLevel + fx.ChargeBonus
	local seam: SeamState = {
		Id = seamCounter,
		SiteId = siteId,
		Grid = grid,
		Stratum = stratum,
		Charges = puzzle and PuzzleConfig.Charges or run and run.Charges or max,
		ChargesMax = puzzle and PuzzleConfig.Charges or run and run.StartCharges or max,
		Run = run,
		Puzzle = puzzle,
		Earned = 0,
		Popped = 0,
		Valuable = Seam.CountValuable(grid, Crystals),
		InFlight = false,
	}
	seams[player] = seam
	Remotes.SeamStart:FireAllClients(seamPayload(player, seam))
	sendRunState(player)
	sync(player)
end

local function releaseSite(player: Player)
	local siteId = playerSite[player]
	if not siteId then
		return
	end
	siteOwner[siteId] = nil
	playerSite[player] = nil
	seams[player] = nil
	awaySince[player] = nil
	World.SetSiteStatus(siteId, "Free")
	Remotes.SeamRemove:FireAllClients(player.UserId)
end

-- The Daily Puzzle ignores upgrades, relics and events so every player plays by the same rules.
local function puzzleContext()
	return {
		Crystals = Config.Context.Crystals,
		Charges = Config.Context.Charges,
		Tuning = Tuning,
		RadiusBonus = 0,
		MomentumPops = Tuning.MomentumPops,
	}
end

local function contextFor(data: any, run: Expedition.Run?)
	local mods = run and Expedition.Modifiers(run, ExpeditionConfig) or nil
	return {
		Crystals = Config.Context.Crystals,
		Charges = Config.Context.Charges,
		Tuning = Tuning,
		RadiusBonus = upgradeLevel(data, "BlastRadius") * Upgrades.Defs.BlastRadius.PerLevel,
		MomentumPops = math.max(3, Tuning.MomentumPops - upgradeLevel(data, "Momentum") * Upgrades.Defs.Momentum.PerLevel + (mods and mods.MomentumPopsDelta or 0)),
		Modifiers = mods,
	}
end

-- The Expedition is over (banked, collapsed or won): drop back to normal blasting on the same pad after a short pause.
local function finishRun(player: Player, seam: SeamState)
	if seam.Run then
		seam.Run.Phase = "Ended"
	end
	seam.Run = nil
	Remotes.RunState:FireClient(player, { Active = false })
	task.delay(Tuning.SeamRegenDelay, function()
		if seams[player] == seam and player.Parent then
			startSeam(player)
		end
	end)
end

local function award(data: any, amount: number)
	data.Shards += amount
	data.Stats.TotalShards += amount
end

-- The one volley of the Daily Puzzle has played out: score it against par, record it and pay the medal.
local function endPuzzle(player: Player, seam: SeamState, score: number)
	local data = Data.Get(player)
	local puzzle = seam.Puzzle
	if not data or not puzzle or seams[player] ~= seam then
		return
	end
	local p = data.Puzzle
	if p.Day ~= puzzle.Day then -- (the once-a-day check happens at the start; this also guards a double finish)
		local medal = Puzzle.Medal(score, puzzle.Par, PuzzleConfig)
		local streak = Puzzle.Streak(p.LastDay, p.Streak, puzzle.Day)
		data.Puzzle = {
			Day = puzzle.Day,
			Score = score,
			Par = puzzle.Par,
			Medal = medal or "",
			Streak = streak,
			LastDay = puzzle.Day,
			BestStreak = math.max(p.BestStreak, streak),
		}
		if medal then
			local reward = Puzzle.Reward(Puzzle.MedalReward(medal, PuzzleConfig), streak, PuzzleConfig)
			award(data, reward)
			notify(player, ("Daily Puzzle: %d points (par %d). %s medal! +%d shards (day %d streak)"):format(score, puzzle.Par, medal, reward, streak), "Reward")
		else
			notify(player, ("Daily Puzzle: %d points (par %d). No medal today; come back tomorrow!"):format(score, puzzle.Par), "Info")
		end
	end
	seam.Puzzle = nil
	announceGoals(player)
	sync(player)
	task.delay(Tuning.SeamRegenDelay, function()
		if seams[player] == seam and player.Parent then
			startSeam(player)
		end
	end)
end

-- A floor of an Expedition ended (charges spent or grid cleared). The run decides what happens next.
local function endFloor(player: Player, seam: SeamState)
	local data = Data.Get(player)
	local run = seam.Run
	if not data or not run or seams[player] ~= seam then
		return
	end
	local fraction = seam.Valuable > 0 and seam.Popped / seam.Valuable or 1
	local outcome = Expedition.FloorEnded(run, seam.Earned, fraction, seam.Charges, runRng, ExpeditionConfig)
	data.Stats.BestDepth = math.max(data.Stats.BestDepth, run.Floor)

	if outcome == "Choose" then
		notify(player, ("Floor %d cleared! Choose your next step, or bank your haul."):format(run.Floor), "Reward")
		sendRunState(player)
	elseif outcome == "Victory" then
		local amount = Expedition.Bank(run, ExpeditionConfig, true)
		award(data, amount)
		data.Stats.ExpeditionsWon += 1
		notify(player, ("EXPEDITION COMPLETE! +%d shards"):format(amount), "Reward")
		finishRun(player, seam)
	else
		local amount = Expedition.Salvage(run, ExpeditionConfig)
		award(data, amount)
		notify(player, ("The tunnel collapsed! You salvaged %d shards from floor %d."):format(amount, run.Floor), "Error")
		finishRun(player, seam)
	end
	announceGoals(player)
	sync(player)
end

local function endSeam(player: Player, seam: SeamState)
	local data = Data.Get(player)
	if not data or seams[player] ~= seam then
		return
	end
	if seam.Run then
		return endFloor(player, seam)
	end
	local fraction = seam.Valuable > 0 and seam.Popped / seam.Valuable or 1
	if fraction >= Tuning.ClearBonusMinFraction then
		local bonus = math.floor(seam.Earned * Tuning.ClearBonusRate * fraction)
		data.Shards += bonus
		data.Stats.TotalShards += bonus
		data.Stats.SeamsCleared += 1
		recordDaily(data, "Seams", 1)
		announceGoals(player)
		notify(player, ("Seam cleared! +%d bonus shards"):format(bonus), "Reward")
	else
		notify(player, "Seam spent. New seam incoming.", "Info")
	end
	sync(player)
	task.delay(Tuning.SeamRegenDelay, function()
		if seams[player] == seam and player.Parent then
			startSeam(player)
		end
	end)
end

local function onDetonate(player: Player, payload: any)
	local data = Data.Get(player)
	local seam = seams[player]
	if not data or not seam or seam.InFlight then
		return
	end
	if not isNear(player, Geometry.Station(seam.SiteId), DETONATE_LEASH) then
		return -- must be standing at your own site
	end
	local now = os.clock()
	local last = lastAction[player]
	if last and now - last.Detonate < DETONATE_COOLDOWN then
		return
	end
	if last then
		last.Detonate = now
	end

	if seam.Run and seam.Run.Phase ~= "Blasting" then
		return -- choosing a card or finished: no blasting
	end

	local volley, reason = Validate.Volley(payload, seam.Charges, seam.Puzzle and { Basic = true } or data.UnlockedCharges, seam.Grid.Size, seam.Puzzle and PuzzleConfig.Charges or Tuning.MaxVolleyCharges)
	if not volley then
		warn(("[Game] Rejected Detonate from %s: %s"):format(player.Name, tostring(reason)))
		return
	end

	seam.InFlight = true
	seam.Charges -= #volley
	local result = ChainSim.Run(seam.Grid, volley, seam.Puzzle and puzzleContext() or contextFor(data, seam.Run))

	if seam.Puzzle then
		-- Puzzle: one volley, plain score (no multipliers), nothing else in the save changes until it is scored.
		for _, ev in result.Events do
			seam.Grid.Cells[ChainSim.Key(seam.Grid.Size, ev.X, ev.Z)] = nil
		end
		Remotes.VolleyResult:FireAllClients({
			UserId = player.UserId,
			Style = Cosmetics.Active(data, CosmeticsConfig).Id,
			Charges = volley,
			Events = result.Events,
			Pops = result.Pops,
			Raw = result.Raw,
			Bonus = result.Bonus,
			Total = result.Total,
			Multiplier = 1,
			PeakMult = result.PeakMult,
			Tier = result.Tier,
			Duration = result.Duration,
			Momentum = false,
		})
		task.delay(result.Duration + 0.3, function()
			endPuzzle(player, seam, result.Total)
		end)
		return
	end

	local valuablePops = 0
	for _, ev in result.Events do
		seam.Grid.Cells[ChainSim.Key(seam.Grid.Size, ev.X, ev.Z)] = nil
		if Crystals.Defs[ev.Kind].Value > 0 then
			valuablePops += 1
		end
		data.Codex.Discovered[ev.Kind] = true
		if ev.Mutated then
			data.Codex.Mutated[ev.Kind] = true
		end
	end
	local multiplier = (Purchases.Owns(player, "DoubleShards") and 2 or 1) * Events.Combine(activeEvents()).ShardMult * Community.Mult(goal, os.clock(), CommunityConfig)
	local payout = math.floor(result.Total * multiplier + 0.5)
	seam.Popped += valuablePops
	seam.Earned += payout
	if not seam.Run then
		award(data, payout) -- on an Expedition the payout goes into the haul (banked later), not straight to shards
	end
	data.Stats.TotalPops += result.Pops
	recordDaily(data, "Pops", result.Pops)
	recordDaily(data, "Chain", result.Pops)
	recordDaily(data, "Volleys", 1)
	recordDaily(data, "Shards", payout)
	if result.Pops >= DailiesConfig.TierPops then
		recordDaily(data, "Tiers", 1)
	end
	data.Stats.BestChain = math.max(data.Stats.BestChain, result.Pops)
	Leaderboard.Submit(player.UserId, data.Stats.BestChain)
	if Community.Contribute(goal, player.UserId, result.Pops) then
		finishGoal()
	end
	goalDirty = true
	if result.Momentum then
		seam.Charges = math.min(seam.Charges + 1, seam.ChargesMax)
	end

	announceGoals(player)
	Remotes.VolleyResult:FireAllClients({
		UserId = player.UserId,
		Style = Cosmetics.Active(data, CosmeticsConfig).Id,
		Charges = volley,
		Events = result.Events,
		Pops = result.Pops,
		Raw = result.Raw,
		Bonus = result.Bonus,
		Total = payout,
		Multiplier = multiplier,
		PeakMult = result.PeakMult,
		Tier = result.Tier,
		Duration = result.Duration,
		Momentum = result.Momentum,
	})
	sync(player)

	task.delay(result.Duration + 0.3, function()
		if seams[player] ~= seam then
			return
		end
		seam.InFlight = false
		local remaining = Seam.CountValuable(seam.Grid, Crystals)
		if seam.Charges <= 0 or remaining == 0 then
			endSeam(player, seam)
		end
	end)
end

local function onBuy(player: Player, kind: any, id: any)
	local data = Data.Get(player)
	if not data or type(kind) ~= "string" or type(id) ~= "string" then
		return
	end
	local now = os.clock()
	local last = lastAction[player]
	if last and now - last.Buy < BUY_COOLDOWN then
		return
	end
	if last then
		last.Buy = now
	end

	if kind == "Upgrade" then
		local def = Upgrades.Defs[id]
		if not def then
			return
		end
		local level = upgradeLevel(data, id)
		local cost = def.Costs[level + 1]
		if not cost then
			return notify(player, "Already maxed.", "Info")
		end
		if data.Shards < cost then
			return notify(player, "Not enough shards.", "Error")
		end
		data.Shards -= cost
		data.Upgrades[id] = level + 1
		notify(player, def.Name .. " upgraded" .. (id == "ExtraCharge" and " (next seam)" or ""), "Reward")
	elseif kind == "Charge" then
		local def = Charges.Defs[id]
		if not def or def.UnlockCost == nil or data.UnlockedCharges[id] then
			return
		end
		if data.Shards < def.UnlockCost then
			return notify(player, "Not enough shards.", "Error")
		end
		data.Shards -= def.UnlockCost
		data.UnlockedCharges[id] = true
		notify(player, def.Name .. " unlocked!", "Reward")
	elseif kind == "Stratum" then
		local n = tonumber(id)
		if not n or n % 1 ~= 0 or Strata[n] == nil or n ~= data.Progress.StrataUnlocked + 1 then
			return
		end
		local cost = Strata[n].Cost
		if data.Shards < cost then
			return notify(player, "Not enough shards.", "Error")
		end
		data.Shards -= cost
		data.Progress.StrataUnlocked = n
		notify(player, Strata[n].Name .. " unlocked! Blast sites there are open.", "Reward")
	else
		return
	end
	announceGoals(player)
	sync(player)
end

-- Crystal Farm: "collect" takes the store; "upgrade" buys the next level (which collects first, at the old rate).
local function onFarmAction(player: Player, action: any)
	local data = Data.Get(player)
	if not data or (action ~= "collect" and action ~= "upgrade" and action ~= "refresh") then
		return
	end
	local now = os.time()
	if action == "refresh" then
		return sync(player) -- the store fills with time, so opening the tab asks for a fresh number
	elseif action == "collect" then
		local amount = Farm.Collect(data.Farm, now, FarmConfig)
		if amount > 0 then
			award(data, amount)
			notify(player, ("Collected %d shards from the Crystal Farm."):format(amount), "Reward")
		else
			notify(player, "The farm store is empty. Check back later!", "Info")
		end
	else
		local nextDef = FarmConfig.Levels[data.Farm.Level + 1]
		local ok, paid = Farm.Upgrade(data.Farm, now, data.Shards, FarmConfig)
		if not ok then
			notify(player, paid == "max" and "The farm is fully upgraded." or "Not enough shards.", paid == "max" and "Info" or "Error")
			return
		end
		data.Shards -= nextDef.Cost
		award(data, paid)
		notify(player, ("Crystal Farm upgraded to level %d!%s"):format(data.Farm.Level, paid > 0 and (" (collected %d first)"):format(paid) or ""), "Reward")
	end
	announceGoals(player)
	sync(player)
end

local function onSetting(player: Player, name: any, value: any)
	local data = Data.Get(player)
	local key, enabled = Validate.Setting(name, value)
	if not data or not key then
		return
	end
	data.Settings[key] = enabled
	sync(player)
end

local function onEquip(player: Player, id: any)
	local data = Data.Get(player)
	if not data then
		return
	end
	if not Cosmetics.CanEquip(data, CosmeticsConfig, id) then
		return notify(player, "You have not unlocked that style yet.", "Error")
	end
	data.Cosmetics.Equipped.BlastColor = id
	sync(player)
end

local function onClaimGoal(player: Player, id: any)
	local data = Data.Get(player)
	if not data then
		return
	end
	local now = os.clock()
	local last = lastAction[player]
	if last and now - last.Buy < BUY_COOLDOWN then
		return
	end
	if last then
		last.Buy = now
	end

	if not Achievements.CanClaim(data, AchievementsConfig, id) then
		return notify(player, "That goal is not complete yet.", "Error")
	end
	local def = Achievements.Find(AchievementsConfig, id)
	data.Achievements.Claimed[def.Id] = true
	data.Shards += def.Reward
	notify(player, ("Goal complete: %s! +%d shards"):format(def.Name, def.Reward), "Reward")
	sync(player)
end

local function onClaimWeekly(player: Player, slot: any)
	local data = Data.Get(player)
	if not data then
		return
	end
	local now = os.clock()
	local last = lastAction[player]
	if last and now - last.Buy < BUY_COOLDOWN then
		return
	end
	if last then
		last.Buy = now
	end

	ensureWeekly(data)
	local defs = weeklyDefs()
	if not Dailies.CanClaim(data.Weekly, defs, slot) then
		return notify(player, "Nothing to claim there yet.", "Error")
	end
	local reward = Dailies.Reward(defs[slot], data.Progress.StrataUnlocked)
	data.Weekly.Claimed[tostring(slot)] = true
	data.Shards += reward
	notify(player, ("Weekly challenge complete! +%d shards"):format(reward), "Reward")
	sync(player)
end

local function onClaim(player: Player, slot: any)
	local data = Data.Get(player)
	if not data then
		return
	end
	local now = os.clock()
	local last = lastAction[player]
	if last and now - last.Buy < BUY_COOLDOWN then
		return
	end
	if last then
		last.Buy = now
	end

	ensureDaily(data)
	local defs = todaysDefs()
	if not Dailies.CanClaim(data.Daily, defs, slot) then
		return notify(player, "Nothing to claim there yet.", "Error")
	end
	local reward = Dailies.Reward(defs[slot], data.Progress.StrataUnlocked)
	data.Daily.Claimed[tostring(slot)] = true
	data.Shards += reward
	notify(player, ("Daily complete! +%d shards"):format(reward), "Reward")
	sync(player)
end

-- A player used a site's blast station.
local function onSiteTriggered(player: Player, siteId: number)
	local data = Data.Get(player)
	local site = WorldConfig.Sites[siteId]
	if not data or not site then
		return
	end
	if not isNear(player, Geometry.Station(siteId), PROMPT_LEASH) then
		return
	end
	if data.Progress.StrataUnlocked < site.Stratum then
		local s = Strata[site.Stratum]
		return notify(player, ("%s is locked. Unlock it in the Forge (%d shards)."):format(s.Name, s.Cost), "Error")
	end
	local owner = siteOwner[siteId]
	if owner and owner ~= player then
		return notify(player, "Someone else is using this site. Try another pad.", "Error")
	end

	local current = seams[player]
	if current and current.Run and playerSite[player] ~= siteId then
		return notify(player, "Finish or bank your expedition first.", "Error")
	end

	if playerSite[player] ~= siteId then
		releaseSite(player)
		siteOwner[siteId] = player
		playerSite[player] = siteId
		World.SetSiteStatus(siteId, "In use: " .. player.DisplayName)
		startSeam(player)
	end
	Remotes.Engage:FireClient(player, siteId)
end

-- A player chose "Begin Expedition" at a pad station.
local function onExpeditionTriggered(player: Player, siteId: number)
	local data = Data.Get(player)
	local site = WorldConfig.Sites[siteId]
	if not data or not site then
		return
	end
	if not isNear(player, Geometry.Station(siteId), PROMPT_LEASH) then
		return
	end
	if data.Progress.StrataUnlocked < site.Stratum then
		local s = Strata[site.Stratum]
		return notify(player, ("%s is locked. Unlock it in the Forge (%d shards)."):format(s.Name, s.Cost), "Error")
	end
	local owner = siteOwner[siteId]
	if owner and owner ~= player then
		return notify(player, "Someone else is using this site. Try another pad.", "Error")
	end

	local current = seams[player]
	if current and current.Run then
		if playerSite[player] == siteId then
			return Remotes.Engage:FireClient(player, siteId) -- already on an expedition here: just return to it
		end
		return notify(player, "Finish or bank your expedition first.", "Error")
	end

	if playerSite[player] ~= siteId then
		releaseSite(player)
		siteOwner[siteId] = player
		playerSite[player] = siteId
	end
	World.SetSiteStatus(siteId, "Expedition: " .. player.DisplayName)
	local fx = Events.Combine(activeEvents())
	local charges = Tuning.BaseCharges + upgradeLevel(data, "ExtraCharge") * Upgrades.Defs.ExtraCharge.PerLevel + fx.ChargeBonus
	startSeam(player, Expedition.New(ExpeditionConfig, charges))
	Remotes.Engage:FireClient(player, siteId)
end

-- The player's choice between floors: a card number, or "bank" to take the haul and leave.
local function onRunPick(player: Player, choice: any)
	local data = Data.Get(player)
	local seam = seams[player]
	local run = seam and seam.Run
	if not data or not seam or not run or seam.InFlight or run.Phase ~= "Choosing" then
		return
	end
	if choice == "bank" then
		local amount = Expedition.Bank(run, ExpeditionConfig, false)
		award(data, amount)
		notify(player, ("Banked %d shards from floor %d."):format(amount, run.Floor), "Reward")
		announceGoals(player)
		finishRun(player, seam)
		sync(player)
		return
	end
	if Expedition.Pick(run, choice, ExpeditionConfig) then
		startSeam(player, run) -- descend: generates the next floor and tells everyone
	end
end

-- "Play today's puzzle" (Menu > Daily): uses the pad the player is standing at, or the nearest free unlocked one.
local puzzleParCache: { [number]: number } = {}

local function onPuzzleStart(player: Player)
	local data = Data.Get(player)
	if not data then
		return
	end
	local today = Dailies.DayNumber(os.time())
	if data.Puzzle.Day == today then
		return notify(player, "You already played today's puzzle. A new one arrives in " .. ("%dh %02dm"):format(Dailies.SecondsUntilReset(os.time()) // 3600, Dailies.SecondsUntilReset(os.time()) % 3600 // 60) .. ".", "Info")
	end
	local current = seams[player]
	if current and current.Run then
		return notify(player, "Finish or bank your expedition first.", "Error")
	end

	local siteId, bestDist = nil, PROMPT_LEASH
	for id, site in WorldConfig.Sites do
		local owner = siteOwner[id]
		if data.Progress.StrataUnlocked >= site.Stratum and (owner == nil or owner == player) then
			local station = Geometry.Station(id)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local dist = (root.Position - station).Magnitude
				if dist <= bestDist then
					siteId, bestDist = id, dist
				end
			end
		end
	end
	if not siteId then
		return notify(player, "Walk up to a free blast pad first, then start the puzzle from the Menu.", "Error")
	end

	if playerSite[player] ~= siteId then
		releaseSite(player)
		siteOwner[siteId] = player
		playerSite[player] = siteId
	end
	World.SetSiteStatus(siteId, "Puzzle: " .. player.DisplayName)
	local par = puzzleParCache[today]
	if not par then
		local grid = Seam.Generate(Crystals, Tuning, PuzzleConfig.Stratum, Puzzle.Seed(today), PuzzleConfig.MutationChance)
		par = Puzzle.Par(grid, puzzleContext(), PuzzleConfig.Charges, ChainSim.Run)
		puzzleParCache[today] = par
	end
	startSeam(player, nil, { Day = today, Par = par })
	Remotes.Engage:FireClient(player, siteId)
end

local function onCacheTriggered(player: Player, cacheId: string)
	local data = Data.Get(player)
	local cache = cachesById[cacheId]
	if not data or not cache then
		return
	end
	if not isNear(player, Vector3.new(cache.X, 0, cache.Z), CACHE_LEASH) then
		return
	end
	if data.Caches[cacheId] then
		return notify(player, "You already looted this cache.", "Info")
	end
	data.Caches[cacheId] = true
	data.Shards += cache.Reward
	data.Stats.TotalShards += cache.Reward

	local found = 0
	for _ in data.Caches do
		found += 1
	end
	notify(player, ("Geode cache! +%d shards (%d/%d found)"):format(cache.Reward, found, #WorldConfig.Caches), "Reward")
	announceGoals(player)
	sync(player)
end

local function respawn(player: Player)
	if player.Parent then
		player:LoadCharacter()
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			(humanoid :: Humanoid).Died:Connect(function()
				task.delay(Players.RespawnTime, respawn, player)
			end)
		end
	end)

	local session = Data.Load(player)
	if not session then
		player:Kick("Your data could not be loaded safely. Please rejoin in a minute.")
		return
	end
	if player.Parent == nil then
		Data.Release(player) -- left mid-load: free the session lock
		return
	end

	lastAction[player] = { Buy = 0, Detonate = 0 }
	if session.Data.Farm.LastCollect == 0 then
		session.Data.Farm.LastCollect = os.time() -- a new farm starts producing now (no backpay for old saves)
	end
	seenGoals[player] = {}
	Leaderboard.Submit(player.UserId, session.Data.Stats.BestChain)
	Achievements.NewlyComplete(session.Data, AchievementsConfig, seenGoals[player]) -- silent: old completions are not announced
	Purchases.LoadPasses(player)
	player:LoadCharacter()
	sync(player)
	Remotes.Community:FireClient(player, Community.View(goal, os.clock(), CommunityConfig))

	-- Show caverns that are already active.
	for other, seam in seams do
		if other ~= player then
			Remotes.SeamStart:FireClient(player, seamPayload(other, seam))
		end
	end
end

local function onPlayerRemoving(player: Player)
	releaseSite(player)
	limiter:Forget(player.UserId)
	Leaderboard.Flush(player.UserId)
	Purchases.Forget(player)
	seenGoals[player] = nil
	lastAction[player] = nil
end

-- Free sites whose owner wandered off, so pads never stay reserved by idle players.
local function idleLoop()
	while true do
		task.wait(5)
		for player, siteId in playerSite do
			local seam = seams[player]
			if seam and not seam.InFlight and not isNear(player, Geometry.Station(siteId), IDLE_DISTANCE) then
				local since = awaySince[player]
				if not since then
					awaySince[player] = os.clock()
				elseif os.clock() - since > IDLE_RELEASE_SECONDS then
					releaseSite(player)
					notify(player, "Your blast site was released while you were away.", "Info")
				end
			else
				awaySince[player] = nil
			end
		end
	end
end

-- Optional systems must never be able to stop the core game from starting: a failure warns and the rest carries on.
local function optional(name: string, start: () -> ())
	local ok, err = pcall(start)
	if not ok then
		warn(("[Game] optional system '%s' failed to start: %s"):format(name, tostring(err)))
	end
end

function Game.Init()
	Remotes.Detonate.OnServerEvent:Connect(guarded("Detonate", 6, 10, onDetonate))
	Remotes.Buy.OnServerEvent:Connect(guarded("Buy", 5, 8, onBuy))
	Remotes.Claim.OnServerEvent:Connect(guarded("Claim", 5, 8, onClaim))
	Remotes.ClaimWeekly.OnServerEvent:Connect(guarded("ClaimWeekly", 5, 8, onClaimWeekly))
	Remotes.ClaimGoal.OnServerEvent:Connect(guarded("ClaimGoal", 5, 8, onClaimGoal))
	Remotes.Equip.OnServerEvent:Connect(guarded("Equip", 5, 8, onEquip))
	Remotes.Setting.OnServerEvent:Connect(guarded("Setting", 5, 8, onSetting))
	Remotes.RunPick.OnServerEvent:Connect(guarded("RunPick", 5, 8, onRunPick))
	Remotes.FarmAction.OnServerEvent:Connect(guarded("FarmAction", 3, 5, onFarmAction))
	Remotes.PuzzleStart.OnServerEvent:Connect(guarded("PuzzleStart", 2, 3, onPuzzleStart))
	optional("Purchases", function()
		Purchases.Init({ Notify = notify, OnChanged = sync })
	end)
	optional("Leaderboard", function()
		Leaderboard.Init(World.Registry.Board)
	end)

	for siteId, entry in World.Registry.Sites do
		entry.Prompt.Triggered:Connect(guarded("Site", 3, 5, function(player)
			onSiteTriggered(player, siteId)
		end))
		entry.ExpeditionPrompt.Triggered:Connect(guarded("Expedition", 3, 5, function(player)
			onExpeditionTriggered(player, siteId)
		end))
	end
	for cacheId, entry in World.Registry.Caches do
		entry.Prompt.Triggered:Connect(guarded("Cache", 3, 5, function(player)
			onCacheTriggered(player, cacheId)
		end))
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(idleLoop)
	-- Broadcast the shared goal when it changed (at most every 2 seconds), and at least every 10 so timers stay honest.
	task.spawn(function()
		local ticks = 0
		while true do
			task.wait(2)
			ticks += 1
			if goalDirty or ticks % 5 == 0 then
				goalDirty = false
				Remotes.Community:FireAllClients(Community.View(goal, os.clock(), CommunityConfig))
			end
		end
	end)
end

return Game
