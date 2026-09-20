# Asset Registry

Source for all entries: Roblox Creator Store API (`apis.roblox.com/toolbox-service/v1`), found with
`tools/asset-search/audio_search.py`. Filters applied from API metadata: audio type SoundEffect, free, approved and
publicly visible, no scripts flag, short duration, no album/foreign artist, franchise-name blocklist.

**Verification status for all audio below:** metadata verified via API on 2026-09-21. **Not yet listened to** and
**in-experience playback not yet confirmed**: run the game and look for `[Audio] ... OK/FAILED` in Output.
Audio contains no scripts. License: listed as free on the Creator Store; no separate license text was reviewed.

| Cue | Asset ID | Name | Creator | Length | Search terms | Fallback |
|---|---|---|---|---|---|---|
| Pop | 111044884172919 | Crystal Break | jmlopes08 | 2s | crystal break, glass shatter | silent (id = nil) |
| Place | 87437544236708 | UI - Click 1 | SodaBreadle | 1s | ui click | silent |
| Detonate | 138533090376585 | Explosion Blast Impact Boom | 0FFZ3TI | 3s | explosion | silent |
| Tier | 4612374036 | bling_big_diamond_pickup | thienbao2109 | 2s | success chime, achievement | silent |
| Reward | 135483737426662 | Coin Collect | G00byBBQSauce | 1s | coin collect | silent |
| Click | 139804904213958 | ui_menu_click_03 | Vicktor2012 | 1s | ui click | silent |
| Error | 16903690359 | warning beep | DjDan_123 | 1s | error buzz, denied | silent |

Used in: `src/ReplicatedStorage/Shared/Config/Sounds.luau`. To swap a sound, change its `Id` there and update this table.

Also used (not an external asset): `rbxasset://textures/particles/sparkles_main.dds`, built into the Roblox client.
