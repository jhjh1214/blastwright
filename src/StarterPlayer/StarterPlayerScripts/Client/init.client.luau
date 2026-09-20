--!nonstrict
-- Client bootstrap: wires server events to presentation modules.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)

local AudioManager = require(script.AudioManager)
local CameraFeedback = require(script.CameraFeedback)
local CavernView = require(script.CavernView)
local Input = require(script.Input)
local Playback = require(script.Playback)
local Preview = require(script.Preview)
local State = require(script.State)
local UI = require(script.UI)

-- The camera is fixed over the cavern; turn off the default movement controls (also removes the mobile thumbstick).
task.spawn(function()
	local ok, err = pcall(function()
		local playerModule = require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
		playerModule:GetControls():Disable()
	end)
	if not ok then
		warn("[Client] could not disable default controls: " .. tostring(err))
	end
end)

task.spawn(AudioManager.Verify)

UI.Init()
Preview.OnText = UI.SetPreview
CameraFeedback.Start()
Input.Init()

Remotes.Sync.OnClientEvent:Connect(function(snapshot)
	State.SetData(snapshot)
end)

Remotes.SeamStart.OnClientEvent:Connect(function(payload)
	local view = CavernView.Build(payload)
	if payload.UserId == localPlayer.UserId then
		table.clear(State.Placed)
		local center = Geometry.CellPosition(view.Origin, (view.Size + 1) / 2, (view.Size + 1) / 2)
		CameraFeedback.Focus(center, view.Extent)
		State.Changed:Fire("Placed")
	end
end)

Remotes.SeamRemove.OnClientEvent:Connect(function(userId)
	CavernView.Remove(userId)
end)

Remotes.VolleyResult.OnClientEvent:Connect(function(result)
	Playback.Run(result)
end)

Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	UI.Toast(tostring(text), tostring(kind))
end)
