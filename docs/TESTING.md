# Testing

## Automated (runs outside Studio)
```
tools/bin/luau.exe tools/tests/core.spec.luau
```
`tools/bin` is git-ignored; it holds the Luau CLI, analyzer and compiler (v0.739, from the luau-lang GitHub release).

**Covered (75 tests, plus a developer smoke run in Studio that showed the cavern and UI):** chain propagation, ordering, bounds, amplifier, unstable, prism/column shapes, tiers, momentum, radius bonus, determinism and grid immutability, seed/stratum generation, save-schema migration/sanitizing, and hostile Detonate payloads, the delayed-fuse crystal (timing, multiplier cash-in, follow-on blast, stratum gating), the world layout (sites/caches unique, in bounds, off roads and each other), area names, the v1 to v2 save migration, the objective/guide logic, daily objectives (deterministic rotation, progress rules, claim rules, day reset, reward scaling), purchase idempotency and bounded history, product config validity, Prismatic Luck spawn chance, the v3 save migration, prop config validity, sound config validity, the music playlist config, the settings validator, round-pad geometry (grid corners fit, station on the rim, clearance), chain sources (which cell set each crystal off: charges, chains, beams, delayed blasts, shaft charges), blast cell targeting (`ChainSim.BlastCells`: shapes, distances, clipping at the grid edge), goals (config validity and reachability, where each stat is read from, claim rules, the client view, v4 migration, objective nudge), and the Echostone relay (far links, timing, sources, independence from table layout) plus the fourth area (sites, spawn gating), cosmetics (ownership derived from goals and purchases, equipping rules, fallback, view, v5 migration), and cosmetic products (every shop style is buyable, receipts grant it idempotently).

**Mutation-tested:** removing the unstable multiplier, amplifier bonus, volatile propagation, tier bonus, bounds check, the validator's unlock/duplicate/charges-left checks, and the delayed-crystal delay/blast/Lit logic each fails the suite. One mutant (the redundant `dead[key]` re-check in the pop loop) survives because it is logically redundant, not because of a test gap.

Also run: `luau-compile --text <file>` on every `.luau` (syntax), `rojo build`, and
```
python tools/lint/roblox_api_check.py
```
which checks every Roblox property, method, enum and service name against the official API dump (`tools/bin/API-Dump.json`, download `https://setup.rbxcdn.com/<studio version>-API-Dump.json`). It exists because `luau-compile` cannot see wrong Roblox API names: a bad `SurfaceGui` property once silently killed the world build. Verified against 9 seeded errors of every kind it claims to catch.

## NOT covered by any automated test
`Game.luau` (site reservation, rewards, seam end, caches, daily wiring), `Purchases.luau` (`ProcessReceipt`, gamepass checks), `Props.luau` (model loading and sanitizing), music/ambience playback and the sound switches, `World.luau` terrain and prop building, `Data.luau` (DataStore, locking, retries, shutdown), `World.luau`, and every client module (rendering, UI, input, camera, playback). These are compile-checked only.

## Manual Studio checklist (developer)
1. `rojo serve`, connect the plugin in Studio, press Play. Expect a few seconds of loading, then spawn on the hub plaza (no errors in Output).
2. Walk down the west road to a Glimmer Shallows pad; use its station. Expect the camera to lift over the grid and movement to lock. Plant, Detonate, watch the cascade; shards count up. "Leave" (or X) returns you to free roaming.
3. Clear a seam or run out of charges: expect a toast and a new seam after ~3s.
3b. Walk to a Prism Veins or Ember Hollows pad before unlocking: expect a "locked" toast. Find a geode cache off the road: expect a shard reward, "n/22 found", and the cache to go dull.
4. Open Forge: buy an upgrade; check shards drop and Lv rises. Open Codex.
5. Test with 2 players (Test tab, 2 players): each has their own cavern and can see the other's.
6. Stop and play again: in Studio the profile is volatile, so progress will not persist (expected; see output warning). Real persistence requires "Enable Studio Access to API Services" and a published place.
7. Emulate a phone (Device emulator): check the layout, tap targets, and that the whole grid is visible in portrait.
8. Report anything odd from the Output window.
