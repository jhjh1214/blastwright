--!strict
-- Sound cues. Every Id below was returned by the Creator Store API and passed tools/asset-search filters;
-- see docs/ASSET_REGISTRY.md. Cues with Id = nil are silently skipped by AudioManager.
-- IMPORTANT: chosen from metadata only (nobody has listened yet) and playback in-experience is checked at
-- runtime by AudioManager.Verify (look for "[Audio]" lines in the Output window).
export type Cue = { Id: string?, Group: string, Volume: number }

return {
	Pop = { Id = "rbxassetid://111044884172919", Group = "Sfx", Volume = 0.5 }, -- "Crystal Break"
	Place = { Id = "rbxassetid://87437544236708", Group = "Ui", Volume = 0.6 }, -- "UI - Click 1"
	Detonate = { Id = "rbxassetid://138533090376585", Group = "Sfx", Volume = 0.9 }, -- "Explosion Blast Impact Boom"
	Tier = { Id = "rbxassetid://4612374036", Group = "Reward", Volume = 0.8 }, -- "bling_big_diamond_pickup"
	Reward = { Id = "rbxassetid://135483737426662", Group = "Reward", Volume = 0.7 }, -- "Coin Collect"
	Click = { Id = "rbxassetid://139804904213958", Group = "Ui", Volume = 0.5 }, -- "ui_menu_click_03"
	Error = { Id = "rbxassetid://16903690359", Group = "Ui", Volume = 0.5 }, -- "warning beep"
} :: { [string]: Cue }
