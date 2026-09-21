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
local Trophies = require(script.Trophies)
local CameraFeedback = require(script.CameraFeedback)
local CavernView = require(script.CavernView)
local Guide = require(script.Guide)
local Input = require(script.Input)
local Playback = require(script.Playback)
local Preview = require(script.Preview)
local State = require(script.State)
local UI = require(script.UI)
local VFX = require(script.VFX)
local FloatingNumbers = require(script.FloatingNumbers)
local Geometry = require(Shared.Geometry)

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
Preview.OnCombat = UI.SetCombat
CameraFeedback.Start()
Input.Init()
optional("cache visuals", CacheView.Init)
optional("ambient motes", Ambience.Init)
optional("trophy hall", Trophies.Init)
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
	local ok, err = pcall(function()
		State.Run = view.Active and view or nil
		UI.SetRun(State.Run)
		State.Changed:Fire("Placed") -- refreshes the preview with the run's modifiers
	end)
	if not ok then
		warn("[Client] RunState failed: " .. tostring(err))
	end
end)

Remotes.MonsterTurn.OnClientEvent:Connect(function(turn)
	local ok, err = pcall(function()
		local view = CavernView.Get(localPlayer.UserId)
		if not view then
			return
		end
		for _, e in turn.Eaten do
			CavernView.Eat(view, e.X, e.Z)
		end
		-- hit numbers and bursts on whatever was hit (positions are read before the creature moves on)
		local hitPos = (turn.BossDamage and turn.BossDamage > 0 and CavernView.BossPosition(view)) or (turn.Damage and turn.Damage > 0 and CavernView.MonsterPosition(view)) or nil
		local hitAmount = (turn.BossDamage and turn.BossDamage > 0 and turn.BossDamage) or (turn.Damage and turn.Damage > 0 and turn.Damage) or nil
		if turn.BossDamage and turn.BossDamage > 0 then
			CavernView.BossHit(view)
		end
		-- an attack landed: fire where the crystals were destroyed
		if #turn.Eaten > 0 and turn.Boss then
			for i = 1, math.min(#turn.Eaten, 10) do
				local at = Geometry.CellPosition(view.Origin, turn.Eaten[i].X, turn.Eaten[i].Z) + Vector3.new(0, 2, 0)
				VFX.Burst(at, Color3.fromRGB(255, 130, 60), 10, 24)
			end
			CameraFeedback.Shake(1)
		end
		if hitPos and hitAmount then
			FloatingNumbers.Show(hitPos + Vector3.new(0, 8, 0), "-" .. hitAmount, Color3.fromRGB(255, 90, 90), math.min(1.1 + hitAmount * 0.03, 2))
			VFX.Burst(hitPos + Vector3.new(0, 3, 0), Color3.fromRGB(255, 90, 90), 16, 26)
		end
		if turn.Slain then
			local at = Geometry.CellPosition(view.Origin, turn.Slain.X, turn.Slain.Z) + Vector3.new(0, 3, 0)
			VFX.Burst(at, Color3.fromRGB(255, 220, 90), 40, 34)
			VFX.Ring(at, Color3.fromRGB(255, 220, 90), 22, 0.6)
			FloatingNumbers.Show(at + Vector3.new(0, 4, 0), "+" .. turn.Slain.Bounty, Color3.fromRGB(255, 215, 90), 1.6)
		end
		if turn.HeartsLost or turn.Stolen then
			UI.Flash(Color3.fromRGB(255, 40, 40), 0.45) -- the rig took a hit
		end
		for _, c in turn.Corrupted or {} do
			CavernView.Corrupt(view, c.X, c.Z)
		end
		if turn.Cut then
			local at = CavernView.BossPosition(view)
			if at then
				FloatingNumbers.Show(at + Vector3.new(0, 10, 0), "CUT!", Color3.fromRGB(120, 255, 170), 1.5)
			end
		elseif turn.Dodged then
			local at = CavernView.BossPosition(view)
			if at then
				FloatingNumbers.Show(at + Vector3.new(0, 10, 0), "BLOCKED", Color3.fromRGB(120, 200, 255), 1.5)
			end
		end
		CavernView.SetMonster(view, turn.Monster)
		CavernView.SetBoss(view, turn.Boss)
		if turn.BossSlain then
			-- FINAL BLAST: the arena erupts.
			local core = Geometry.CellPosition(view.Origin, 5, 5) + Vector3.new(0, 4, 0)
			local fin = State.Data and State.Data.Finishers and State.Data.Finishers.Color or { 255, 205, 90 } -- the equipped finisher colours the FINAL BLAST
			for i = 1, 6 do
				task.delay(i * 0.12, function()
					VFX.Burst(core + Vector3.new(math.random(-8, 8), math.random(0, 6), math.random(-8, 8)), Color3.fromRGB(math.max(0, fin[1] - i * 8), math.max(0, fin[2] - i * 12), math.max(0, fin[3] - i * 6)), 30, 40)
					VFX.Ring(view.Origin + Vector3.new(0, 0.4, 0), Color3.fromRGB(fin[1], fin[2], fin[3]), view.Extent * (0.6 + i * 0.25), 0.9)
				end)
			end
			UI.ShowTier("Boss defeated")
			UI.Flash(Color3.fromRGB(255, 240, 200), 0.6)
			CameraFeedback.Shake(2)
			CameraFeedback.Punch(10)
		elseif turn.PhaseChanged then
			UI.ShowPhase(turn.PhaseChanged, turn.Boss)
			CameraFeedback.Punch(6)
			CameraFeedback.Shake(1.2)
			VFX.Ring(view.Origin + Vector3.new(0, 0.4, 0), Color3.fromRGB(255, 220, 160), view.Extent * 1.6, 0.8)
			UI.Flash(Color3.fromRGB(255, 255, 255), 0.25)
		end
		if turn.Emerged or turn.Slain or turn.HeartsLost or #turn.Eaten > 0 then
			CameraFeedback.Shake(turn.HeartsLost and 1.4 or 0.8)
		end
	end)
	if not ok then
		warn("[Client] MonsterTurn failed: " .. tostring(err))
	end
end)

Remotes.Community.OnClientEvent:Connect(function(view)
	State.Community, State.CommunityAt = view, os.clock()
	UI.SetCommunity(view, State.CommunityAt)
end)

Remotes.Sync.OnClientEvent:Connect(function(snapshot)
	pcall(function()
		VFX.SetCritical((snapshot.Critical or 0) > 0)
	end)
	pcall(function()
		AudioManager.SetIntensity((snapshot.Boss and 1 or 0) + ((snapshot.Critical or 0) > 0 and 1 or 0)) -- the music rises for boss fights and Critical Mass
	end)
	-- The boss markers (armor nodes, weak points, marked attack cells) follow the server's snapshot.
	local view = CavernView.Get(localPlayer.UserId)
	if snapshot.Boss and not State.LastBoss and State.Engaged then
		UI.ShowBossIntro(snapshot.Boss) -- the boss just appeared
		CameraFeedback.Punch(7)
	end
	State.LastBoss = snapshot.Boss ~= nil
	if view then
		CavernView.SetBoss(view, snapshot.Boss)
		CavernView.SetMonster(view, snapshot.Monster) -- an awake Lurker from a Nest, Elite room or Blood Rush shows up at floor start
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
