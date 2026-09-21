--!nonstrict
-- Central audio playback with per-group volume. Missing/failed sounds never affect gameplay.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local MusicConfig = require(ReplicatedStorage.Shared.Config.Music)

local AudioManager = {}
local groups = {}
local pool = {}
local loops = {} -- [cueName] = { Sound = Sound, Base = number }
local duckFactor = 1
local intensity = 0 -- 0 calm, 1 boss fight or Critical Mass, 2 both: the music gets louder and a little higher
local pitchEffect = nil
local musicEnabled = true
local sfxEnabled = true
local musicStarted = false
local currentMusic = nil

local GROUP_VOLUME = { Music = 0.5, Ambient = 0.5, Ui = 0.7, Sfx = 0.8, Reward = 0.9 }

-- Music and Ambient follow the Music switch; everything else follows the Effects switch.
local function groupVolume(name)
	local on = (name == "Music" or name == "Ambient") and musicEnabled or ((name ~= "Music" and name ~= "Ambient") and sfxEnabled)
	return on and (GROUP_VOLUME[name] or 0.8) or 0
end

local function group(name)
	if groups[name] then
		return groups[name]
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = groupVolume(name)
	g.Parent = SoundService
	groups[name] = g
	return g
end

-- kind: "Music" (music + ambience) or "Sfx" (effects, UI, rewards).
function AudioManager.SetEnabled(kind, on)
	if kind == "Music" then
		musicEnabled = on
	elseif kind == "Sfx" then
		sfxEnabled = on
	else
		return
	end
	for name, g in groups do
		TweenService:Create(g, TweenInfo.new(0.4), { Volume = groupVolume(name) }):Play()
	end
end

local function musicTarget()
	return MusicConfig.Volume * (0.5 + 0.5 * duckFactor) * (1 + 0.15 * intensity)
end

-- Plays one track with a fade in; schedules its own fade out and cleanup. Returns seconds until the next track
-- should start (so tracks overlap by the crossfade), or nil if the track could not be loaded.
local function playTrack(track)
	local fade = MusicConfig.CrossfadeSeconds
	local ok, waitFor = pcall(function()
		local s = Instance.new("Sound")
		s.Name = "Music"
		s.SoundId = track.Id
		s.Volume = 0
		s.SoundGroup = group("Music")
		s.Parent = SoundService
		local t0 = os.clock()
		while not s.IsLoaded and os.clock() - t0 < 12 do
			task.wait(0.2)
		end
		if not s.IsLoaded or s.TimeLength <= 0 then
			s:Destroy()
			return nil
		end
		local pitch = Instance.new("PitchShiftSoundEffect")
		pitch.Octave = 1 + 0.05 * intensity -- a pitch lift that does not change the speed, so track timing stays right
		pitch.Parent = s
		pitchEffect = pitch
		s:Play()
		currentMusic = s
		TweenService:Create(s, TweenInfo.new(fade), { Volume = musicTarget() }):Play()
		local length = s.TimeLength
		task.delay(math.max(length - fade, 1), function()
			TweenService:Create(s, TweenInfo.new(fade), { Volume = 0 }):Play()
			task.delay(fade + 0.3, function()
				if currentMusic == s then
					currentMusic = nil
				end
				s:Destroy()
			end)
		end)
		return math.max(length - fade, 1)
	end)
	if ok and waitFor then
		return waitFor
	end
	warn("[Audio] music track skipped: " .. track.Name)
	return nil
end

-- Shuffled, endlessly looping playlist with crossfades. Tracks that fail to load are skipped.
function AudioManager.StartMusic()
	if musicStarted or #MusicConfig.Tracks == 0 then
		return
	end
	musicStarted = true
	task.spawn(function()
		local rng = Random.new()
		local order, index, last = {}, math.huge, nil
		while true do
			if index > #order then
				order = table.clone(MusicConfig.Tracks)
				for i = #order, 2, -1 do
					local j = rng:NextInteger(1, i)
					order[i], order[j] = order[j], order[i]
				end
				if last and #order > 1 and order[1] == last then
					order[1], order[2] = order[2], order[1] -- never repeat the same track back to back
				end
				index = 1
			end
			local track = order[index]
			index += 1
			last = track
			local waitFor = playTrack(track)
			task.wait(waitFor or 1)
		end
	end)
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
	if currentMusic then
		TweenService:Create(currentMusic, TweenInfo.new(0.8), { Volume = musicTarget() }):Play()
	end
end

-- Turn the music up for danger: 0 calm, 1 a boss fight or Critical Mass, 2 both. Safe to call every sync.
function AudioManager.SetIntensity(level)
	level = math.clamp(level or 0, 0, 2)
	if level == intensity then
		return
	end
	intensity = level
	if currentMusic then
		TweenService:Create(currentMusic, TweenInfo.new(0.6), { Volume = musicTarget() }):Play()
	end
	if pitchEffect and pitchEffect.Parent then
		TweenService:Create(pitchEffect, TweenInfo.new(0.6), { Octave = 1 + 0.05 * intensity }):Play()
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
	for i, track in MusicConfig.Tracks do
		local s = Instance.new("Sound")
		s.Name = "Music" .. i
		s.SoundId = track.Id
		table.insert(probes, s)
	end
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
