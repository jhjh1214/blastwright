--!nonstrict
-- Hub leaderboards: OrderedDataStores of each player's best chain, deepest Expedition floor and bosses slain, shown on boards
-- in the hub. Everything here is best-effort and wrapped in pcall: in Studio without a published place (or if the service
-- is down) a board simply says it is unavailable and gameplay is unaffected. Ranking and text come from the pure, tested
-- Shared/Board.luau.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Board = require(ReplicatedStorage:WaitForChild("Shared").Board)

local TOP = 10
local REFRESH_SECONDS = 90
local SUBMIT_SECONDS = 30 -- queued improvements are written at most this often (DataStore budgets are limited)

-- kind -> board definition. World.luau builds one hub board per kind (Registry.Boards[kind]).
local BOARDS = {
	Chain = { Store = "BestChain_v1", Title = "LONGEST CHAINS" },
	Depth = { Store = "BestDepth_v1", Title = "DEEPEST EXPEDITIONS" },
	Bosses = { Store = "BossesSlain_v1", Title = "BOSS SLAYERS" },
}

local Leaderboard = {}
Leaderboard.Kinds = { "Chain", "Depth", "Bosses" }

local stores = {} -- [kind] = OrderedDataStore
local labels = {} -- [kind] = TextLabel
local submitted = {} -- [kind][userId] = best value already written
local pending = {} -- [kind][userId] = best value waiting to be written
local nameCache = {}
for kind in BOARDS do
	submitted[kind] = {}
	pending[kind] = {}
end

local function getStore(kind)
	if not stores[kind] then
		stores[kind] = DataStoreService:GetOrderedDataStore(BOARDS[kind].Store)
	end
	return stores[kind]
end

local function setText(kind, text)
	if labels[kind] then
		labels[kind].Text = text
	end
end

-- Write one player's best if it beats what is stored. Returns true on success (including "nothing to improve").
local function write(kind, userId, value)
	local ok, err = pcall(function()
		getStore(kind):UpdateAsync(tostring(userId), function(old)
			if old == nil or value > old then
				return value
			end
			return nil -- keep the existing, higher score
		end)
	end)
	if ok then
		submitted[kind][userId] = value
	else
		warn(("[Leaderboard] %s write failed for %d: %s"):format(kind, userId, tostring(err)))
	end
	return ok
end

-- Queue a player's best for a board; only improvements are ever written.
function Leaderboard.Submit(kind, userId, value)
	if not BOARDS[kind] or type(value) ~= "number" or value <= 0 then
		return
	end
	if (submitted[kind][userId] or 0) >= value or (pending[kind][userId] or 0) >= value then
		return
	end
	pending[kind][userId] = value
end

-- Try to write a player's queued values right away (used when they leave).
function Leaderboard.Flush(userId)
	for kind in BOARDS do
		local value = pending[kind][userId]
		if value and write(kind, userId, value) then
			pending[kind][userId] = nil
		end
	end
end

local function refresh(kind)
	local ok, pages = pcall(function()
		return getStore(kind):GetSortedAsync(false, TOP)
	end)
	if not ok then
		setText(kind, BOARDS[kind].Title .. "\n\nUnavailable right now.\n(Needs a published game with\nAPI access enabled.)")
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
	setText(kind, Board.Format(BOARDS[kind].Title, rows, TOP))
end

-- boardLabels: { [kind] = TextLabel } from the hub (a missing label is skipped, so a world that failed to build is harmless).
function Leaderboard.Init(boardLabels)
	labels = boardLabels or {}
	for kind in BOARDS do
		setText(kind, BOARDS[kind].Title .. "\n\nLoading...")
	end

	task.spawn(function()
		task.wait(5)
		while true do
			for kind in BOARDS do
				refresh(kind)
				task.wait(2) -- spread the reads out
			end
			task.wait(REFRESH_SECONDS)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SUBMIT_SECONDS)
			for kind in BOARDS do
				for userId, value in pending[kind] do
					if write(kind, userId, value) then
						pending[kind][userId] = nil
					end
				end
			end
		end
	end)
end

return Leaderboard
