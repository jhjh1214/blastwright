--!nonstrict
-- Drifting glow motes around the player, tinted by the area you are in. One cheap emitter that follows the character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("Shared").Config).World

local Ambience = {}

function Ambience.Init()
	local part = Instance.new("Part")
	part.Name = "AmbientMotes"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(80, 1, 80)
	part.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 16
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Speed = NumberRange.new(0.3, 1.1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.28)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.9
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 190, 255))
	emitter.Parent = part

	local lastArea = ""
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		part.Position = root.Position + Vector3.new(0, 9, 0)

		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		local area = WorldConfig.AreaName(root.Position.X, root.Position.Z)
		if area ~= lastArea then
			lastArea = area
			local color = Color3.fromRGB(150, 190, 255)
			for _, b in WorldConfig.Biomes do
				if b.Name == area then
					color = Color3.fromRGB(b.Color[1], b.Color[2], b.Color[3])
				end
			end
			emitter.Color = ColorSequence.new(color)
		end
	end)
end

return Ambience
