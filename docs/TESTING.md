# Testing

## Automated (runs outside Studio)
```
tools/bin/luau.exe tools/tests/core.spec.luau
```
`tools/bin` is git-ignored; it holds the Luau CLI, analyzer and compiler (v0.739, from the luau-lang GitHub release).

**Covered (87 tests, plus a developer smoke run in Studio that showed the cavern and UI):** chain propagation, ordering, bounds, amplifier, unstable, prism/column shapes, tiers, momentum, radius bonus, determinism and grid immutability, seed/stratum generation, save-schema migration/sanitizing, and hostile Detonate payloads, the delayed-fuse crystal (timing, multiplier cash-in, follow-on blast, stratum gating), the world layout (sites/caches unique, in bounds, off roads and each other), area names, the v1 to v2 save migration, the objective/guide logic, daily objectives (deterministic rotation, progress rules, claim rules, day reset, reward scaling), purchase idempotency and bounded history, product config validity, Prismatic Luck spawn chance, the v3 save migration, prop config validity, sound config validity, the music playlist config, the settings validator, round-pad geometry (grid corners fit, station on the rim, clearance), chain sources (which cell set each crystal off: charges, chains, beams, delayed blasts, shaft charges), blast cell targeting (`ChainSim.BlastCells`: shapes, distances, clipping at the grid edge), goals (config validity and reachability, where each stat is read from, claim rules, the client view, v4 migration, objective nudge), and the Echostone relay (far links, timing, sources, independence from table layout) plus the fourth area (sites, spawn gating), cosmetics (ownership derived from goals and purchases, equipping rules, fallback, view, v5 migration), cosmetic products (every shop style is buyable, receipts grant it idempotently), goal announcements (reported once, silent at join, several at once in config order), the leaderboard ranking and text (ordering, tie-breaks in every arrival order, junk rows, truncation), the screen-shake setting (validated key, default on, old saves filled in), and weekly challenges (Monday-aligned week boundaries and countdown, rising and harder-than-daily targets and rewards, v6 migration, objective nudge).

**Mutation-tested:** removing the unstable multiplier, amplifier bonus, volatile propagation, tier bonus, bounds check, the validator's unlock/duplicate/charges-left checks, and the delayed-crystal delay/blast/Lit logic each fails the suite. One mutant (the redundant `dead[key]` re-check in the pop loop) survives because it is logically redundant, not because of a test gap.

Also run: `luau-compile --text <file>` on every `.luau` (syntax), `rojo build`, and
```
python tools/lint/roblox_api_check.py
```
which checks every Roblox property, method, enum and service name against the official API dump (`tools/bin/API-Dump.json`, download `https://setup.rbxcdn.com/<studio version>-API-Dump.json`). It exists because `luau-compile` cannot see wrong Roblox API names: a bad `SurfaceGui` property once silently killed the world build. Verified against 9 seeded errors of every kind it claims to catch.

## NOT covered by any automated test
`Game.luau` (site reservation, rewards, seam end, caches, daily wiring), `Purchases.luau` (`ProcessReceipt`, gamepass checks), `Leaderboard.luau` (OrderedDataStore reads/writes and the hub board), `Props.luau` (model loading and sanitizing), music/ambience playback and the sound switches, `World.luau` terrain and prop building, `Data.luau` (DataStore, locking, retries, shutdown), `World.luau`, and every client module (rendering, UI, input, camera, playback). These are compile-checked only.

## Manual Studio checklist (developer)
Everything below was written without being run in Studio (the automated tests cover only the pure logic). Run `rojo serve`, connect the Rojo plugin in a Baseplate place, press Play, and tick through in order. Paste any Output errors or oddities back to Claude.

### A. Startup (Output window)
1. No red errors. Expected lines: `[Data] DataStore unavailable in Studio ... volatile profile` (normal unpublished), `[Props] 8/8 props available`, one `[Audio] ... -> OK` per sound and per music track (about 19).
2. No `World build failed`, no `optional system '...' failed to start`. A leaderboard warning about DataStore access is normal unpublished.
3. World loads in a few seconds, you spawn on the hub plaza. Lighting is bright enough, crystals are not glaring.

### B. Getting around
4. Welcome panel shows for a new profile; "Let's go" closes it; "?" reopens it and shows Music / Effects / Shake switches.
5. Objective card says to walk to a blast pad; a gold marker with distance, a glowing dot trail and (when off-screen) an edge arrow lead there.
6. Four biomes off the hub: Shallows (west), Prism Veins (east), Ember Hollows (north), Echo Caverns (south, needs the new southern road). Signposts at the hub name them.
7. Hub leaderboard board is beside the spawn (shows "Unavailable" until the game is published; that is expected).
8. Music plays (cheerful classical), cave ambience underneath. Music and Effects switches work and persist after Stop/Play only when the game is published (volatile profile otherwise).

### C. Blasting
9. Use a Shallows pad station: camera lifts CLOSE over a round pad, movement locks, no "Start blasting" prompt is visible. HUD text sits above the grid, not on it; corner buttons at the bottom.
10. Grid outline and faint lines visible. Hover a cell (PC) or tap (mobile): gold outline, and the exact blasted cells are tinted. Crystal info line appears.
11. Plant charges (Blasting Cap; unlock Shaft Charge later for the strip), press Detonate (or Space): cascade with sounds, numbers, chain lines; tier banner on big chains; Momentum toast at 10+ pops.
12. Gold links appear only with the Seismograph upgrade (900 shards); without it only white direct hits.
13. Leave button (top right) or X returns you to walking, camera returns to normal.
14. Clear a seam or run out of charges: toast, new seam after about 3 seconds.

### D. Economy and menus (Menu button, top right)
15. Forge: buy upgrades (Deep Satchel, Fat Fuse, Momentum Coil, Seismograph), unlock Shaft Charge (400), unlock areas (1,200 / 4,000 / 12,000). Locked pads show a "locked" toast.
16. Daily tab: three objectives with progress; weekly challenges below; Claim pays out; red dot on Menu when something is claimable.
17. Goals tab (24): progress bars, claim; a "Goal ready" toast appears the moment one completes.
18. Shop tab: everything says "Not for sale yet" (no product IDs exist). Nothing crashes.
19. Codex tab: crystals appear as you discover them (7 kinds); Blast colors section: Classic equipped; others locked with a hint ("Claim the goal: ..."); claiming that goal unlocks it and Equip works; your planting markers and blast rings change color.
20. Geode caches (22) hidden off the roads: crack open once each, reward + "n/22", then the cache goes dull.

### E. New mechanics
21. Slowburn (area 3): fuse flash, pops about a second later at your peak multiplier.
22. Echostone (area 4): popping one sets off every other Echostone on the grid; a long line shows the jump. (To reach these quickly, temporarily lower `Cost` in `Config/Strata.luau` and/or `Config/Tuning`, then restore.)

### F. Multi-player and phones (Test > 2 players, and the Device emulator)
23. Two players use different pads and see each other's grids and blasts (distant grids appear only when you are near: level of detail). A pad in use is labelled "In use". Walking 130+ studs away for a minute releases it.
24. Phone-size window (for example 390 x 844): top bar (shards, Menu, ?) does not overlap; the Menu panel's 5 tabs fit; the grid is fully visible in the free band; buttons are tappable; text readable.

### G. Publishing-only (do these last, see MANUAL_ACTIONS.md)
25. Save persistence, the leaderboard, product prompts, and 2x Shards / Prismatic Luck can only be verified in a published place.
