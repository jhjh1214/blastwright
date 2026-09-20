--!nonstrict
-- Shows geode caches you have already looted as dull and non-interactive. Server still enforces one loot per player.
local CollectionService = game:GetService("CollectionService")

local State = require(script.Parent.State)

local CacheView = {}

local function apply(model)
	local id = model:GetAttribute("CacheId")
	local claimed = State.Data ~= nil and State.Data.Caches ~= nil and State.Data.Caches[id] == true
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = not claimed
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = not claimed
		elseif d:IsA("PointLight") then
			d.Enabled = not claimed
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			d.Transparency = claimed and 0.85 or 0
		end
	end
end

function CacheView.Init()
	for _, model in CollectionService:GetTagged("Cache") do
		apply(model)
	end
	CollectionService:GetInstanceAddedSignal("Cache"):Connect(apply)
	State.Changed.Event:Connect(function(what)
		if what == "Data" then
			for _, model in CollectionService:GetTagged("Cache") do
				apply(model)
			end
		end
	end)
end

return CacheView
