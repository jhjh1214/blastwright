--!nonstrict
-- Blast pad labels and prompts, per player. The server writes each pad's shared status ("Free", "In use: ...") into the
-- station's Status attribute; here it is combined with what THIS player has unlocked: pads in areas you have not unlocked
-- say LOCKED with the price, and their prompt offers to unlock the area with E (the server buys it if it is the next area
-- and you can afford it). Display only: the server decides everything.
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local State = require(script.Parent.State)

local SiteLabels = {}

local function commas(n)
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function apply(station)
	local stratum = station:GetAttribute("Stratum") or 1
	local unlocked = State.Data and State.Data.StrataUnlocked or 1
	local status = station:GetAttribute("Status") or "Free"
	local gui = station:FindFirstChildOfClass("BillboardGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	local prompts = {}
	for _, d in station:GetChildren() do
		if d:IsA("ProximityPrompt") then
			table.insert(prompts, d)
		end
	end
	local area = Config.Strata[stratum]
	local siteName = label and (string.match(label.Text, "^[^\n]*")) or ""
	if stratum > unlocked and area then
		if label then
			label.Text = siteName .. "\nLOCKED  -  press E to unlock\n" .. (stratum == unlocked + 1 and ("(" .. commas(area.Cost) .. " shards)") or ("(unlock " .. Config.Strata[unlocked + 1].Name .. " first)"))
			label.TextColor3 = Color3.fromRGB(255, 120, 120)
		end
		for _, p in prompts do
			if p.ActionText == "Start blasting" or p.ActionText == "Unlock area" then
				p.ActionText = "Unlock area"
				p.ObjectText = area.Name .. (stratum == unlocked + 1 and (" - " .. commas(area.Cost) .. " shards") or " (locked)")
			end
		end
	else
		if label then
			label.Text = siteName .. "\n" .. status
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
		for _, p in prompts do
			if p.ActionText == "Unlock area" then
				p.ActionText = "Start blasting"
				p.ObjectText = siteName
			end
		end
	end
end

function SiteLabels.Init()
	local function watch(station)
		apply(station)
		station:GetAttributeChangedSignal("Status"):Connect(function()
			apply(station)
		end)
	end
	for _, station in CollectionService:GetTagged("SiteStation") do
		watch(station)
	end
	CollectionService:GetInstanceAddedSignal("SiteStation"):Connect(watch)
	State.Changed.Event:Connect(function(what)
		if what == "Data" then
			for _, station in CollectionService:GetTagged("SiteStation") do
				pcall(apply, station)
			end
		end
	end)
end

return SiteLabels
