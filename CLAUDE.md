# CLAUDE.md

## Project
**Blastwright** is a PvE Roblox game: plant charges in crystal caverns, detonate, and plan chain reactions for shards. Concept approved 2026-09-21. Design: `docs/GAME_DESIGN.md`. Architecture: `docs/TECHNICAL_ARCHITECTURE.md`.

## Status (update this section as work lands)
- Done and unit-tested (21 tests): `ChainSim`, `Seam`, `Schema`, `Validate`.
- Runs in Studio (developer-confirmed) but has no automated tests and only a first smoke run: `Game`, `Data`, `World`, all Client modules.
- Developer confirmed on 2026-09-21 that the game runs in Studio and shows the cavern and UI (after the lazy-DataStore fix). Developer reported it "feels very good" (2026-09-21); audio playback not explicitly confirmed.
- Audio: 7 SFX cues wired from Creator Store results (`tools/asset-search`); **unheard, playback unconfirmed** until Output shows `[Audio] ... OK`.
- Not started: monetization, external visual assets, music/ambience, mobile testing, world/hub, daily retention.
- Stratum 3 (Slowburn delayed-fuse crystal) added and unit-tested; its visuals, fuse flash and Codex entry are **not yet seen in Studio**.
- Next: developer checks stratum 3 in Studio (needs 4000 shards, or temporarily lower `Strata[3].Cost`), then visual assets.

## Environment (Windows, PowerShell)
Rojo 7.7.0 (`C:\Tools\Rojo`), Git, Node, Python. Asset search: `python tools/asset-search/audio_search.py <cue> <max_secs> <keywords...>`. Luau CLI/analyzer/compiler are in `tools/bin` (git-ignored; re-download from the luau-lang GitHub release if missing). Roblox Studio is installed but cannot be driven by Claude.

## Commands
- Tests: `tools/bin/luau.exe tools/tests/core.spec.luau`
- Syntax check a file: `tools/bin/luau-compile.exe --text <file>`
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
Purchases only via `ProcessReceipt` (not built). Product IDs stay `nil` in config until supplied. Save data: `Schema.luau` versioned; bump `CURRENT_VERSION` and add a migration for any schema change.

## Known issues / risks
- Only smoke-tested in Studio: multi-player, mobile layout, seam end/regen, purchases in Forge and persistence are unverified.
- Fun is unproven: the risk is "click and wait". Fix gameplay before adding content.
- Preview may make planning too easy; Seismograph gating is a first mitigation.
- Audio picks are metadata-only guesses. Visuals are procedural Parts placeholder quality.
- Economy numbers are paper math.
