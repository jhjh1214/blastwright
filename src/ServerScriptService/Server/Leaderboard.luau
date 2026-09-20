--!nonstrict
-- "Longest Chains" leaderboard: an OrderedDataStore of each player's best chain, shown on a board in the hub.
-- Everything here is best-effort and wrapped in pcall: in Studio without a published place (or if the service is down)
-- the board simply says it is unavailable and gameplay is unaffected. Ranking and text come from the pure, tested
-- Shared/Board.luau.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Board = require(ReplicatedStorage:WaitForChild("Shared").Board)

local STORE_NAME = "BestChain_v1"
local TITLE = "LONGEST CHAINS"
local TOP = 10
local REFRESH_SECONDS = 90
local SUBMIT_SECONDS = 30 -- queued improvements are written at most this often (DataStore budgets are limited)

local Leaderboard = {}

local store = nil
local label = nil
local submitted = {} -- [userId] = best value already written
local pending = {} -- [userId] = best value waiting to be written
local nameCache = {}

local function getStore()
	if not store then
		store = DataStoreService:GetOrderedDataStore(STORE_NAME)
	end
	return store
end

local function setText(text)
	if label then
		label.Text = text
	end
end

-- Write one player's best if it beats what is stored. Returns true on success (including "nothing to improve").
local function write(userId, value)
	local ok, err = pcall(function()
		getStore():UpdateAsync(tostring(userId), function(old)
			if old == nil or value > old then
				return value
			end
			return nil -- keep the existing, higher score
		end)
	end)
	if ok then
		submitted[userId] = value
	else
		warn(("[Leaderboard] write failed for %d: %s"):format(userId, tostring(err)))
	end
	return ok
end

-- Queue a player's best chain; only improvements are ever written.
function Leaderboard.Submit(userId, value)
	if type(value) ~= "number" or value <= 0 then
		return
	end
	if (submitted[userId] or 0) >= value or (pending[userId] or 0) >= value then
		return
	end
	pending[userId] = value
end

-- Try to write a player's queued value right away (used when they leave).
function Leaderboard.Flush(userId)
	local value = pending[userId]
	if value and write(userId, value) then
		pending[userId] = nil
	end
end

local function refresh()
	local ok, pages = pcall(function()
		return getStore():GetSortedAsync(false, TOP)
	end)
	if not ok then
		setText(TITLE .. "\n\nUnavailable right now.\n(Needs a published game with\nAPI access enabled.)")
		return
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(entry.key)
		if userId then
			local name = nameCache[userId]
			if not name then
				local nameOk, result = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				name = nameOk and result or ("Player " .. entry.key)
				nameCache[userId] = name
			end
			table.insert(rows, { Name = name, Value = entry.value })
		end
	end
	setText(Board.Format(TITLE, rows, TOP))
end

-- boardLabel: the TextLabel on the hub board (may be nil if the world failed to build; then this is a no-op).
function Leaderboard.Init(boardLabel)
	label = boardLabel
	setText(TITLE .. "\n\nLoading...")

	task.spawn(function()
		task.wait(5)
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SUBMIT_SECONDS)
			for userId, value in pending do
				if write(userId, value) then
					pending[userId] = nil
				end
			end
		end
	end)
end

return Leaderboard
