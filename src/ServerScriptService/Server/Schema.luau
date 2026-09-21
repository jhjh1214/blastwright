--!strict
-- Save-data schema: defaults, migration and validation. Pure: no Roblox APIs.
local Schema = {}

Schema.CURRENT_VERSION = 13

function Schema.Default(): { [string]: any }
	return {
		SchemaVersion = Schema.CURRENT_VERSION,
		Shards = 0,
		Upgrades = {}, -- [upgradeId] = level
		UnlockedCharges = { Basic = true },
		Progress = { StrataUnlocked = 1, ActiveStratum = 1 },
		Codex = { Discovered = {}, Mutated = {} }, -- [crystalId] = true
		Stats = { SeamsCleared = 0, BestChain = 0, TotalPops = 0, TotalShards = 0, BestDepth = 0, ExpeditionsWon = 0, LurkersSlain = 0, BossesSlain = 0 },
		Settings = { Music = true, Sfx = true, Shake = true },
		Caches = {}, -- [cacheId] = true for geode caches this player has looted
		Daily = { Day = 0, Progress = {}, Claimed = {} }, -- see Shared/Dailies.luau (string slot keys)
		Weekly = { Day = 0, Progress = {}, Claimed = {} }, -- same shape; Day holds the week number
		Cosmetics = { Owned = {}, Equipped = { BlastColor = "Classic" } }, -- Owned = purchased styles; goal styles are derived
		Achievements = { Claimed = {} }, -- [goalId] = true once the reward was taken (see Shared/Achievements.luau)
		Puzzle = { Day = 0, Score = 0, Par = 0, Medal = "", Streak = 0, LastDay = 0, BestStreak = 0 }, -- see Shared/Puzzle.luau
		Farm = { Level = 1, LastCollect = 0 }, -- see Shared/Farm.luau (LastCollect 0 = stamped with the time on first load)
		Collection = { Lurkers = {}, Bosses = {}, Relics = {} }, -- see Shared/Mastery.luau: kill counts and relics found
		Mastery = { Done = {}, Title = "", Extra = {} }, -- boss mastery objectives done, the title worn, and titles from purchases
		Boosts = { Shards = { Until = 0, Mult = 1 }, Luck = { Until = 0, Mult = 1 } }, -- timed boosts (Shared/Grants.luau)
		Inventory = { Revive = 0, Charge = 0 }, -- consumable tokens
		Finishers = { Owned = {}, Equipped = "Gold" }, -- boss-defeat effects
		Club = { LastMonth = 0 }, -- last UTC month the subscription allotment was claimed
		Purchases = {}, -- receipt ids, reserved for monetization
	}
end

-- Migration steps: Migrations[n] upgrades data from version n-1 to n.
local Migrations: { [number]: (data: { [string]: any }) -> () } = {
	-- v2: exploration world. Adds looted geode caches. (Progress.ActiveStratum is now unused: stratum comes from the site.)
	[2] = function(data)
		if type(data.Caches) ~= "table" then
			data.Caches = {}
		end
	end,
	-- v3: daily objectives. Missing record is filled from defaults by reconcile; nothing to convert.
	[3] = function(data)
		if type(data.Daily) ~= "table" then
			data.Daily = { Day = 0, Progress = {}, Claimed = {} }
		end
	end,
	-- v4: goals. Progress is derived from existing stats; only the claimed set is new.
	[4] = function(data)
		if type(data.Achievements) ~= "table" then
			data.Achievements = { Claimed = {} }
		end
	end,
	-- v5: cosmetics. Ownership of goal styles is derived; only purchases and the equipped choice are stored.
	[5] = function(data)
		if type(data.Cosmetics) ~= "table" then
			data.Cosmetics = { Owned = {}, Equipped = { BlastColor = "Classic" } }
		end
	end,
	-- v6: weekly challenges. Same record shape as Daily; Day holds the week number.
	[6] = function(data)
		if type(data.Weekly) ~= "table" then
			data.Weekly = { Day = 0, Progress = {}, Claimed = {} }
		end
	end,
	-- v7: expeditions. Adds the deepest floor reached and the number of completed dives to Stats (existing stats untouched).
	[7] = function(data)
		if type(data.Stats) == "table" then
			if type(data.Stats.BestDepth) ~= "number" then
				data.Stats.BestDepth = 0
			end
			if type(data.Stats.ExpeditionsWon) ~= "number" then
				data.Stats.ExpeditionsWon = 0
			end
		end
	end,
	-- v8: daily puzzle. Missing record is filled from defaults by reconcile; nothing to convert.
	[8] = function(data)
		if type(data.Puzzle) ~= "table" then
			data.Puzzle = { Day = 0, Score = 0, Par = 0, Medal = "", Streak = 0, LastDay = 0, BestStreak = 0 }
		end
	end,
	-- v9: crystal farm. Missing record is filled from defaults; LastCollect 0 is stamped by the server on load (no backpay).
	[9] = function(data)
		if type(data.Farm) ~= "table" then
			data.Farm = { Level = 1, LastCollect = 0 }
		end
	end,
	-- v10: hidden monsters. Adds the number of Lurkers slain to Stats (existing stats untouched).
	[10] = function(data)
		if type(data.Stats) == "table" and type(data.Stats.LurkersSlain) ~= "number" then
			data.Stats.LurkersSlain = 0
		end
	end,
	-- v11: bosses. Adds the number of bosses defeated to Stats (existing stats untouched).
	[11] = function(data)
		if type(data.Stats) == "table" and type(data.Stats.BossesSlain) ~= "number" then
			data.Stats.BossesSlain = 0
		end
	end,
	-- v12: collection log and boss mastery. Missing records are filled from defaults by reconcile; nothing to convert.
	[12] = function(data)
		if type(data.Collection) ~= "table" then
			data.Collection = { Lurkers = {}, Bosses = {}, Relics = {} }
		end
		if type(data.Mastery) ~= "table" then
			data.Mastery = { Done = {}, Title = "" }
		end
	end,
	-- v13: monetization records (boosts, tokens, finishers, purchased titles, club claim). Filled from defaults by reconcile.
	[13] = function(data)
		if type(data.Mastery) == "table" and type(data.Mastery.Extra) ~= "table" then
			data.Mastery.Extra = {}
		end
	end,
}

-- Fill missing keys from defaults and fix wrong-typed values. Extra keys are kept.
local function reconcile(data: { [string]: any }, default: { [string]: any })
	for key, defVal in default do
		local cur = data[key]
		if type(defVal) == "table" then
			if type(cur) ~= "table" then
				data[key] = Schema.Default()[key] -- fresh copy
			elseif next(defVal) ~= nil then
				reconcile(cur, defVal)
			end
		elseif type(cur) ~= type(defVal) then
			data[key] = defVal
		end
	end
end

local function isFiniteNonNegative(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < math.huge
end

function Schema.Migrate(data: any): { [string]: any }
	if type(data) ~= "table" then
		return Schema.Default()
	end
	local version = type(data.SchemaVersion) == "number" and data.SchemaVersion or 0
	while version < Schema.CURRENT_VERSION do
		version += 1
		local step = Migrations[version]
		if step then
			step(data)
		end
		data.SchemaVersion = version
	end
	reconcile(data, Schema.Default())
	if not isFiniteNonNegative(data.Shards) then
		data.Shards = 0
	end
	data.Shards = math.floor(data.Shards)
	data.UnlockedCharges.Basic = true
	return data
end

return Schema
