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
	local center = Vector3.new(hub.X - 34, 0, hub.Z + 4)
	for i, kind in ORDER do
		local at = center + Vector3.new(0, 0, (i - 1.5) * SPACING)
		part(folder, Vector3.new(0.8, 14, 14), CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 62, 96), Enum.Material.Slate, Enum.PartType.Cylinder)
		part(folder, Vector3.new(0.4, 11, 11), CFrame.new(at + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 202, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
		local model = Creatures.Build(kind)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("TrueColor", d.Color)
				d:SetAttribute("TrueTransparency", d.Transparency)
				d.Anchored, d.CanCollide, d.CanQuery = true, false, false
			end
		end
		model:ScaleTo(MODEL_SCALE)
		model:PivotTo(CFrame.new(at + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, math.rad(90), 0))
		model.Parent = folder
		local signAt = at + Vector3.new(8, 1.8, 0)
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
