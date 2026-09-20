--!nonstrict
-- Central audio playback with per-group volume. Missing/failed sounds never affect gameplay.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local AudioManager = {}
local groups = {}
local pool = {}

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

return AudioManager
