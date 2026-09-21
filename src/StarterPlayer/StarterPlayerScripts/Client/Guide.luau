--!nonstrict
-- Onboarding and navigation. Asks Objectives (pure, tested) what the player should do next, then shows it:
--   * objective card + pulsing Forge button (via UI)
--   * a floating gold marker with distance above the target
--   * a trail of glowing dots on the ground that ripples toward the target
--   * an edge-of-screen arrow when the target is out of view
--   * a first-time welcome panel
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Objectives = require(Shared.Objectives)

local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Guide = {}

local GOLD = Color3.fromRGB(255, 205, 90)
local CRUMBS = 10
local CRUMB_SPACING = 7

local cfg = {
	Strata = Config.Strata,
	Upgrades = Config.Upgrades.Defs,
	World = Config.World,
	Tuning = Config.Tuning,
}

local target = nil -- Vector3
local targetLabel = ""
local markerPart, markerLabel, edgeArrow, edgeDistance
local crumbs = {}
local shownWelcome = false

local function makePart(size)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	return p
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "Guide"
	folder.Parent = workspace

	markerPart = makePart(Vector3.one)
	markerPart.Transparency = 1
	markerPart.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(180, 84)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 5000
	bb.Adornee = markerPart
	bb.Parent = markerPart
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.new(1, 0, 0, 44)
	arrow.Font = Enum.Font.FredokaOne
	arrow.Text = "▼"
	arrow.TextSize = 40
	arrow.TextColor3 = GOLD
	arrow.TextStrokeTransparency = 0.3
	arrow.Parent = bb
	markerLabel = Instance.new("TextLabel")
	markerLabel.BackgroundTransparency = 1
	markerLabel.Position = UDim2.fromOffset(0, 42)
	markerLabel.Size = UDim2.new(1, 0, 0, 40)
	markerLabel.Font = Enum.Font.BuilderSansBold
	markerLabel.TextSize = 18
	markerLabel.TextColor3 = GOLD
	markerLabel.TextStrokeTransparency = 0.3
	markerLabel.Parent = bb

	for i = 1, CRUMBS do
		local c = makePart(Vector3.one * 1.1)
		c.Shape = Enum.PartType.Ball
		c.Material = Enum.Material.Neon
		c.Color = GOLD
		c.Transparency = 1
		c.Parent = folder
		crumbs[i] = c
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "GuideGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- so viewport coordinates line up
	gui.DisplayOrder = 4
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	edgeArrow = Instance.new("TextLabel")
	edgeArrow.BackgroundTransparency = 1
	edgeArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	edgeArrow.Size = UDim2.fromOffset(56, 56)
	edgeArrow.Font = Enum.Font.FredokaOne
	edgeArrow.Text = "▲"
	edgeArrow.TextSize = 46
	edgeArrow.TextColor3 = GOLD
	edgeArrow.TextStrokeTransparency = 0.3
	edgeArrow.Visible = false
	edgeArrow.Parent = gui
	edgeDistance = Instance.new("TextLabel")
	edgeDistance.BackgroundTransparency = 1
	edgeDistance.AnchorPoint = Vector2.new(0.5, 0)
	edgeDistance.Size = UDim2.fromOffset(120, 22)
	edgeDistance.Font = Enum.Font.BuilderSansBold
	edgeDistance.TextSize = 16
	edgeDistance.TextColor3 = GOLD
	edgeDistance.TextStrokeTransparency = 0.3
	edgeDistance.Visible = false
	edgeDistance.Parent = gui
end

local function hideWorldGuide()
	markerPart.Parent = nil
	edgeArrow.Visible = false
	edgeDistance.Visible = false
	for _, c in crumbs do
		c.Transparency = 1
	end
end

local function playerPosition()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

-- Decide what to show. Cheap, run a few times per second.
local function refreshObjective()
	if not State.Data then
		return
	end
	local pos = playerPosition()

	if State.Engaged then
		local hint = Objectives.Blast(State.Data, #State.Placed)
		UI.SetBlastHint(hint and hint.Id == "Detonate" and hint.Text or "") -- planting is explained by the preview line
		UI.SetObjective(nil)
		UI.SetHighlight(nil)
		target = nil
		return
	end
	UI.SetBlastHint("")
	if not pos then
		return
	end
	local objective = Objectives.Roam(State.Data, pos.X, pos.Z, cfg)
	UI.SetObjective(objective.Text)
	UI.SetHighlight(objective.Highlight)
	if objective.Target then
		target = Vector3.new(objective.Target.X, 3, objective.Target.Z)
		targetLabel = objective.TargetLabel or "Go here"
	else
		target = nil
	end

	-- First-time welcome for brand-new players.
	if not shownWelcome then
		shownWelcome = true
		if ((State.Data.Stats or {}).TotalPops or 0) == 0 then
			UI.ShowWelcome(true)
		end
	end
end

-- Per-frame visuals for the marker, trail and edge arrow.
local function updateVisuals()
	local pos = playerPosition()
	if not target or not pos or State.Engaged then
		hideWorldGuide()
		return
	end
	local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	local dist = flat.Magnitude
	if dist < 12 then
		hideWorldGuide() -- you have arrived; the prompt takes over
		return
	end

	local now = os.clock()
	markerPart.Parent = workspace.Guide
	markerPart.Position = target + Vector3.new(0, 9 + math.sin(now * 3) * 0.8, 0)
	markerLabel.Text = ("%s\n%d m"):format(targetLabel, math.floor(dist))

	local dir = flat.Unit
	local usable = math.min(CRUMBS, math.floor((dist - 10) / CRUMB_SPACING))
	for i, c in crumbs do
		if i <= usable then
			c.Position = Vector3.new(pos.X, 1.6, pos.Z) + dir * (CRUMB_SPACING * i + 4)
			-- A bright pulse runs down the trail toward the target.
			local phase = (now * 1.6 - i * 0.16) % 1
			c.Transparency = 0.1 + 0.85 * phase
		else
			c.Transparency = 1
		end
	end

	local camera = workspace.CurrentCamera
	local view, onScreen = camera:WorldToViewportPoint(markerPart.Position)
	if onScreen and view.Z > 0 then
		edgeArrow.Visible = false
		edgeDistance.Visible = false
		return
	end
	local size = camera.ViewportSize
	local cx, cy = size.X / 2, size.Y / 2
	local dx, dy = view.X - cx, view.Y - cy
	if view.Z < 0 then
		dx, dy = -dx, -dy -- target is behind the camera: flip so the arrow points the short way round
	end
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 1e-3 then
		dx, dy, len = 0, -1, 1
	end
	dx, dy = dx / len, dy / len
	local tx = (cx - 70) / math.max(math.abs(dx), 1e-3)
	local ty = (cy - 110) / math.max(math.abs(dy), 1e-3)
	local t = math.min(tx, ty)
	local px, py = cx + dx * t, cy + dy * t
	edgeArrow.Position = UDim2.fromOffset(px, py)
	edgeArrow.Rotation = math.deg(math.atan2(dx, -dy))
	edgeArrow.Visible = true
	edgeDistance.Position = UDim2.fromOffset(px, py + 28)
	edgeDistance.Text = ("%d m"):format(math.floor(dist))
	edgeDistance.Visible = true
end

function Guide.Init()
	build()
	State.Changed.Event:Connect(refreshObjective)

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= 0.3 then
			since = 0
			refreshObjective()
		end
		updateVisuals()
	end)
end

return Guide
