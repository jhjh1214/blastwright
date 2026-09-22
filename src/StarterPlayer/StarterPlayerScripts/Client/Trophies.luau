--!nonstrict
-- The hub trophy hall: a pedestal per boss west of the plaza. Before your first kill the boss stands as a dark silhouette
-- with "???"; after it, the model glows on its pedestal with your personal kill count. Purely a local view of the save
-- snapshot (State.Data.Collection.Bosses); it holds no logic and any failure just leaves the hall empty.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local State = require(script.Parent.State)
local Creatures = require(script.Parent.Creatures)
local Theme = require(script.Parent.Theme)

local Trophies = {}

local ORDER = { "Titan", "Warden" }
local SPACING = 26
local MODEL_SCALE = 0.55
-- The hub plaza (Server/World.luau buildHub: a 0.6-thick disc centred at Y=0.15) has its walkable top at Y=0.45. Every
-- part here is built relative to GROUND, stacked upward with real clearance, so nothing clips into or floats off the
-- plaza regardless of small mismatches — the earlier version placed things by guesswork and both boards ended up
-- partly buried.
local GROUND = 0.45
local PEDESTAL_H, RING_H = 0.8, 0.4
local PEDESTAL_TOP = GROUND + PEDESTAL_H + RING_H -- where a statue's feet should land
-- Creatures.Build makes a model centred on its own origin (see CavernView.luau's GROUND table): this is how far below
-- that origin each kind's feet sit, so a statue's feet actually meet the pedestal instead of floating or sinking.
local STATUE_LIFT = { Titan = 4, Warden = 8 }

local stands = {}

local function part(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, true, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function sign(parent, cf)
	local board = part(parent, Vector3.new(9, 3.2, 0.4), cf, Color3.fromRGB(26, 18, 40), Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font.Display
	label.TextSize = 40
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextWrapped = true
	label.Text = "???"
	label.Parent = gui
	return label
end

local function paint(stand, found, kills, name)
	stand.Label.Text = found and string.format("%s\nSlain x%d", name, kills) or "???\nUndefeated"
	for _, d in stand.Model:GetDescendants() do
		if d:IsA("BasePart") then
			if found then
				d.Color = d:GetAttribute("TrueColor") or d.Color
				d.Transparency = d:GetAttribute("TrueTransparency") or d.Transparency
			else
				d.Color = Color3.fromRGB(20, 18, 30)
				d.Transparency = 0
			end
		end
	end
end

local function refresh()
	local col = State.Data and State.Data.Collection
	if not col or not col.Bosses then
		return
	end
	for _, entry in col.Bosses do
		local stand = stands[entry.Id]
		if stand then
			paint(stand, entry.Found, entry.Kills, entry.Name)
		end
	end
end

function Trophies.Init()
	local hub = Config.World.Hub
	local folder = Instance.new("Folder")
	folder.Name = "TrophyHall"
	folder.Parent = workspace
	local center = Vector3.new(hub.X - 34, GROUND, hub.Z + 4)
	for i, kind in ORDER do
		local at = center + Vector3.new(0, 0, (i - 1.5) * SPACING) -- at.Y = GROUND: every offset below is measured up from here
		part(folder, Vector3.new(PEDESTAL_H, 14, 14), CFrame.new(at + Vector3.new(0, PEDESTAL_H / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 62, 96), Enum.Material.Slate, Enum.PartType.Cylinder)
		part(folder, Vector3.new(RING_H, 11, 11), CFrame.new(at + Vector3.new(0, PEDESTAL_H + RING_H / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 202, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
		local model = Creatures.Build(kind)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("TrueColor", d.Color)
				d:SetAttribute("TrueTransparency", d.Transparency)
				d.Anchored, d.CanCollide, d.CanQuery = true, false, false
			end
		end
		model:ScaleTo(MODEL_SCALE)
		model:PivotTo(CFrame.new(at + Vector3.new(0, (PEDESTAL_TOP - GROUND) + STATUE_LIFT[kind] * MODEL_SCALE, 0)) * CFrame.Angles(0, math.rad(90), 0))
		model.Parent = folder
		-- The sign stands on its own small post so it never depends on guessing the model's height: post foot at GROUND,
		-- board comfortably above it.
		local postHeight = 2.4
		part(folder, Vector3.new(0.5, postHeight, 0.5), CFrame.new(at + Vector3.new(8, postHeight / 2, 0)), Color3.fromRGB(40, 36, 54), Enum.Material.Metal)
		local signAt = at + Vector3.new(8, postHeight + 1.6, 0)
		local label = sign(folder, CFrame.lookAt(signAt, signAt + Vector3.new(1, 0, 0)))
		stands[kind] = { Model = model, Label = label }
		paint(stands[kind], false, 0, kind)
	end
	State.Changed.Event:Connect(function(what)
		if what == "Data" then
			pcall(refresh)
		end
	end)
	pcall(refresh)
end

return Trophies
