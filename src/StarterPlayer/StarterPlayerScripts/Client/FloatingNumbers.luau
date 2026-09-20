--!nonstrict
-- Pooled world-space floating text (values, multipliers, warnings).
local TweenService = game:GetService("TweenService")

local FloatingNumbers = {}

local folder = Instance.new("Folder")
folder.Name = "FloatingNumbers"
folder.Parent = workspace

local free = {}
local FONT = Enum.Font.GothamBlack

local function acquire()
	local item = table.remove(free)
	if item then
		return item
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 44)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = part
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = gui

	part.Parent = folder
	return { Part = part, Label = label }
end

-- scale: 1 = normal, larger for big multipliers.
function FloatingNumbers.Show(position, text, color, scale)
	pcall(function()
		local item = acquire()
		scale = scale or 1
		item.Part.Position = position
		item.Label.Text = text
		item.Label.TextColor3 = color
		item.Label.TextTransparency = 0
		item.Label.TextStrokeTransparency = 0.35
		item.Label.Size = UDim2.fromScale(0.6 * scale, 0.6 * scale)
		item.Label.Position = UDim2.fromScale((1 - 0.6 * scale) / 2, (1 - 0.6 * scale) / 2)

		local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(item.Part, info, { Position = position + Vector3.new(0, 4, 0) }):Play()
		TweenService:Create(item.Label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(0.85, function()
			table.insert(free, item)
		end)
	end)
end

return FloatingNumbers
