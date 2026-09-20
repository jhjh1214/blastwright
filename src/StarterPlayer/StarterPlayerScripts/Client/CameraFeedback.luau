--!nonstrict
-- Fixed top-down camera over the player's cavern, plus shake and FOV punch for impact.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraFeedback = {}

local BASE_FOV = 60
-- Screen space (pixels) kept free of the grid: the top holds the shard counter and the planning text, the bottom
-- the charge and Detonate buttons. The grid is fitted into what is left, so the HUD never covers it.
local TOP_RESERVE = 124
local BOTTOM_RESERVE = 80
local PITCH = math.rad(55) -- lower tilt = camera nearer the floor and crystals look more three-dimensional
local focus = nil -- { Center = Vector3, Extent = number }
local shake = 0
local punch = 0

function CameraFeedback.Focus(center, extent)
	focus = { Center = center, Extent = extent }
end

-- Return control to Roblox's default follow camera.
function CameraFeedback.Clear()
	focus = nil
	shake, punch = 0, 0
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function CameraFeedback.Shake(amount)
	shake = math.max(shake, math.min(amount, 1.2))
end

function CameraFeedback.Punch(degrees)
	punch = math.max(punch, math.min(degrees, 10))
end

function CameraFeedback.Start()
	RunService:BindToRenderStep("BlastwrightCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		if not camera or not focus then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = BASE_FOV + punch

		-- Fit the whole grid on screen for any aspect ratio (portrait phones need more distance).
		local view = camera.ViewportSize
		local aspect = view.X / math.max(view.Y, 1)
		local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
		local half = focus.Extent * 0.56 -- half the grid plus a little for the crystals
		local top = GuiService:GetGuiInset().Y + TOP_RESERVE
		local usableH = math.max(view.Y - top - BOTTOM_RESERVE, view.Y * 0.35)
		local usableW = math.max(view.X - 24, 100)
		-- Vertically the tilted grid looks shorter (by sin(pitch)); horizontally it is full width.
		local dist = math.max(half * math.sin(PITCH) / (tanV * usableH / view.Y), half / (tanV * aspect * usableW / view.X))

		local dir = Vector3.new(0, math.sin(PITCH), -math.cos(PITCH))
		local cf = CFrame.lookAt(focus.Center + dir * dist, focus.Center)
		-- Slide the view so the grid sits in the free band between the HUD rows (moving the camera up moves the scene down).
		local pixelsDown = (top + usableH / 2) - view.Y / 2
		cf = cf * CFrame.new(0, pixelsDown / view.Y * 2 * tanV * dist, 0)

		if shake > 0.001 then
			local a = shake
			cf = cf * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * a * 0.02)
		end
		camera.CFrame = cf

		local decay = math.exp(-dt * 8)
		shake *= decay
		punch *= decay
	end)
end

return CameraFeedback
