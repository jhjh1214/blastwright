--!nonstrict
-- The Crystal Colossus in the world: a huge hovering Titan over the hub plaza while the world boss is up, flashing when it
-- takes damage and fading out when it falls or leaves. Display only (the server owns the fight; see Shared/WorldBoss.luau).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TweenService = game:GetService("TweenService")

local Creatures = require(script.Parent.Creatures)

local WorldBossView = {}

local model, lastHP = nil, nil

local function remove()
	if model then
		local old = model
		model, lastHP = nil, nil
		for _, d in old:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			end
		end
		task.delay(1.4, function()
			old:Destroy()
		end)
	end
end

function WorldBossView.Show(view)
	if not view or not view.Active then
		remove()
		return
	end
	if not model then
		local hub = Config.World.Hub
		model = Creatures.Build("Titan")
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
			end
		end
		model:ScaleTo(3.2)
		model:PivotTo(CFrame.new(hub.X, 26, hub.Z + 34))
		model.Name = "WorldBossColossus"
		model.Parent = workspace
		task.spawn(function()
			local mine = model
			local t = 0
			while model == mine and mine.Parent do
				t += task.wait()
				mine:PivotTo(CFrame.new(hub.X, 26 + math.sin(t * 0.8) * 2, hub.Z + 34) * CFrame.Angles(0, math.rad(200), 0))
			end
		end)
	end
	if lastHP and view.HP and view.HP < lastHP then
		pcall(Creatures.Flash, model, Color3.fromRGB(255, 240, 200))
	end
	lastHP = view.HP
end

return WorldBossView
