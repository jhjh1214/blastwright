# CLAUDE.md

## Project
**Blastwright** is a PvE Roblox game: plant charges in crystal caverns, detonate, and plan chain reactions for shards. Concept approved 2026-09-21. Design: `docs/GAME_DESIGN.md`. Architecture: `docs/TECHNICAL_ARCHITECTURE.md`.

## Status (update this section as work lands)
- Done and unit-tested (255 tests, three charge types): `ChainSim`, `Seam`, `Schema`, `Validate`.
- Runs in Studio (developer-confirmed) but has no automated tests and only a first smoke run: `Game`, `Data`, `World`, all Client modules.
- Developer confirmed on 2026-09-21 that the game runs in Studio and shows the cavern and UI (after the lazy-DataStore fix). Developer reported it "feels very good" (2026-09-21); audio playback not explicitly confirmed.
- Audio: 7 SFX cues wired from Creator Store results (`tools/asset-search`); **unheard, playback unconfirmed** until Output shows `[Audio] ... OK`.
- Explorable mine (hub, 4 biomes, 16 blast pads, 22 geode caches, terrain, lighting) and the reworked HUD are written and compile-checked; **not yet seen in Studio**. Save schema is v2 (`Caches`).
- Daily objectives (3 per UTC day, claim in the Daily button) and the monetization framework (`Purchases.luau`, `Receipts.luau`, `Config/Products.luau`, Shop tab) are written and unit-tested where pure; **unseen in Studio, no product IDs exist**. **Economy rebalanced from tools/sim: all sink prices and reward tables x5, and crystal spawn weights lowered so chains are not trivially supercritical; docs/ECONOMY.md has the measured pacing.** Server Goal co-op feature (pure logic tested, broadcasting unseen). Every remote is rate-limited and audited (docs/SECURITY.md); launch steps in docs/LAUNCH_CHECKLIST.md. Live events calendar (`Config/Events.luau`, pure logic tested). Developer feedback 2026-09-21: game feels too fast, dailies/weeklies too easy and too rewarding; balancing is deferred to last, see docs/BALANCE_BACKLOG.md. Save schema is v6 (`Daily`, `Weekly`, `Achievements`, `Cosmetics`).
- Real decor models (8, Creator Store, thumbnails viewed) load via `Server/Props.luau` with script-stripping and procedural fallbacks; a looping cave ambience bed and an 11-track shuffled classical playlist (APMOfficial) are wired. Playtest 2026-09-21: all audio OK, music volume and mood approved by the developer, **all 8 props load (8/8; inventory step done)**. Pads are round with rock rims, crystals sit on lumpy rocks with jitter/turn/size (developer has not confirmed this fixed the grid look). Developer feedback after that: crystals radiated too much light (fixed: matte shards, darkened accents, lower bloom; switches in Tuning) and the planting/chain preview was unclear (rewritten: cell dots, hover ghost with blast area, coloured chain links via new `SX/SZ` event sources, crystal info line). Developer feedback after that: HUD text covered the grid middle, no grid outline, could not see where a charge would go (hover ghost was under the rocks). Fixed by: camera reserves HUD space (`CameraFeedback` TOP/BOTTOM_RESERVE), one compact text block, hint pill replaced by a pulsing Detonate outline, overlay redrawn with always-on-top `BoxHandleAdornment`s (grid outline, lattice, gold hover cell, exact blast cells via `ChainSim.BlastCells`). Crystal brightness and the organic grid look were confirmed good by the developer. The new overlay/camera/HUD are unseen so far. Latest playtest: everything looked good but the camera was far above the grid (fixed: 60 deg FOV, 55 deg tilt, tighter fit, ~45% lower) and "Press E start blasting" showed while at the grid (fixed: proximity prompts disabled in blast mode). New since (all unseen): 23-24 milestone Goals (the Goals button); a 4th area, Echo Caverns (south road, 12,000 shards) with the Echostone relay crystal (world Bounds MaxZ now 350, 16 pads, 22 caches, set max players to 16); blast colors (7 cosmetic styles, most unlocked by claiming goals, Neon Pink is a shop product); client LOD that builds crystal models only for grids near the camera; a "Longest Chains" leaderboard board in the hub (pure ranking tested; the OrderedDataStore part needs a published game).
- Added after the "more to do than blast" feedback (all pure logic unit-tested and mutation-checked; server wiring and UI **unseen in Studio**): Expeditions (`Shared/Expedition.luau`, second "Begin Expedition" prompt on each pad), Daily Puzzle (`Shared/Puzzle.luau`, the Daily button), Crystal Farm (`Shared/Farm.luau`, the Farm button). Lurkers (hidden monsters, turn-based grid fights, rig hearts; `Shared/Lurker.luau`, docs/MONSTERS.md) add risk; the real-time boss arena is not built. Chain power + CRITICAL MASS (`Shared/Power.luau`) and the Crystal Titan boss (`Shared/Boss.luau`, floors 4 and 8 of an Expedition, docs/MONSTERS.md; a greedy-bot sim is in `tools/sim/boss.luau`) are built as turn-based grid fights, unseen in Studio. Expeditions now have room types, Chaos events and four relic families (see GAME_DESIGN). Collection log, boss mastery and wearable titles are built (`Shared/Mastery.luau`). Monetization ladder (boosts, revive and emergency-charge tokens, finishers, bundles, Club) is built from `Shared/Grants.luau` with all product ids still nil (docs/MONETIZATION.md). Save schema is now v13. Direction from the developer (2026-09-21): combat must be built from the crystal system, replayable Expeditions (room types, relic builds), boss mastery, cosmetics and a monetization ladder come after the fun is proven; see docs/DEVELOPMENT_PLAN.md. Placeholders to balance are listed in docs/BALANCE_BACKLOG.md.
- Latest (all unseen in Studio): real-time boss attacks (`Shared/BossRT.luau`: slam / meteor / corruption on a clock, answered by crystal behaviours, dodge shield), a second boss (Prism Warden, floor 8), procedural creature models (`Creatures.luau`), UI polish (`Fx.luau`, `ShopArt.luau`), a planning read that shows what a volley does to Lurkers, bosses and their wound-up attacks (`Boss.Estimate` / `BossRT.Simulate`, parity-tested), live chain milestones, onboarding steps toward Expeditions and the first boss, and expedition/bounty income cut after `tools/sim/expedition.luau` showed it was ~9x mining. Working style and rules are in the memory folder and docs/BALANCE_BACKLOG.md.
- UI is now one chunky design system (docs/TESTING.md E17): `Theme.luau` (tokens), `Kit.luau` (components), `Icons.luau` (icons drawn in code, no asset ids), `Dock.luau` (side stack + SHOP), `Feed.luau`, `BossHud.luau`, `ShopArt.luau`. New UI must use Kit/Theme, not raw frames. Unseen in Studio.
- Also new, unseen: hub trophy hall (`Client/Trophies.luau`), combat-linked daily/weekly objectives (Slays, Critical), docs/PUBLISH_GUIDE.md. TESTING.md section E18.
- Not started: mobile testing.
- Stratum 3 (Slowburn delayed-fuse crystal) added and unit-tested; its visuals, fuse flash and Codex entry are **not yet seen in Studio**.
- Playtest 2026-09-21: world build died on an invalid `SurfaceGui` property (fixed; API checker added). Lighting/crystal glow retuned after "too dark / too bright" feedback; guide system (objective card, marker, trail, edge arrow, welcome panel) added. **Both unseen in Studio.**
- Next: developer runs the first full playtest (docs/TESTING.md), then follows docs/PUBLISH_GUIDE.md (the single ordered list of every manual step: balance, publish, products, assets, presentation).

## Environment (Windows, PowerShell)
Rojo 7.7.0 (`C:\Tools\Rojo`), Git, Node, Python. Asset search: `python tools/asset-search/audio_search.py <cue> <max_secs> <keywords...>`. Luau CLI/analyzer/compiler are in `tools/bin` (git-ignored; re-download from the luau-lang GitHub release if missing). Roblox Studio is installed but cannot be driven by Claude.

## Commands
- Tests: `tools/bin/luau.exe tools/tests/core.spec.luau`
- Syntax check a file: `tools/bin/luau-compile.exe --text <file>`
- Asset search: `tools/asset-search/audio_search.py` (`--min=`, `--allow-music`, `--library` for partner-library music; `gen_music.py` regenerates Config/Music.luau) and `model_search.py <out.png> <keywords>` (renders a thumbnail sheet to LOOK at before choosing).
- **Roblox API name check (run before claiming Roblox-facing code is done):** `python tools/lint/roblox_api_check.py`. Needs `tools/bin/API-Dump.json` (git-ignored; see docs/TESTING.md).
- Build: `rojo build -o "$env:TEMP\gamev1.rbxl"`
- Live sync: `rojo serve`

## Architecture rules
- Rojo is the source of truth. No logic lives only in Studio.
- Pure logic (`ChainSim`, `Seam`, `Schema`, `Validate`, `Config/*`) uses no Roblox APIs so the CLI tests can load it. ChainSim takes config via a `ctx` argument; do not add `require(script...)` to these files.
- Content is data: crystals, charges, upgrades and strata are in `Config/*`. Behaviors live in `ChainSim`.
- Server is authoritative. Clients send intents only (`Detonate` cells, `Buy` ids). Validate every remote argument with a pure function and test it with hostile inputs.
- Crystal visuals are built client-side from grid data (`CavernView`); the server holds no crystal Parts.
- Optional systems (VFX, audio, UI effects) must never break gameplay: wrap in `pcall`, skip on missing config.

## Conventions
- Luau, tabs, `--!strict` for pure modules, `--!nonstrict` for Roblox-facing ones. Files are `.luau`; `init.server.luau` / `init.client.luau` for entry scripts.
- Write files as UTF-8 **without BOM** (PowerShell 5.1 `Set-Content -Encoding utf8` adds a BOM and breaks Rojo). Prefer the Write tool.
- Conventional Commits. Attribution is the user alone: no Co-Authored-By or tool mentions.

## Assets
Never invent an asset or product ID. Use the Creator Store / Marketplace APIs, inspect and strip scripts, record in `docs/ASSET_REGISTRY.md`. If unverifiable, build procedural.

## Monetization / DataStore
Purchases only via `ProcessReceipt` (`Server/Purchases.luau`, idempotent via `Receipts.Apply`). Product IDs stay `nil` in `Config/Products.luau` until the developer supplies them; never invent one. Save data: `Schema.luau` versioned; bump `CURRENT_VERSION` and add a migration for any schema change.

## Known issues / risks
- The whole roaming world and new UI are unrun. Older systems were only smoke-tested in Studio: multi-player, mobile layout, seam end/regen, purchases in Forge and persistence are unverified.
- Fun is unproven: the risk is "click and wait". Fix gameplay before adding content.
- Preview may make planning too easy; Seismograph gating is a first mitigation.
- Audio picks are metadata-only guesses. Visuals are procedural Parts placeholder quality.
- Economy numbers are paper math.
