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
| Ambience (loop) | 273398061 | Cave Ambience | Texodus | 118s | cave ambience | silent (id = nil) |

Ambience note: uploader original (audio type "Unknown", artist = uploader, no album). Ducked to 45% while blasting.
**No music track is set.** Every long "Music"-typed result came from label/distributor accounts with albums, which the
strict filter rejects on purpose; a track you are licensed to use can be added as a `Music` cue.

Used in: `src/ReplicatedStorage/Shared/Config/Sounds.luau`. To swap a sound, change its `Id` there and update this table.

Also used (not an external asset): `rbxasset://textures/particles/sparkles_main.dds`, built into the Roblox client.

## Models (world decor)

Found with `tools/asset-search/model_search.py` (Creator Store API). Filters from API metadata: type Model, free,
hash-approved, `hasScripts == false`. **Each thumbnail was viewed** before selection (2026-09-21). Re-verified via the
API just before use. Loaded at runtime by `Server/Props.luau`, which keeps ONLY visual geometry (parts, meshes,
textures, attachments) and destroys everything else (scripts, sounds, remotes, prompts, particles, lights, GUIs),
logging the counts. Nothing from these models runs. If a load fails the world uses procedural decor.

**Verification status: metadata verified and thumbnails reviewed; in-experience loading NOT yet confirmed.** Check the
Output for `[Props] <name> loaded ...` lines and the summary `[Props] n/8 props available`.

| Key | Asset ID | Name | Creator | Use | Notes |
|---|---|---|---|---|---|
| CrystalA | 15618160671 | Crystal Cluster | kingOfcats9912828 | Decor crystals (tinted per biome, Neon) | Neutral grey mesh, so it can be tinted |
| CrystalB | 12882247457 | crystals6 | senya0079 | Decor crystals (tinted) | Second silhouette |
| Lamp | 17451005959 | lamp | metrox1223 | Road lamp posts (our own light attached) | Hanging lantern on a stone base |
| MushroomA | 2986139359 | Glowing Mushroom | CaptainOwlin | Cave flora | Cyan cap |
| MushroomB | 1532334716 | Glowing Mushroom | Chooonky | Cave flora | Cyan cap, thicker |
| StalagmiteA | 9687949418 | Stalagmite 1 | Jey_Jacule | Rock decor | Grey pillar |
| StalagmiteB | 10186366587 | stalagmite 2 | Firesquirrel777 | Rock decor | Dark spike |
| Crate | 182451181 | Wooden Crate | Quenty | Mining-depot props at stations and hub | |

Fallback for every model: procedural Parts (crystal shards, pole and neon head), or simply omitted (flora, crates).
License: listed as free on the Creator Store; no separate license text was reviewed.
