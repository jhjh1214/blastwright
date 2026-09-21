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
local Guide = require(script.Guide)
local Input = require(script.Input)
local Playback = require(script.Playback)
local Preview = require(script.Preview)
local State = require(script.State)
local UI = require(script.UI)

-- Optional presentation systems: a failure in one of these warns and the game still starts.
local function optional(name, start)
	local ok, err = pcall(start)
	if not ok then
		warn(("[Client] optional system '%s' failed to start: %s"):format(name, tostring(err)))
	end
end

task.spawn(AudioManager.Verify)
optional("ambience loops", AudioManager.StartLoops)
optional("music", AudioManager.StartMusic)

UI.Init()
Preview.OnText = UI.SetPreview
Preview.OnInfo = UI.SetInfo
CameraFeedback.Start()
Input.Init()
optional("cache visuals", CacheView.Init)
optional("ambient motes", Ambience.Init)
optional("guide", Guide.Init)
UI.SetEngaged(false)

Remotes.Sync.OnClientEvent:Connect(function(snapshot)
	if snapshot.Settings then
		AudioManager.SetEnabled("Music", snapshot.Settings.Music ~= false)
		AudioManager.SetEnabled("Sfx", snapshot.Settings.Sfx ~= false)
		CameraFeedback.SetShakeEnabled(snapshot.Settings.Shake ~= false)
	end
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

Remotes.RunState.OnClientEvent:Connect(function(view)
	State.Run = view.Active and view or nil
	UI.SetRun(State.Run)
	State.Changed:Fire("Placed") -- refreshes the preview with the run's modifiers
end)

Remotes.MonsterTurn.OnClientEvent:Connect(function(turn)
	local view = CavernView.Get(localPlayer.UserId)
	if not view then
		return
	end
	for _, e in turn.Eaten do
		CavernView.Eat(view, e.X, e.Z)
	end
	CavernView.SetMonster(view, turn.Monster)
	if turn.Emerged or turn.Slain or turn.HeartsLost or #turn.Eaten > 0 then
		CameraFeedback.Shake(turn.HeartsLost and 1.4 or 0.8)
	end
end)

Remotes.Community.OnClientEvent:Connect(function(view)
	State.Community, State.CommunityAt = view, os.clock()
	UI.SetCommunity(view, State.CommunityAt)
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
