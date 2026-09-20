--!nonstrict
-- Plays a server-computed volley timeline: each event triggers pop, VFX, number, sound and camera feedback.
-- The server already decided the outcome; this is presentation only.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChainSim = require(Shared.ChainSim)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)

local AudioManager = require(script.Parent.AudioManager)
local CameraFeedback = require(script.Parent.CameraFeedback)
local CavernView = require(script.Parent.CavernView)
local FloatingNumbers = require(script.Parent.FloatingNumbers)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)
local VFX = require(script.Parent.VFX)

local Playback = {}

local runs = {}
local connection = nil

local CELL = Config.Tuning.CellSize

local function crystalColor(kind)
	local c = Config.Crystals.Defs[kind].Color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function popEvent(run, ev)
	local view = run.View
	local key = ChainSim.Key(view.Size, ev.X, ev.Z)
	local pos = Geometry.CellPosition(view.Origin, ev.X, ev.Z)
	local top = pos + Vector3.new(0, 2, 0)
	local col = crystalColor(ev.Kind)
	local behavior = Config.Crystals.Defs[ev.Kind].Behavior
	run.Count += 1

	CavernView.Pop(view, key)
	VFX.Burst(top, col, ev.Cause == "Charge" and 14 or 9, 22)
	if ev.Cause == "Chain" and ev.SX then
		-- A short line from the crystal that set this one off, so the chain is visible as it travels.
		VFX.Beam(Geometry.CellPosition(view.Origin, ev.SX, ev.SZ) + Vector3.new(0, 2, 0), top, col, 0.3)
	end

	if behavior == "Prism" then
		local range = Config.Crystals.Defs[ev.Kind].Params.Range
		local x1 = math.max(1, ev.X - range)
		local x2 = math.min(view.Size, ev.X + range)
		VFX.Beam(Geometry.CellPosition(view.Origin, x1, ev.Z) + Vector3.new(0, 2, 0), Geometry.CellPosition(view.Origin, x2, ev.Z) + Vector3.new(0, 2, 0), col, 0.6)
	elseif behavior == "Volatile" then
		VFX.Ring(pos + Vector3.new(0, 0.3, 0), col, CELL * 3.2, 0.3)
	end

	if behavior == "Unstable" then
		FloatingNumbers.Show(top, "CAVE-IN", Color3.fromRGB(255, 90, 100), 1.1)
	elseif ev.Value > 0 then
		FloatingNumbers.Show(top, "+" .. ev.Value, col, math.min(1 + (ev.Mult - 1) * 0.15, 1.6))
	end

	-- Pitch climbs with the chain so long chains sound like a rising cascade.
	AudioManager.Play("Pop", { Pitch = 0.9 + math.min(run.Count, 40) * 0.025 })

	if run.Own then
		CameraFeedback.Shake(0.05 + math.min(run.Count, 30) * 0.004)
		UI.SetChain(run.Count, ev.Mult)
	end
end

-- Fuse flash: shows when a Delayed crystal was hit, well before it actually pops.
local function lightFuse(run, ev)
	local view = run.View
	local pos = Geometry.CellPosition(view.Origin, ev.X, ev.Z)
	local col = crystalColor(ev.Kind)
	VFX.Ring(pos + Vector3.new(0, 0.4, 0), col, CELL * 1.6, 0.5)
	VFX.Burst(pos + Vector3.new(0, 3.4, 0), col, 5, 12)
	AudioManager.Play("Click", { Pitch = 1.6 })
end

local function step()
	local now = os.clock()
	for i = #runs, 1, -1 do
		local run = runs[i]
		local elapsed = now - run.Start
		local events = run.Result.Events
		while run.FuseNext <= #run.Fuses and run.Fuses[run.FuseNext].Lit <= elapsed do
			pcall(lightFuse, run, run.Fuses[run.FuseNext])
			run.FuseNext += 1
		end
		while run.Next <= #events and events[run.Next].T <= elapsed do
			local ok, err = pcall(popEvent, run, events[run.Next])
			if not ok then
				warn("[Playback] " .. tostring(err))
			end
			run.Next += 1
		end
		if run.Next > #events and elapsed >= run.Result.Duration then
			table.remove(runs, i)
			if run.Own then
				State.Busy = false
				UI.SetChain(0, 1)
				if run.Result.Tier then
					UI.ShowTier(run.Result.Tier, run.Result.Bonus, run.Result.Total)
					CameraFeedback.Shake(0.9)
					CameraFeedback.Punch(6)
					VFX.Ring(run.View.Origin + Vector3.new(0, 0.4, 0), Color3.fromRGB(255, 205, 90), run.View.Extent * 1.4, 0.7)
				end
				if run.Result.Momentum then
					UI.Toast("Momentum! +1 charge", "Reward")
				end
				Preview.Refresh()
				UI.Refresh()
			end
		end
	end
	if #runs == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

function Playback.Run(result)
	local view = CavernView.Get(result.UserId)
	if not view then
		return
	end
	local own = result.UserId == State.UserId

	-- Keep the local grid in sync with the server immediately; visuals follow on the timeline.
	for _, ev in result.Events do
		view.Grid.Cells[ChainSim.Key(view.Size, ev.X, ev.Z)] = nil
	end

	-- Someone else's grid that is not built (out of range): the data is already updated, nothing to show.
	if not own and not view.Built then
		return
	end

	if own then
		State.Busy = true
		table.clear(State.Placed)
		Preview.Refresh()
		CameraFeedback.Shake(0.5)
	end
	for _, c in result.Charges or {} do
		local p = Geometry.CellPosition(view.Origin, c.X, c.Z)
		VFX.Ring(p + Vector3.new(0, 0.4, 0), Color3.fromRGB(255, 170, 60), CELL * 2.6, 0.35)
		VFX.Burst(p + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 200, 120), 12, 26)
	end
	AudioManager.Play("Detonate")

	local fuses = {}
	for _, ev in result.Events do
		if ev.Lit then
			table.insert(fuses, ev)
		end
	end
	table.sort(fuses, function(a, b)
		return a.Lit < b.Lit
	end)

	table.insert(runs, { Result = result, View = view, Own = own, Start = os.clock(), Next = 1, Count = 0, Fuses = fuses, FuseNext = 1 })
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
	if #result.Events == 0 and own then
		State.Busy = false
	end
end

return Playback
