--!nonstrict
-- Central audio playback with per-group volume. Missing/failed sounds never affect gameplay.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local AudioManager = {}
local groups = {}
local pool = {}
local loops = {} -- [cueName] = { Sound = Sound, Base = number }
local duckFactor = 1

local GROUP_VOLUME = { Music = 0.5, Ambient = 0.5, Ui = 0.7, Sfx = 0.8, Reward = 0.9 }

local function group(name)
	if groups[name] then
		return groups[name]
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = GROUP_VOLUME[name] or 0.8
	g.Parent = SoundService
	groups[name] = g
	return g
end

-- Starts every looping cue (ambience) with a slow fade-in. Safe to call once at startup; skips cues without an Id.
function AudioManager.StartLoops()
	for name, cue in Sounds do
		if cue.Loop and cue.Id and not loops[name] then
			local ok = pcall(function()
				local s = Instance.new("Sound")
				s.Name = "Loop_" .. name
				s.SoundId = cue.Id
				s.Looped = true
				s.Volume = 0
				s.SoundGroup = group(cue.Group)
				s.Parent = SoundService
				s:Play()
				loops[name] = { Sound = s, Base = cue.Volume }
				TweenService:Create(s, TweenInfo.new(4), { Volume = cue.Volume * duckFactor }):Play()
			end)
			if not ok then
				warn("[Audio] could not start loop " .. name)
			end
		end
	end
end

-- Lower (or restore) the looping beds. factor 1 = normal, 0.4 = quieter. Used when entering/leaving blast mode.
function AudioManager.Duck(factor)
	duckFactor = factor
	for _, loop in loops do
		TweenService:Create(loop.Sound, TweenInfo.new(0.8), { Volume = loop.Base * factor }):Play()
	end
end

-- opts: { Pitch = number?, Volume = number? }
function AudioManager.Play(cueName, opts)
	local ok = pcall(function()
		local cue = Sounds[cueName]
		if not cue or not cue.Id then
			return
		end
		local s = table.remove(pool)
		if not s then
			s = Instance.new("Sound")
			s.Ended:Connect(function()
				table.insert(pool, s)
			end)
		end
		s.SoundId = cue.Id
		s.Volume = (opts and opts.Volume) or cue.Volume
		s.PlaybackSpeed = (opts and opts.Pitch) or 1
		s.SoundGroup = group(cue.Group)
		s.Parent = SoundService
		s:Play()
	end)
	if not ok then
		warn("[Audio] failed to play " .. tostring(cueName))
	end
end

-- Preloads every cue and logs whether Roblox can load it in this experience. Purely diagnostic.
function AudioManager.Verify()
	local ContentProvider = game:GetService("ContentProvider")
	local probes = {}
	for name, cue in Sounds do
		if cue.Id then
			local s = Instance.new("Sound")
			s.Name = name
			s.SoundId = cue.Id
			table.insert(probes, s)
		end
	end
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(probes, function(contentId, status)
			local label = status == Enum.AssetFetchStatus.Success and "OK" or ("FAILED (" .. tostring(status) .. ")")
			print(("[Audio] %s -> %s"):format(contentId, label))
		end)
	end)
	if not ok then
		warn("[Audio] verify failed: " .. tostring(err))
	end
	for _, s in probes do
		s:Destroy()
	end
end

return AudioManager
