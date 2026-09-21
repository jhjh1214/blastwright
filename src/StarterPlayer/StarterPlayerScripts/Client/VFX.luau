--!nonstrict
-- Pooled particle bursts plus lightweight ring/beam effects. Purely cosmetic: every call is safe to fail.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local VFX = {}

local TEXTURE = "rbxasset://textures/particles/sparkles_main.dds" -- built into the Roblox client
local MAX_EMITTERS = 24

local folder = Instance.new("Folder")
folder.Name = "VFX"
folder.Parent = workspace

local free = {}
local total = 0

local function newEmitter()
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2

	local e = Instance.new("ParticleEmitter")
	e.Texture = TEXTURE
	e.Enabled = false
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 3
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = part
	part.Parent = folder
	total += 1
	return { Part = part, Emitter = e }
end

-- Small radial burst. count is kept low for mobile.
function VFX.Burst(position, color, count, speed)
	pcall(function()
		local item = table.remove(free)
		if not item then
			if total >= MAX_EMITTERS then
				return -- pool exhausted: drop the effect rather than allocate
			end
			item = newEmitter()
		end
		item.Part.Position = position
		item.Emitter.Color = ColorSequence.new(color)
		item.Emitter.Speed = NumberRange.new(speed * 0.5, speed)
		item.Emitter:Emit(count)
		task.delay(1, function()
			table.insert(free, item)
		end)
	end)
end

-- Expanding flat ring (shockwave).
function VFX.Ring(position, color, maxDiameter, duration)
	pcall(function()
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.25
		ring.Size = Vector3.new(0.3, 1, 1)
		ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = folder
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(ring, info, { Size = Vector3.new(0.3, maxDiameter, maxDiameter), Transparency = 1 }):Play()
		Debris:AddItem(ring, duration + 0.1)
	end)
end

-- Thin glowing line between two points (prism beams).
function VFX.Beam(a, b, color, width)
	pcall(function()
		local dist = (b - a).Magnitude
		if dist < 0.1 then
			return
		end
		local beam = Instance.new("Part")
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = color
		beam.Size = Vector3.new(width, width, dist)
		beam.CFrame = CFrame.lookAt((a + b) / 2, b)
		beam.Parent = folder
		TweenService:Create(beam, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.05, 0.05, dist) }):Play()
		Debris:AddItem(beam, 0.4)
	end)
end

-- CRITICAL MASS grade: the whole screen warms up and gets punchier while it lasts (uses the cave's own colour correction).
local criticalOn = false
local savedGrade = nil
function VFX.SetCritical(on)
	if on == criticalOn then
		return
	end
	criticalOn = on
	pcall(function()
		local Lighting = game:GetService("Lighting")
		local TweenService = game:GetService("TweenService")
		local cc = Lighting:FindFirstChild("CaveGrade")
		if not cc then
			return
		end
		if on then
			savedGrade = { Tint = cc.TintColor, Saturation = cc.Saturation, Contrast = cc.Contrast }
			TweenService:Create(cc, TweenInfo.new(0.5), { TintColor = Color3.fromRGB(255, 225, 170), Saturation = cc.Saturation + 0.25, Contrast = cc.Contrast + 0.12 }):Play()
		elseif savedGrade then
			TweenService:Create(cc, TweenInfo.new(0.8), { TintColor = savedGrade.Tint, Saturation = savedGrade.Saturation, Contrast = savedGrade.Contrast }):Play()
		end
	end)
end

return VFX
