--!nonstrict
-- Tap/click to plant charges on the cavern grid; buttons and keys to detonate or clear.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Geometry = require(Shared.Geometry)
local Remotes = require(Shared.Remotes)

local AudioManager = require(script.Parent.AudioManager)
local Blasting = require(script.Parent.Blasting)
local CavernView = require(script.Parent.CavernView)
local Preview = require(script.Parent.Preview)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Input = {}
local sending = false

local function chargesAvailable()
	return State.Data and State.Data.ChargesLeft or 0
end

local function cellFromScreen(view, position)
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	if ray.Direction.Y >= -1e-4 then
		return nil, nil
	end
	local t = (view.Origin.Y - ray.Origin.Y) / ray.Direction.Y
	return Geometry.WorldToCell(view.Origin, ray.Origin + ray.Direction * t)
end

local function cellFromRay(view, ray)
	if ray.Direction.Y >= -1e-4 then
		return nil, nil
	end
	local t = (view.Origin.Y - ray.Origin.Y) / ray.Direction.Y
	return Geometry.WorldToCell(view.Origin, ray.Origin + ray.Direction * t)
end

local function toggleCharge(x, z)
	for i, c in State.Placed do
		if c.X == x and c.Z == z then
			table.remove(State.Placed, i)
			AudioManager.Play("Click")
			return
		end
	end
	if #State.Placed >= math.min(chargesAvailable(), Config.Tuning.MaxVolleyCharges) then
		UI.Toast("No charges left to plant", "Error")
		return
	end
	table.insert(State.Placed, { X = x, Z = z, Kind = State.SelectedCharge })
	AudioManager.Play("Place")
end

local function onTap(position)
	local view = CavernView.Get(State.UserId)
	if not view or not State.Engaged or State.Busy or State.PanelOpen or not State.Data or (State.Run and State.Run.Phase ~= "Blasting") then
		return
	end
	local x, z = cellFromScreen(view, position)
	if not x then
		return
	end
	toggleCharge(x, z)
	Preview.SetHover(x, z, true) -- on touch screens the last tapped cell acts as the hover cell
	State.Changed:Fire("Placed")
end

local function detonate()
	if sending or State.Busy or #State.Placed == 0 or (State.Run and State.Run.Phase ~= "Blasting") then
		return
	end
	sending = true
	local volley = {}
	for _, c in State.Placed do
		table.insert(volley, { X = c.X, Z = c.Z, Kind = c.Kind })
	end
	Remotes.Detonate:FireServer(volley)
	task.delay(0.4, function()
		sending = false
	end)
end

local function clear()
	if State.Busy then
		return
	end
	table.clear(State.Placed)
	State.Changed:Fire("Placed")
end

function Input.Init()
	UI.OnDetonate = detonate
	UI.OnClear = clear
	UI.OnLeave = Blasting.Leave

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			onTap(Vector2.new(input.Position.X, input.Position.Y))
		elseif State.Engaged and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return) then
			detonate()
		elseif State.Engaged and input.KeyCode == Enum.KeyCode.Backspace then
			clear()
		elseif State.Engaged and input.KeyCode == Enum.KeyCode.X then
			Blasting.Leave()
		end
	end)

	-- Mouse hover: show where a charge would go and what it would cover (touch has no hover; taps set it instead).
	if UserInputService.MouseEnabled then
		RunService.RenderStepped:Connect(function()
			if not State.Engaged or State.Busy or State.PanelOpen then
				return
			end
			local view = CavernView.Get(State.UserId)
			local camera = workspace.CurrentCamera
			if not view or not camera then
				return
			end
			local location = UserInputService:GetMouseLocation()
			local x, z = cellFromRay(view, camera:ViewportPointToRay(location.X, location.Y))
			Preview.SetHover(x, z)
		end)
	end

	State.Changed.Event:Connect(function(what)
		if what == "Placed" or what == "Charge" or what == "Data" then
			Preview.Refresh()
			UI.Refresh()
		end
	end)
end

return Input
