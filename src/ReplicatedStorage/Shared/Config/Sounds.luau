--!strict
-- Sound cues. `Id` stays nil until a sound is found, verified and recorded in docs/ASSET_REGISTRY.md.
-- AudioManager silently skips cues with no Id, so the game runs with or without audio.
export type Cue = { Id: string?, Group: string, Volume: number }

return {
	Pop = { Id = nil, Group = "Sfx", Volume = 0.5 },
	Place = { Id = nil, Group = "Ui", Volume = 0.6 },
	Detonate = { Id = nil, Group = "Sfx", Volume = 0.9 },
	Tier = { Id = nil, Group = "Reward", Volume = 0.8 },
	Reward = { Id = nil, Group = "Reward", Volume = 0.7 },
	Click = { Id = nil, Group = "Ui", Volume = 0.5 },
	Error = { Id = nil, Group = "Ui", Volume = 0.5 },
} :: { [string]: Cue }
