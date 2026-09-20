--!nonstrict
-- Client bootstrap: wires server events to presentation modules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Ambience = require(script.Ambience)
local AudioManager = require(script.AudioManager)
local Blasting = require(script.Blasting)
local CacheView = require(script.CacheView)
local CameraFeedback = require(script.CameraFeedback)
local CavernView = require(script.CavernView)
local Input = require(script.Input)
local Playback = require(script.Playback)
local Preview = require(script.Preview)
local State = require(script.State)
local UI = require(script.UI)

task.spawn(AudioManager.Verify)

UI.Init()
Preview.OnText = UI.SetPreview
CameraFeedback.Start()
Input.Init()
CacheView.Init()
Ambience.Init()
UI.SetEngaged(false)

Remotes.Sync.OnClientEvent:Connect(function(snapshot)
	State.SetData(snapshot)
end)

Remotes.SeamStart.OnClientEvent:Connect(function(payload)
	local view = CavernView.Build(payload)
	if payload.UserId == localPlayer.UserId then
		table.clear(State.Placed)
		if State.Engaged then
			Blasting.Focus(view) -- a fresh seam at the same site: keep the camera where it is
		end
		State.Changed:Fire("Placed")
	end
end)

Remotes.SeamRemove.OnClientEvent:Connect(function(userId)
	CavernView.Remove(userId)
	if userId == localPlayer.UserId then
		Blasting.Leave()
	end
end)

Remotes.Engage.OnClientEvent:Connect(function(siteId)
	Blasting.Engage(siteId)
end)

Remotes.VolleyResult.OnClientEvent:Connect(function(result)
	Playback.Run(result)
end)

Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	UI.Toast(tostring(text), tostring(kind))
end)

-- Dying or respawning ends blast mode.
localPlayer.CharacterRemoving:Connect(function()
	Blasting.Leave()
end)

-- Location label
task.spawn(function()
	while true do
		task.wait(0.5)
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and not State.Engaged then
			UI.SetLocation(Config.World.AreaName(root.Position.X, root.Position.Z))
		end
	end
end)
