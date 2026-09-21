--!strict
-- All RemoteEvents in one place. The server creates them on first require; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = { "Sync", "SeamStart", "SeamRemove", "Engage", "Detonate", "VolleyResult", "Buy", "Claim", "ClaimWeekly", "ClaimGoal", "Equip", "Setting", "Community", "RunState", "RunPick", "PuzzleStart", "FarmAction", "MonsterTurn", "Dodge", "EquipTitle", "UseCharge", "RunRevive", "EquipFinisher", "ClubClaim", "Notify" }

local Remotes: { [string]: RemoteEvent } = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in NAMES do
		Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
	end
end

return Remotes
