--!strict
-- Builds the static world shell (ground, lighting, spawn) from code so Rojo remains the source of truth.
local Lighting = game:GetService("Lighting")

local World = {}

local function ensure(class: string, name: string, parent: Instance): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == class then
		return existing
	end
	local inst = Instance.new(class)
	inst.Name = name
	inst.Parent = parent
	return inst
end

function World.Init()
	-- Cave lighting: dark, cool ambient so crystals carry the color.
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(28, 32, 48)
	Lighting.OutdoorAmbient = Color3.fromRGB(28, 32, 48)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = false

	local bloom = ensure("BloomEffect", "CaveBloom", Lighting) :: BloomEffect
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.6

	local cc = ensure("ColorCorrectionEffect", "CaveGrade", Lighting) :: ColorCorrectionEffect
	cc.Saturation = 0.15
	cc.Contrast = 0.1
	cc.TintColor = Color3.fromRGB(235, 240, 255)

	local atmo = ensure("Atmosphere", "CaveAtmosphere", Lighting) :: Atmosphere
	atmo.Density = 0.25
	atmo.Color = Color3.fromRGB(35, 40, 70)
	atmo.Decay = Color3.fromRGB(20, 22, 40)

	-- Ground plane so nothing falls into the void.
	local ground = ensure("Part", "Ground", workspace) :: Part
	ground.Anchored = true
	ground.Size = Vector3.new(4000, 2, 600)
	ground.Position = Vector3.new(0, -1.5, 0)
	ground.Material = Enum.Material.Slate
	ground.Color = Color3.fromRGB(24, 27, 36)

	local spawn = ensure("SpawnLocation", "Spawn", workspace) :: SpawnLocation
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, 0.5, -90)
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
end

return World
