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
local Lurker = require(Shared.Lurker)
local Power = require(Shared.Power)
local Boss = require(Shared.Boss)
local BossRT = require(Shared.BossRT)
local Mastery = require(Shared.Mastery)
local Grants = require(Shared.Grants)
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
local LurkerConfig = Config.Lurkers
local BossConfig = Config.Bosses
local PowerConfig = Config.Bosses.Power
local MasteryConfig = Config.Mastery
local FinisherConfig = Config.Finishers
local ClubConfig = Config.Products.Club

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
	Hearts: number, -- rig hearts left (an Expedition keeps them in Run.Hearts)
	HeartsMax: number, -- base hearts plus relic bonuses
	BountyMult: number?, -- room and relic scaling of a Lurker's bounty
	RelicReward: boolean?, -- an Elite room: killing its Lurker grants a relic
	MonsterHPMult: number?,
	BossStats: { Volleys: number, HeartsLost: number }?, -- metrics for boss mastery
	AwaitRevive: boolean?, -- the floor collapsed and the player is choosing whether to spend a Revive
	Revived: boolean?, -- a Revive was offered or used on this floor (only one)
	Hidden: { Kind: string, X: number, Z: number }?, -- a Lurker hiding under a crystal: SECRET, never sent to clients
	Monster: Lurker.Monster?, -- an awake Lurker on the grid
	Defeated: boolean?, -- the rig was knocked out
	Boss: Boss.State?, -- an Expedition boss fight (the floor is the arena)
	BossDefeated: boolean?,
	Critical: number, -- volleys of CRITICAL MASS left
	BossRT: BossRT.State?, -- real-time boss attacks (threats on a clock, shield window)
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
-- The worn title floats above the player's head (visible to everyone: a cosmetic flex, never a stat).
local function applyTitle(player: Player)
	local data = Data.Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local old = head:FindFirstChild("TitleTag")
	if old then
		old:Destroy()
	end
	local title = data.Mastery.Title
	if title == "" then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TitleTag"
	gui.Size = UDim2.fromOffset(200, 26)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 70
	gui.Parent = head
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.TextColor3 = Color3.fromRGB(255, 205, 90)
	text.TextStrokeTransparency = 0.4
	text.Text = title
	text.Parent = gui
end

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
		Hearts = seam and seam.Hearts or 0,
		Boosts = {
			Shards = { Left = Grants.BoostRemaining(data.Boosts, "Shards", os.time()), Mult = Grants.BoostMult(data.Boosts, "Shards", os.time()) },
			Luck = { Left = Grants.BoostRemaining(data.Boosts, "Luck", os.time()), Mult = Grants.BoostMult(data.Boosts, "Luck", os.time()) },
		},
		Inventory = { Revive = data.Inventory.Revive, Charge = data.Inventory.Charge },
		Finishers = (function()
			local color = FinisherConfig.Defs[1].Color
			for _, def in FinisherConfig.Defs do
				if def.Id == data.Finishers.Equipped then
					color = def.Color
				end
			end
			return { Equipped = data.Finishers.Equipped, Owned = data.Finishers.Owned, Color = color }
		end)(),
		Club = (function()
			local active = Purchases.IsClub(player)
			return {
				Configured = ClubConfig.SubscriptionId ~= nil,
				Active = active,
				CanClaim = active and Grants.MonthNumber(os.time()) > data.Club.LastMonth,
				MonthlyShards = ClubConfig.MonthlyShards,
			}
		end)(),
		AwaitRevive = seam ~= nil and seam.AwaitRevive == true,
		Collection = Mastery.CollectionView(data.Collection, LurkerConfig, BossConfig, ExpeditionConfig),
		Mastery = { Objectives = Mastery.View(data.Mastery, MasteryConfig), Titles = Mastery.Titles(data.Mastery, MasteryConfig), Title = data.Mastery.Title },
		Critical = seam and seam.Critical or 0,
		Boss = seam and seam.Boss and (function()
			local view = Boss.View(seam.Boss, BossConfig)
			if seam.BossRT then
				view.RT = BossRT.View(seam.BossRT, os.clock(), BossConfig, seam.Boss.Kind)
				view.DodgeReady = view.RT.DodgeReady
				view.DodgeCooldown = view.RT.DodgeLeft
				view.Telegraph = {} -- (the turn-based marker list is unused: the client draws view.RT.Threats)
			end
			return view
		end)() or nil,
		HeartsMax = seam and seam.HeartsMax or LurkerConfig.Hearts,
		Monster = seam and seam.Monster and (function()
			local m = seam.Monster
			local def = LurkerConfig.Defs[m.Kind]
			return { Kind = m.Kind, Name = def.Name, Description = def.Description, X = m.X, Z = m.Z, HP = m.HP, MaxHP = m.MaxHP, Warn = Lurker.Telegraph(m, LurkerConfig) }
		end)() or nil,
		Tremor = seam ~= nil and seam.Hidden ~= nil and upgradeLevel(data, "Seismograph") > 0, -- Seismograph owners feel that something stirs (not where)
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
		local data = Data.Get(player)
		view.AwaitRevive = seam.AwaitRevive == true
		view.Revives = data and data.Inventory.Revive or 0
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
	local chance = Tuning.MutationChance * (Purchases.Owns(player, "PrismaticLuck") and 2 or 1) * fx.MutationMult * Grants.BoostMult(data.Boosts, "Luck", os.time()) * (run and Expedition.Modifiers(run, ExpeditionConfig).MutationChanceMult or 1)
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
	seam.HeartsMax = LurkerConfig.Hearts + (run and Expedition.HeartsBonus(run, ExpeditionConfig) or 0)
	if run then
		run.Hearts = run.Hearts or seam.HeartsMax
		seam.Hearts = run.Hearts
	else
		seam.Hearts = seam.HeartsMax
	end
	seam.Critical = 0
	local mods = run and Expedition.Modifiers(run, ExpeditionConfig) or nil
	local roomFx = run and Expedition.RoomEffects(run, ExpeditionConfig) or nil
	seam.BountyMult = (roomFx and roomFx.BountyMult or 1) * (mods and mods.BountyMult or 1) * fx.BountyMult
	seam.RelicReward = roomFx ~= nil and roomFx.RelicReward
	seam.MonsterHPMult = (roomFx and roomFx.HPMult or 1) * (mods and mods.MonsterHPMult or 1)
	if run and run.Chaos then
		local event = ExpeditionConfig.ChaosEvents[run.Chaos]
		task.defer(function()
			notify(player, ("CHAOS RIFT: %s! %s"):format(event.Name, event.Description), "Error")
		end)
	end
	local bossKind = run and BossConfig.BossFloors[run.Floor]
	if bossKind then
		seam.Boss = Boss.New(bossKind, grid, { Crystals = Config.Context.Crystals }, BossConfig, runRng)
		seam.BossStats = { Volleys = 0, HeartsLost = 0 }
		seam.BossRT = BossRT.New(os.clock(), bossKind, BossConfig)
		seam.Valuable = Seam.CountValuable(grid, Crystals) -- the core was cleared
		seam.Charges = math.max(seam.Charges, run.StartCharges) -- a boss fight always starts with a full rig
		seam.ChargesMax = math.max(seam.ChargesMax, run.StartCharges)
		task.defer(function()
			notify(player, ("BOSS: %s! %s"):format(BossConfig.Defs[bossKind].Name, BossConfig.Defs[bossKind].Description), "Error")
		end)
	end
	local noLurker = puzzle ~= nil or bossKind ~= nil or (roomFx ~= nil and roomFx.NoLurker)
	if not noLurker and roomFx and roomFx.Awake then
		-- A Lurker Nest, Elite room or Blood Rush: the Lurker is already out, standing where a crystal was.
		local spot = Lurker.Hide(grid, { Crystals = Config.Context.Crystals }, Lurker.PickKind(stratum, runRandom:NextNumber(), LurkerConfig), runRandom:NextNumber())
		if spot then
			grid.Cells[(spot.Z - 1) * grid.Size + spot.X] = nil
			local m = Lurker.New(spot.Kind, spot.X, spot.Z, LurkerConfig)
			m.HP = math.max(1, math.floor(m.HP * (seam.MonsterHPMult or 1) + 0.5))
			m.MaxHP = m.HP
			seam.Monster = m
			seam.Valuable = Seam.CountValuable(grid, Crystals)
			task.defer(function()
				notify(player, ("A %s is awake! %s"):format(LurkerConfig.Defs[m.Kind].Name, LurkerConfig.Defs[m.Kind].Description), "Error")
			end)
		end
	elseif not noLurker and runRandom:NextNumber() < Lurker.SpawnChance(stratum, run and run.Floor or 0, LurkerConfig, data.Stats.LurkersSlain == 0 and data.Stats.TotalPops >= 40) * fx.LurkerMult then
		seam.Hidden = Lurker.Hide(grid, { Crystals = Config.Context.Crystals }, Lurker.PickKind(stratum, runRandom:NextNumber(), LurkerConfig), runRandom:NextNumber())
	end
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

-- The Expedition is over (banked, collapsed or won): the player leaves the pad (no normal seam follows).
local function finishRun(player: Player, seam: SeamState)
	if seam.Run then
		seam.Run.Phase = "Ended"
	end
	seam.Run = nil
	Remotes.RunState:FireClient(player, { Active = false })
	if seams[player] == seam then
		releaseSite(player) -- frees the pad and tells the client to leave blast mode
	end
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
	if seam.BossDefeated then
		fraction = 1
	elseif seam.Defeated or seam.Boss then
		fraction = 0 -- a knocked-out rig, or a boss still standing when the charges run out, collapses the run
	end
	run.Hearts = seam.Hearts
	local chargesLeft = (seam.Defeated or seam.Boss) and 0 or seam.Charges
	if Expedition.WouldCollapse(fraction, chargesLeft, ExpeditionConfig) and not seam.Revived and (data.Inventory.Revive or 0) > 0 and Seam.CountValuable(seam.Grid, Crystals) > 0 then
		-- Offer a Revive instead of collapsing (once per floor). No answer in 25 seconds counts as no.
		seam.AwaitRevive = true
		seam.InFlight = true
		notify(player, ("The tunnel is collapsing! Use a Revive token to keep going? (you have %d)"):format(data.Inventory.Revive), "Error")
		sendRunState(player)
		sync(player)
		task.delay(25, function()
			if seams[player] == seam and seam.AwaitRevive then
				seam.AwaitRevive = nil
				seam.Revived = true
				endFloor(player, seam)
			end
		end)
		return
	end
	local outcome = Expedition.FloorEnded(run, seam.Earned, fraction, chargesLeft, runRng, ExpeditionConfig)
	data.Stats.BestDepth = math.max(data.Stats.BestDepth, run.Floor)
	Leaderboard.Submit("Depth", player.UserId, data.Stats.BestDepth)

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
		notify(player, ("The tunnel collapsed! You salvaged %d shards from floor %d.%s"):format(amount, run.Floor, (data.Inventory.Revive or 0) == 0 and " (Revive tokens in the Shop can save a run.)" or ""), "Error")
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
	if seam.Defeated then
		local fee = math.min(data.Shards, Lurker.RepairFee(seam.Earned, LurkerConfig))
		data.Shards -= fee
		notify(player, ("Your rig was knocked out! Repairs cost %d shards. No clear bonus."):format(fee), "Error")
	elseif fraction >= Tuning.ClearBonusMinFraction then
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

-- After a volley has played out: wake a hidden Lurker whose crystal popped, hurt the awake one, then let it act.
-- Everything is decided here on the server; the client only receives the outcome (MonsterTurn).
local function resolveMonster(player: Player, seam: SeamState, volley: any, result: any, power: number, payout: number)
	local data = Data.Get(player)
	if not data or (not seam.Hidden and not seam.Monster) then
		return
	end
	local mctx = { Crystals = Config.Context.Crystals, Charges = Config.Context.Charges, BlastCells = ChainSim.BlastCells, Size = seam.Grid.Size }
	local turn = { UserId = player.UserId, Eaten = {}, Hearts = seam.Hearts }

	if seam.Hidden and Lurker.Revealed(seam.Hidden, result.Events) then
		-- Its crystal popped: it bursts out and stays put this turn (no free hit on the player).
		seam.Monster = Lurker.New(seam.Hidden.Kind, seam.Hidden.X, seam.Hidden.Z, LurkerConfig)
		seam.Monster.HP = math.max(1, math.floor(seam.Monster.HP * (seam.MonsterHPMult or 1) + 0.5))
		seam.Monster.MaxHP = seam.Monster.HP
		seam.Hidden = nil
		turn.Emerged = true
		notify(player, ("A %s burst out of the rock! %s"):format(LurkerConfig.Defs[seam.Monster.Kind].Name, LurkerConfig.Defs[seam.Monster.Kind].Description), "Error")
	elseif seam.Monster then
		local m = seam.Monster
		local damage = Lurker.Damage(m, volley, result, mctx, LurkerConfig)
		if damage > 0 then
			damage = math.max(1, math.floor(damage * power)) -- better chains hit harder
		end
		turn.Damage = damage
		if not Lurker.Hit(m, damage) then
			local bounty = math.floor(Lurker.Bounty(m.Kind, LurkerConfig) * (seam.BountyMult or 1) + 0.5)
			if seam.Run then
				seam.Earned += bounty -- on an Expedition the bounty joins the haul
			else
				award(data, bounty)
				seam.Earned += bounty
			end
			data.Stats.LurkersSlain += 1
			if Community.Contribute(goal, player.UserId, 5) then -- monsters are a shared threat: kills count toward the Server Goal
				finishGoal()
			end
			goalDirty = true
			Mastery.RecordLurker(data.Collection, m.Kind)
			local slayMods = seam.Run and Expedition.Modifiers(seam.Run, ExpeditionConfig) or nil
			if slayMods and slayMods.KillRefund > 0 then
				seam.Charges = math.min(seam.ChargesMax, seam.Charges + slayMods.KillRefund)
			end
			if seam.Run and seam.RelicReward then
				seam.RelicReward = false
				local run = seam.Run
				run.Hearts = seam.Hearts -- the relic may add a heart or a charge to the RUN; mirror it onto this floor
				local beforeStart = run.StartCharges
				local id = Expedition.GrantRelic(run, runRng, ExpeditionConfig)
				if id then
					Mastery.RecordRelic(data.Collection, id)
					seam.Hearts = run.Hearts or seam.Hearts
					seam.HeartsMax = LurkerConfig.Hearts + Expedition.HeartsBonus(run, ExpeditionConfig)
					local extra = run.StartCharges - beforeStart
					seam.ChargesMax += extra
					seam.Charges += extra
					notify(player, ("ELITE REWARD: %s relic gained: %s. %s"):format(ExpeditionConfig.Relics[id].Family, ExpeditionConfig.Relics[id].Name, ExpeditionConfig.Relics[id].Description), "Reward")
				end
			end
			turn.Slain = { X = m.X, Z = m.Z, Bounty = bounty }
			notify(player, ("%s slain! +%d shards"):format(LurkerConfig.Defs[m.Kind].Name, bounty), "Reward")
			seam.Monster = nil
			announceGoals(player)
		else
			local act = Lurker.Act(m, seam.Grid, mctx, LurkerConfig)
			for _, e in act.Eaten do
				table.insert(turn.Eaten, { X = e.X, Z = e.Z })
			end
			if act.Stolen and act.Stolen > 0 then
				local stolen = math.floor(payout * act.Stolen)
				if stolen > 0 then
					if not seam.Run then
						data.Shards = math.max(0, data.Shards - stolen) -- already paid out: take it back
					end
					seam.Earned = math.max(0, seam.Earned - stolen)
					turn.Stolen = stolen
					notify(player, ("The %s stole %d shards!"):format(LurkerConfig.Defs[m.Kind].Name, stolen), "Error")
				end
			end
			if act.ChargesDrained > 0 then
				seam.Charges = math.max(0, seam.Charges - act.ChargesDrained)
				turn.Drained = act.ChargesDrained
			end
			if act.HeartsLost > 0 then
				seam.Hearts = math.max(0, seam.Hearts - act.HeartsLost)
				turn.HeartsLost = act.HeartsLost
				notify(player, ("The %s smashed your rig! Hearts left: %d"):format(LurkerConfig.Defs[m.Kind].Name, seam.Hearts), "Error")
			end
			if #act.Eaten > 0 then
				notify(player, ("The %s ate %d crystal%s!"):format(LurkerConfig.Defs[m.Kind].Name, #act.Eaten, #act.Eaten > 1 and "s" or ""), "Error")
			end
			if seam.Hearts <= 0 then
				seam.Defeated = true
			end
		end
	end

	turn.Hearts = seam.Hearts
	turn.Monster = seam.Monster and { Kind = seam.Monster.Kind, X = seam.Monster.X, Z = seam.Monster.Z, HP = seam.Monster.HP, MaxHP = seam.Monster.MaxHP, Warn = Lurker.Telegraph(seam.Monster, LurkerConfig) } or nil
	Remotes.MonsterTurn:FireClient(player, turn)
	sync(player)
end

-- After a volley has played out on a boss floor: hurt the boss (phase rules), then let it attack.
local function resolveBoss(player: Player, seam: SeamState, volley: any, result: any, power: number)
	local data = Data.Get(player)
	local boss = seam.Boss
	if not data or not boss then
		return
	end
	local mctx = { Crystals = Config.Context.Crystals, Charges = Config.Context.Charges, BlastCells = ChainSim.BlastCells, Size = seam.Grid.Size }
	local turn = { UserId = player.UserId, Eaten = {}, Hearts = seam.Hearts }
	local out = Boss.Apply(boss, volley, result, mctx, BossConfig, power, seam.Grid, runRng)
	local stats = seam.BossStats or { Volleys = 0, HeartsLost = 0 }
	seam.BossStats = stats
	stats.Volleys += 1
	turn.BossDamage = out.Damage
	if out.NodesBroken > 0 then
		notify(player, ("Armor node broken! %d left."):format(#boss.Nodes), "Reward")
	end
	if out.Killed then
		local def = BossConfig.Defs[boss.Kind]
		local reward = math.floor(def.Bounty * (seam.BountyMult or 1) + 0.5)
		seam.Earned += reward
		seam.BossDefeated = true
		seam.Boss = nil
		data.Stats.BossesSlain += 1
		if Community.Contribute(goal, player.UserId, 40) then -- a boss kill is worth 40 pops toward the Server Goal
			finishGoal()
		end
		goalDirty = true
		Mastery.RecordBoss(data.Collection, boss.Kind)
		Leaderboard.Submit("Bosses", player.UserId, data.Stats.BossesSlain)
		local newly = Mastery.Evaluate(boss.Kind, { HeartsLost = stats.HeartsLost, Volleys = stats.Volleys, FinalPops = result.Pops, HeartsLeft = seam.Hearts }, data.Mastery.Done, MasteryConfig)
		if #newly > 0 then
			award(data, Mastery.Grant(data.Mastery, newly))
			for _, obj in newly do
				notify(player, ("MASTERY: %s! Title unlocked: %s (+%d shards)"):format(obj.Name, obj.Title, obj.Reward), "Reward")
			end
		end
		turn.BossSlain = true
		notify(player, ("%s DEFEATED! +%d shards to the haul"):format(def.Name, reward), "Reward")
		announceGoals(player)
	else
		if out.PhaseChanged then
			seam.Charges = math.min(seam.ChargesMax, seam.Charges + out.Refund)
			turn.PhaseChanged = boss.Phase
			notify(player, ("PHASE: %s (+%d charge)"):format(string.upper(boss.Phase), out.Refund), "Reward")
		end
		-- (its attacks are real-time now: see bossTick and BossRT; a volley only answers them, in onDetonate)
	end
	turn.Hearts = seam.Hearts
	turn.Boss = seam.Boss and Boss.View(seam.Boss, BossConfig) or nil
	if turn.Boss and seam.BossRT then
		turn.Boss.RT = BossRT.View(seam.BossRT, os.clock(), BossConfig, seam.Boss.Kind)
	end
	Remotes.MonsterTurn:FireClient(player, turn)
	sync(player)
end

-- Dodge: a short shield window against the boss's landing attacks (hearts only; crystals still fall). Has a cooldown.
local function onDodge(player: Player)
	local seam = seams[player]
	if not seam or not seam.Boss or not seam.BossRT or seam.AwaitRevive then
		return
	end
	if BossRT.Shield(seam.BossRT, os.clock(), seam.Boss.Kind, BossConfig) then
		notify(player, "Shield up!", "Info")
		sync(player)
	else
		notify(player, "Dodge is recharging.", "Info")
	end
end

-- The boss's clock, several times a second: wind up the next attack when it is due, and land the ones whose time has come.
local function bossTick(player: Player, seam: SeamState)
	local boss = seam.Boss
	if not boss or not seam.BossRT or seam.AwaitRevive or seam.Defeated or seam.BossDefeated then
		return
	end
	local ctx = { Crystals = Config.Context.Crystals }
	local now = os.clock()
	local changed = false
	local threat = BossRT.Spawn(seam.BossRT, boss.Phase, boss.Kind, seam.Grid, ctx, now, runRng, BossConfig)
	if threat then
		changed = true
		local warning = {
			Slam = "SLAM incoming! Pop 3+ crystals on the red line, or Dodge.",
			Meteor = "METEORS incoming! Pop a Lensglass (prism) crystal to deflect them, or Dodge.",
			Corruption = "CORRUPTION! Pop the purple crystals before it lands.",
		}
		notify(player, warning[threat.Type], "Error")
	end
	for _, landed in BossRT.Due(seam.BossRT, now) do
		changed = true
		local r = BossRT.Resolve(landed, seam.Grid, ctx, BossRT.IsShielded(seam.BossRT, now), BossConfig)
		local turn = { UserId = player.UserId, Eaten = r.Destroyed, Corrupted = r.Corrupted, Hearts = seam.Hearts }
		if r.Cancelled then
			turn.Cut = true
		elseif r.Blocked then
			turn.Dodged = true
			notify(player, "Shield! The hit was blocked.", "Reward")
		elseif r.HeartsLost > 0 then
			seam.Hearts = math.max(0, seam.Hearts - r.HeartsLost)
			turn.HeartsLost = r.HeartsLost
			turn.Hearts = seam.Hearts
			if seam.BossStats then
				seam.BossStats.HeartsLost += r.HeartsLost
			end
			notify(player, ("The %s's %s hit your rig! Hearts left: %d"):format(BossConfig.Defs[boss.Kind].Name, string.lower(landed.Type), seam.Hearts), "Error")
			if seam.Hearts <= 0 then
				seam.Defeated = true
			end
		end
		if #r.Corrupted > 0 then
			notify(player, ("%d crystals were corrupted into Dreadgeodes!"):format(#r.Corrupted), "Error")
		end
		turn.Boss = Boss.View(boss, BossConfig)
		turn.Boss.RT = BossRT.View(seam.BossRT, now, BossConfig, boss.Kind)
		Remotes.MonsterTurn:FireClient(player, turn)
	end
	if changed then
		sync(player)
	end
	if seam.Defeated and not seam.InFlight then
		endSeam(player, seam)
	end
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
	if seam.BossRT and seam.Boss then
		-- The volley answers the boss's wound-up attacks: crystals popped on a line cut a slam, prisms deflect meteors, marked
		-- crystals popped are purified.
		local counter = BossRT.Counter(seam.BossRT, result.Events, { Crystals = Config.Context.Crystals }, seam.Boss.Kind, BossConfig)
		if counter.Cut > 0 then
			notify(player, "Slam cut!", "Reward")
		end
		if counter.Deflected > 0 then
			notify(player, ("Prism beam deflected %d meteor zone%s!"):format(counter.Deflected, counter.Deflected > 1 and "s" or ""), "Reward")
		end
		if counter.Purified > 0 then
			notify(player, ("Purified %d crystal%s!"):format(counter.Purified, counter.Purified > 1 and "s" or ""), "Reward")
		end
	end
	local multiplier = (Purchases.Owns(player, "DoubleShards") and 2 or 1) * Events.Combine(activeEvents()).ShardMult * Community.Mult(goal, os.clock(), CommunityConfig) * Grants.BoostMult(data.Boosts, "Shards", os.time())
	local power, powerName = Power.Multiplier(result.Pops, seam.Critical, PowerConfig), select(2, Power.Tier(result.Pops, PowerConfig))
	local relicMods = seam.Run and Expedition.Modifiers(seam.Run, ExpeditionConfig) or nil
	power *= Events.Combine(activeEvents()).DamageMult -- live events (Crystal Storm, Explosive Sunday)
	if relicMods then
		power *= relicMods.DamageMult
		if seam.Hearts == 1 then
			power *= relicMods.LastStandMult
		end
	end
	if seam.Critical > 0 then
		multiplier *= PowerConfig.CriticalPayout
	end
	local criticalLeft, criticalStarted = Power.Advance(seam.Critical, result.Pops, PowerConfig, relicMods and relicMods.CriticalPopsDelta or 0)
	if criticalStarted and relicMods and relicMods.HeartOnCritical > 0 then
		seam.Hearts = math.min(seam.HeartsMax, seam.Hearts + relicMods.HeartOnCritical)
	end
	seam.Critical = criticalLeft
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
	Leaderboard.Submit("Chain", player.UserId, data.Stats.BestChain)
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
		PowerName = powerName,
		Critical = criticalLeft,
		CriticalStarted = criticalStarted,
	})
	sync(player)

	task.delay(result.Duration + 0.3, function()
		if seams[player] ~= seam then
			return
		end
		resolveMonster(player, seam, volley, result, power, payout)
		resolveBoss(player, seam, volley, result, power)
		seam.InFlight = false
		local remaining = Seam.CountValuable(seam.Grid, Crystals)
		if seam.Boss and remaining == 0 then
			seam.Charges = 0 -- nothing left to chain: the fight is lost
		end
		if seam.Defeated or seam.BossDefeated or seam.Charges <= 0 or (remaining == 0 and not seam.Monster and not seam.Boss) then
			endSeam(player, seam)
		else
			sync(player)
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

-- The player answers the Revive offer. Accepting spends a token and restores the rig; declining collapses as normal.
local function onRunRevive(player: Player, accept: any)
	local data = Data.Get(player)
	local seam = seams[player]
	if not data or not seam or not seam.AwaitRevive or not seam.Run then
		return
	end
	seam.AwaitRevive = nil
	if accept == true and Grants.Spend(data, "Revive") then
		seam.Revived = true
		seam.Defeated = nil
		seam.Hearts = math.min(seam.HeartsMax, 2)
		seam.Charges = math.max(seam.Charges, 3)
		seam.ChargesMax = math.max(seam.ChargesMax, seam.Charges)
		seam.InFlight = false
		notify(player, "Revived! Back in the fight.", "Reward")
		sendRunState(player)
		sync(player)
	else
		seam.Revived = true
		endFloor(player, seam)
	end
end

-- One emergency charge from the stock (never in the Daily Puzzle, which has fixed rules).
local function onUseCharge(player: Player)
	local data = Data.Get(player)
	local seam = seams[player]
	if not data or not seam or seam.Puzzle or seam.InFlight or seam.AwaitRevive then
		return
	end
	if Grants.Spend(data, "Charge") then
		seam.Charges += 1
		notify(player, "Emergency charge added.", "Reward")
		sync(player)
	end
end

local function onEquipFinisher(player: Player, id: any)
	local data = Data.Get(player)
	if data and Grants.EquipFinisher(data, id, FinisherConfig) then
		sync(player)
	end
end

-- Club members claim their monthly allotment once per UTC month. The subscription is re-checked with Roblox right now.
local function onClubClaim(player: Player)
	local data = Data.Get(player)
	if not data or not Purchases.RefreshClub(player) then
		return
	end
	local month = Grants.MonthNumber(os.time())
	if month <= data.Club.LastMonth then
		return notify(player, "You already claimed this month's Club allotment.", "Info")
	end
	data.Club.LastMonth = month
	award(data, ClubConfig.MonthlyShards)
	data.Mastery.Extra[ClubConfig.Title] = true
	notify(player, ("Club allotment: +%d shards and the %s title!"):format(ClubConfig.MonthlyShards, ClubConfig.Title), "Reward")
	sync(player)
end

local function onEquipTitle(player: Player, title: any)
	local data = Data.Get(player)
	if not data then
		return
	end
	if Mastery.Equip(data.Mastery, title, MasteryConfig) then
		applyTitle(player)
		sync(player)
	end
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
	local pickedRelic = type(choice) == "number" and run.Choices[choice] and run.Choices[choice].Relic or nil
	if Expedition.Pick(run, choice, ExpeditionConfig, runRng) then
		if pickedRelic then
			Mastery.RecordRelic(data.Collection, pickedRelic)
		end
		local cap = LurkerConfig.Hearts + Expedition.HeartsBonus(run, ExpeditionConfig)
		run.Hearts = math.min(cap, (run.Hearts or cap) + 1) -- a breather between floors
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
		task.spawn(function()
			character:WaitForChild("Head", 5)
			applyTitle(player)
		end)
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
	Leaderboard.Submit("Chain", player.UserId, session.Data.Stats.BestChain)
	Leaderboard.Submit("Depth", player.UserId, session.Data.Stats.BestDepth)
	Leaderboard.Submit("Bosses", player.UserId, session.Data.Stats.BossesSlain)
	Achievements.NewlyComplete(session.Data, AchievementsConfig, seenGoals[player]) -- silent: old completions are not announced
	Purchases.LoadPasses(player)
	task.spawn(Purchases.RefreshClub, player)
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
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, seam in seams do
				if seam.BossRT then
					local ok, err = pcall(bossTick, player, seam)
					if not ok then
						warn("[Game] bossTick failed: " .. tostring(err))
					end
				end
			end
		end
	end)
	Remotes.RunRevive.OnServerEvent:Connect(guarded("RunRevive", 3, 5, onRunRevive))
	Remotes.UseCharge.OnServerEvent:Connect(guarded("UseCharge", 3, 5, onUseCharge))
	Remotes.EquipFinisher.OnServerEvent:Connect(guarded("EquipFinisher", 3, 5, onEquipFinisher))
	Remotes.ClubClaim.OnServerEvent:Connect(guarded("ClubClaim", 1, 2, onClubClaim))
	Remotes.EquipTitle.OnServerEvent:Connect(guarded("EquipTitle", 3, 5, onEquipTitle))
	Remotes.Dodge.OnServerEvent:Connect(guarded("Dodge", 4, 6, onDodge))
	Remotes.FarmAction.OnServerEvent:Connect(guarded("FarmAction", 3, 5, onFarmAction))
	Remotes.PuzzleStart.OnServerEvent:Connect(guarded("PuzzleStart", 2, 3, onPuzzleStart))
	optional("Purchases", function()
		Purchases.Init({ Notify = notify, OnChanged = sync })
	end)
	optional("Leaderboard", function()
		Leaderboard.Init(World.Registry.Boards)
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
