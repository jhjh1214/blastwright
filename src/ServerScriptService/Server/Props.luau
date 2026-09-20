--!nonstrict
-- Loads third-party decor models safely and places scaled copies.
-- Security: a loaded model is rebuilt keeping ONLY visual geometry (parts, meshes, textures, attachments).
-- Scripts, sounds, remotes, prompts, click detectors, particles, lights, GUIs etc. are destroyed and counted.
-- Nothing from these models ever runs. If a load fails, callers get nil and use procedural decor instead.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Props = {}

local prototypes = {}

local KEEP = { Model = true, Folder = true, Attachment = true, Texture = true, Decal = true, SurfaceAppearance = true }

local function allowed(inst)
	return inst:IsA("BasePart") or inst:IsA("DataModelMesh") or KEEP[inst.ClassName] == true
end

-- Destroys everything that is not plain visual geometry. Returns (removedTotal, removedScripts).
local function sanitize(root)
	local removed, scripts = 0, 0
	for _, descendant in root:GetDescendants() do
		if not allowed(descendant) then
			if descendant:IsA("LuaSourceContainer") then
				scripts += 1
			end
			removed += 1
			descendant:Destroy()
		end
	end
	return removed, scripts
end

local function loadOne(key, def, folder)
	local ok, container = pcall(function()
		return InsertService:LoadAsset(def.Id)
	end)
	if not ok or not container then
		warn(("[Props] %s (%d) could not be loaded: %s. Using procedural fallback."):format(key, def.Id, tostring(container)))
		return
	end

	local model = Instance.new("Model")
	model.Name = key
	for _, child in container:GetChildren() do
		child.Parent = model
	end
	container:Destroy()

	local removed, scripts = sanitize(model)
	if not model:FindFirstChildWhichIsA("BasePart", true) then
		warn(("[Props] %s (%d) has no geometry after sanitizing. Using procedural fallback."):format(key, def.Id))
		model:Destroy()
		return
	end

	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end

	-- Pivot at the bottom center so placing on the ground is trivial; remember the native height for scaling.
	local cf, size = model:GetBoundingBox()
	if size.Y < 0.05 then
		warn(("[Props] %s (%d) has no usable height. Using procedural fallback."):format(key, def.Id))
		model:Destroy()
		return
	end
	model.WorldPivot = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
	model:SetAttribute("NativeHeight", size.Y)
	model.Parent = folder
	prototypes[key] = model
	print(("[Props] %s loaded (native height %.1f; removed %d non-visual objects, %d scripts)"):format(key, size.Y, removed, scripts))
end

-- Loads every configured prop in parallel. Never throws; missing props simply are not available.
function Props.Load()
	local folder = ServerStorage:FindFirstChild("PropPrototypes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PropPrototypes"
		folder.Parent = ServerStorage
	end

	local pending, total = 0, 0
	for key, def in Config.Props.Defs do
		total += 1
		pending += 1
		task.spawn(function()
			local ok, err = pcall(loadOne, key, def, folder)
			if not ok then
				warn(("[Props] %s failed unexpectedly: %s"):format(key, tostring(err)))
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end

	local available = 0
	for _ in prototypes do
		available += 1
	end
	print(("[Props] %d/%d props available; the rest use procedural fallbacks"):format(available, total))
end

function Props.Has(key)
	return prototypes[key] ~= nil
end

-- Places a scaled copy standing on `position`. height is the target height in studs. tint (Color3) recolors
-- every part and makes it Neon (used for the grey crystal meshes). Returns the model, or nil on any failure.
function Props.Place(key, position, height, yaw, tint, parent)
	local proto = prototypes[key]
	if not proto then
		return nil
	end
	local ok, clone = pcall(function()
		local copy = proto:Clone()
		copy:ScaleTo(math.clamp(height / proto:GetAttribute("NativeHeight"), 0.02, 200))
		copy:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw or 0, 0))
		if tint then
			for _, d in copy:GetDescendants() do
				if d:IsA("BasePart") then
					d.Color = tint
					d.Material = Enum.Material.Neon
				end
			end
		end
		copy.Parent = parent
		return copy
	end)
	if ok then
		return clone
	end
	return nil
end

return Props
