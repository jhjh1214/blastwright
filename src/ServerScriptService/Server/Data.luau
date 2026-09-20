--!strict
-- Persistence: DataStore with a job-id session lock, retries, autosave and shutdown save.
-- In Studio without API access it falls back to a volatile in-memory profile (never saved).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Schema = require(script.Parent.Schema)

local STORE_NAME = "PlayerData_v1"
local LOCK_STALE_SECONDS = 300 -- a lock older than this is treated as a crashed server
local AUTOSAVE_SECONDS = 60
local LOAD_ATTEMPTS = 6
local SAVE_ATTEMPTS = 4

local JOB_ID = game.JobId ~= "" and game.JobId or "studio"

export type Session = {
	Data: { [string]: any },
	Volatile: boolean, -- true = not persisted (no DataStore access)
	Released: boolean,
}

local DataService = {}
local sessions: { [Player]: Session } = {}
local store = DataStoreService:GetDataStore(STORE_NAME)

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

-- Returns a session, or nil if the data could not be loaded safely (caller should kick).
function DataService.Load(player: Player): Session?
	local key = keyFor(player)

	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(old)
				lockedElsewhere = false
				local now = os.time()
				if
					old
					and old.Meta
					and old.Meta.LockJobId
					and old.Meta.LockJobId ~= JOB_ID
					and now - (old.Meta.LockTime or 0) < LOCK_STALE_SECONDS
				then
					lockedElsewhere = true
					return nil -- cancel: another live server owns this profile
				end
				return {
					Meta = { LockJobId = JOB_ID, LockTime = now },
					Data = old and old.Data or Schema.Default(),
				}
			end)
		end)

		if ok and not lockedElsewhere and result then
			local session: Session = { Data = Schema.Migrate(result.Data), Volatile = false, Released = false }
			sessions[player] = session
			return session
		end

		if not ok and RunService:IsStudio() then
			warn(("[Data] DataStore unavailable in Studio (%s). Using volatile profile; progress will NOT be saved."):format(tostring(result)))
			local session: Session = { Data = Schema.Default(), Volatile = true, Released = false }
			sessions[player] = session
			return session
		end

		warn(("[Data] Load attempt %d/%d for %s failed (%s)"):format(attempt, LOAD_ATTEMPTS, player.Name, lockedElsewhere and "locked" or tostring(result)))
		task.wait(math.min(2 * attempt, 8))
	end
	return nil
end

function DataService.Get(player: Player): { [string]: any }?
	local session = sessions[player]
	return session and session.Data or nil
end

-- releasing = true also clears the session lock.
function DataService.Save(player: Player, releasing: boolean): boolean
	local session = sessions[player]
	if not session or session.Volatile or session.Released then
		return true
	end
	if releasing then
		session.Released = true
	end

	local key = keyFor(player)
	for attempt = 1, SAVE_ATTEMPTS do
		local ownedByUs = true
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				ownedByUs = true
				if old and old.Meta and old.Meta.LockJobId and old.Meta.LockJobId ~= JOB_ID then
					ownedByUs = false
					return nil -- lost the lock; never overwrite the other server's data
				end
				return {
					Meta = { LockJobId = (not releasing) and JOB_ID or nil, LockTime = os.time() },
					Data = session.Data,
				}
			end)
		end)
		if ok and ownedByUs then
			return true
		end
		if ok and not ownedByUs then
			warn("[Data] Save skipped: profile lock belongs to another server for " .. player.Name)
			return false
		end
		warn(("[Data] Save attempt %d/%d failed for %s: %s"):format(attempt, SAVE_ATTEMPTS, player.Name, tostring(err)))
		task.wait(2 ^ attempt)
	end
	return false
end

function DataService.Release(player: Player)
	DataService.Save(player, true)
	sessions[player] = nil
end

function DataService.Init()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in sessions do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(0.5)
		end
		local pendingSaves = 0
		for player in sessions do
			pendingSaves += 1
			task.spawn(function()
				DataService.Save(player, true)
				pendingSaves -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pendingSaves > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
