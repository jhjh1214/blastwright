--!nonstrict
-- Client-side view state. Never authoritative: the server's Sync snapshot is the truth.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Loadout = require(Shared.Loadout)

local State = {
	UserId = Players.LocalPlayer.UserId,
	Data = nil, -- last Sync snapshot
	Placed = {}, -- { {X=, Z=, Kind=} } charges the player has planted but not yet detonated
	SelectedCharge = "Basic",
	Busy = false, -- true while our own volley is playing back
	Engaged = false, -- true while at a blast site (fixed camera, blast HUD)
	PanelOpen = false,
	Run = nil, -- Expedition view from the server (nil when not on one)
}

State.Changed = Instance.new("BindableEvent") -- fires a string: "Data" | "Placed" | "Charge"

function State.SetData(snapshot)
	State.Data = snapshot
	State.DailyResetAt = os.clock() + (snapshot.DailyResetIn or 0)
	State.EventsAt = os.clock() -- EndsIn values in the snapshot count down from here
	State.WeeklyResetAt = os.clock() + (snapshot.WeeklyResetIn or 0)
	if not (snapshot.UnlockedCharges and snapshot.UnlockedCharges[State.SelectedCharge]) then
		State.SelectedCharge = "Basic"
	end
	State.Changed:Fire("Data")
end

-- This player's effective charge definitions (base + owned traits + Fat Fuse), identical to what the server simulates.
-- Cached per snapshot. The Daily Puzzle ignores upgrades and traits, so it gets the base definitions.
local cachedFor, cached = nil, nil
function State.Charges(puzzle)
	if puzzle or not State.Data then
		return Config.Charges.Defs
	end
	if cachedFor ~= State.Data then
		local bonus = (State.Data.Upgrades.BlastRadius or 0) * Config.Upgrades.Defs.BlastRadius.PerLevel
		cached = Loadout.Charges(Config.Charges.Defs, { Owned = State.Data.Traits or {} }, Config.Traits, bonus)
		cachedFor = State.Data
	end
	return cached
end

function State.UpgradeLevel(id)
	return State.Data and State.Data.Upgrades[id] or 0
end

return State
