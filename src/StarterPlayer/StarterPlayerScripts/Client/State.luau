--!nonstrict
-- Client-side view state. Never authoritative: the server's Sync snapshot is the truth.
local Players = game:GetService("Players")

local State = {
	UserId = Players.LocalPlayer.UserId,
	Data = nil, -- last Sync snapshot
	Placed = {}, -- { {X=, Z=, Kind=} } charges the player has planted but not yet detonated
	SelectedCharge = "Basic",
	Busy = false, -- true while our own volley is playing back
	Engaged = false, -- true while at a blast site (fixed camera, blast HUD)
	PanelOpen = false,
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

function State.UpgradeLevel(id)
	return State.Data and State.Data.Upgrades[id] or 0
end

return State
