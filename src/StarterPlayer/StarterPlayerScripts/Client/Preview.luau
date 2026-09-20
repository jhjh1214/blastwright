--!nonstrict
-- Planning aids: charge markers and hit markers. The full-chain preview is gated behind the Seismograph upgrade
-- so that reading crystal types (not just running a simulator) matters early on.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChainSim = require(Shared.ChainSim)
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)

local CavernView = require(script.Parent.CavernView)
local State = require(script.Parent.State)

local Preview = {}
Preview.Text = "" -- read by UI
Preview.OnText = nil -- callback(text)

local markerFolder = Instance.new("Folder")
markerFolder.Name = "PreviewMarkers"
markerFolder.Parent = workspace

local used = {}
local free = {}

local function marker(position, color, diameter, transparency)
	local m = table.remove(free)
	if not m then
		m = Instance.new("Part")
		m.Shape = Enum.PartType.Cylinder
		m.Anchored = true
		m.CanCollide = false
		m.CanQuery = false
		m.CanTouch = false
		m.CastShadow = false
		m.Material = Enum.Material.Neon
	end
	m.Color = color
	m.Transparency = transparency
	m.Size = Vector3.new(0.2, diameter, diameter)
	m.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	m.Parent = markerFolder
	table.insert(used, m)
end

local function clear()
	for _, m in used do
		m.Parent = nil
		table.insert(free, m)
	end
	table.clear(used)
end

local function setText(text)
	Preview.Text = text
	if Preview.OnText then
		Preview.OnText(text)
	end
end

function Preview.Refresh()
	clear()
	local view = CavernView.Get(State.UserId)
	if not view or not State.Data then
		return setText("")
	end
	if State.Busy then
		return setText("")
	end

	for _, c in State.Placed do
		marker(Geometry.CellPosition(view.Origin, c.X, c.Z) + Vector3.new(0, 0.15, 0), Color3.fromRGB(255, 170, 60), 4.2, 0.1)
	end
	if #State.Placed == 0 then
		return setText("Tap the cavern to plant a charge")
	end

	local upgrades = Config.Upgrades.Defs
	local ctx = {
		Crystals = Config.Context.Crystals,
		Charges = Config.Context.Charges,
		Tuning = Config.Tuning,
		RadiusBonus = State.UpgradeLevel("BlastRadius") * upgrades.BlastRadius.PerLevel,
		MomentumPops = Config.Tuning.MomentumPops - State.UpgradeLevel("Momentum") * upgrades.Momentum.PerLevel,
	}
	local result = ChainSim.Run(view.Grid, State.Placed, ctx)
	local seismograph = State.UpgradeLevel("Seismograph") > 0

	local direct = 0
	for _, ev in result.Events do
		if ev.Cause == "Charge" then
			direct += 1
		end
		if seismograph or ev.Cause == "Charge" then
			marker(Geometry.CellPosition(view.Origin, ev.X, ev.Z) + Vector3.new(0, 0.12, 0), Color3.fromRGB(255, 255, 255), 3.6, 0.55)
		end
	end

	if seismograph then
		local tier = result.Tier and (" | " .. result.Tier) or ""
		local refund = result.Momentum and " | +1 charge" or ""
		setText(("Chain %d | ~%d shards%s%s"):format(result.Pops, result.Total, tier, refund))
	else
		setText(("Direct hits: %d"):format(direct))
	end
end

return Preview
