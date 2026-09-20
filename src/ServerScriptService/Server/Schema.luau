--!strict
-- Save-data schema: defaults, migration and validation. Pure: no Roblox APIs.
local Schema = {}

Schema.CURRENT_VERSION = 1

function Schema.Default(): { [string]: any }
	return {
		SchemaVersion = Schema.CURRENT_VERSION,
		Shards = 0,
		Upgrades = {}, -- [upgradeId] = level
		UnlockedCharges = { Basic = true },
		Progress = { StrataUnlocked = 1, ActiveStratum = 1 },
		Codex = { Discovered = {}, Mutated = {} }, -- [crystalId] = true
		Stats = { SeamsCleared = 0, BestChain = 0, TotalPops = 0, TotalShards = 0 },
		Settings = { Music = true, Sfx = true },
		Purchases = {}, -- receipt ids, reserved for monetization
	}
end

-- Migration steps: Migrations[n] upgrades data from version n-1 to n.
local Migrations: { [number]: (data: { [string]: any }) -> () } = {}

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
