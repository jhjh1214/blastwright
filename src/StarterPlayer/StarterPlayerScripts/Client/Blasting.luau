--!nonstrict
-- Enter and leave "blast mode": fixed camera over the site's grid, movement locked, blast HUD shown.
-- Movement is locked on the client only as UX; the server separately requires you to stand at your station.
local Players = game:GetService("Players")

local AudioManager = require(script.Parent.AudioManager)
local CameraFeedback = require(script.Parent.CameraFeedback)
local CavernView = require(script.Parent.CavernView)
local Geometry = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Geometry)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Blasting = {}
local saved = nil

local function lockMovement()
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or saved then
		return
	end
	saved = { Humanoid = humanoid, WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight }
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
end

local function unlockMovement()
	if saved then
		local h = saved.Humanoid
		if h and h.Parent then
			h.WalkSpeed = saved.WalkSpeed
			h.JumpPower = saved.JumpPower
			h.JumpHeight = saved.JumpHeight
		end
		saved = nil
	end
end

function Blasting.Focus(view)
	local mid = (view.Size + 1) / 2
	CameraFeedback.Focus(Geometry.CellPosition(view.Origin, mid, mid), view.Extent)
end

function Blasting.Engage(siteId)
	local view = CavernView.Get(State.UserId)
	local waited = 0
	while (not view or view.SiteId ~= siteId) and waited < 3 do
		task.wait(0.1)
		waited += 0.1
		view = CavernView.Get(State.UserId)
	end
	if not view then
		return
	end
	State.Engaged = true
	lockMovement()
	Blasting.Focus(view)
	UI.SetEngaged(true)
	AudioManager.Duck(0.45)
	table.clear(State.Placed)
	Preview.SetHover(nil, nil, true)
	Preview.Refresh()
	UI.Refresh()
end

function Blasting.Leave()
	if not State.Engaged then
		return
	end
	State.Engaged = false
	unlockMovement()
	CameraFeedback.Clear()
	table.clear(State.Placed)
	UI.SetEngaged(false)
	AudioManager.Duck(1)
	Preview.SetHover(nil, nil, true)
	Preview.Refresh()
end

return Blasting
