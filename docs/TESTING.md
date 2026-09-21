# Testing

## Automated (runs outside Studio)
```
tools/bin/luau.exe tools/tests/core.spec.luau
```
`tools/bin` is git-ignored; it holds the Luau CLI, analyzer and compiler (v0.739, from the luau-lang GitHub release).

**Covered (212 tests, plus a developer smoke run in Studio that showed the cavern and UI):** chain propagation, ordering, bounds, amplifier, unstable, prism/column shapes, tiers, momentum, radius bonus, determinism and grid immutability, seed/stratum generation, save-schema migration/sanitizing, and hostile Detonate payloads, the delayed-fuse crystal (timing, multiplier cash-in, follow-on blast, stratum gating), the world layout (sites/caches unique, in bounds, off roads and each other), area names, the v1 to v2 save migration, the objective/guide logic, daily objectives (deterministic rotation, progress rules, claim rules, day reset, reward scaling), purchase idempotency and bounded history, product config validity, Prismatic Luck spawn chance, the v3 save migration, prop config validity, sound config validity, the music playlist config, the settings validator, round-pad geometry (grid corners fit, station on the rim, clearance), chain sources (which cell set each crystal off: charges, chains, beams, delayed blasts, shaft charges), blast cell targeting (`ChainSim.BlastCells`: radius, column, row and cross shapes, distances, clipping at the grid edge), goals (config validity and reachability, where each stat is read from, claim rules, the client view, v4 migration, objective nudge), and the Echostone relay (far links, timing, sources, independence from table layout) plus the fourth area (sites, spawn gating), cosmetics (ownership derived from goals and purchases, equipping rules, fallback, view, v5 migration), cosmetic products (every shop style is buyable, receipts grant it idempotently), goal announcements (reported once, silent at join, several at once in config order), the leaderboard ranking and text (ordering, tie-breaks in every arrival order, junk rows, truncation), the Server Goal (target scaling and cap, single completion at the exact boundary, contributors, junk input, frenzy timing, new rounds, config sanity), the rate limiter (burst, refill, independence, clock safety), live events (Monday-based weekday, window edges, time left, combining effects, config validity), a balance guard (one charge must not clear the grid on average; chains must still happen), the screen-shake setting (validated key, default on, old saves filled in), and weekly challenges (Monday-aligned week boundaries and countdown, rising and harder-than-daily targets and rewards, v6 migration, objective nudge).

**Mutation-tested:** removing the unstable multiplier, amplifier bonus, volatile propagation, tier bonus, bounds check, the validator's unlock/duplicate/charges-left checks, and the delayed-crystal delay/blast/Lit logic each fails the suite. One mutant (the redundant `dead[key]` re-check in the pop loop) survives because it is logically redundant, not because of a test gap.

Also run: `luau-compile --text <file>` on every `.luau` (syntax), `rojo build`, and
```
python tools/lint/roblox_api_check.py
```
which checks every Roblox property, method, enum and service name against the official API dump (`tools/bin/API-Dump.json`, download `https://setup.rbxcdn.com/<studio version>-API-Dump.json`). It exists because `luau-compile` cannot see wrong Roblox API names: a bad `SurfaceGui` property once silently killed the world build. Verified against 9 seeded errors of every kind it claims to catch.

## NOT covered by any automated test
`Game.luau` (site reservation, rewards, seam end, caches, daily wiring), `Purchases.luau` (`ProcessReceipt`, gamepass checks), `Leaderboard.luau` (OrderedDataStore reads/writes and the hub board), `Props.luau` (model loading and sanitizing), music/ambience playback and the sound switches, `World.luau` terrain and prop building, `Data.luau` (DataStore, locking, retries, shutdown), `World.luau`, and every client module (rendering, UI, input, camera, playback). These are compile-checked only.

## Simulations (run any time)
- `tools/bin/luau.exe tools/sim/economy.luau -a 500 casual` (or `greedy`): plays a whole career with the real rules and prices; prints when each purchase happens.
- `tools/bin/luau.exe tools/sim/balance.luau -a <area 1-4> 30`: compares crystal-mix weight sets (pops per volley, how much of the grid is cleared, longest chain, shards per seam).
Both use blasting income only and a simple planner, so read them as pacing sanity checks.

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
19b. Live events: on a Saturday/Sunday, Wednesday or 18:00-19:00 UTC a gold banner appears under the Menu button. (To test any time, temporarily edit the weekday or hours in `Config/Events.luau`.) Prismatic Weekend should show noticeably more Prismatic crystals; Overcharge Wednesday gives +1 charge; Happy Hour raises blast payouts 1.5x.
19c. Server Goal: a right-hand line under the event banner shows "Server goal: n / target pops together". Blast until it fills: a "Server goal reached" toast pays you, and the line switches to a frenzy countdown. In a 2-player test both players' pops add to the same bar.
20. Geode caches (22) hidden off the roads: crack open once each, reward + "n/22", then the cache goes dull.

### E. New mechanics
21. Slowburn (area 3): fuse flash, pops about a second later at your peak multiplier.
22. Echostone (area 4): popping one sets off every other Echostone on the grid; a long line shows the jump. (To reach these quickly, temporarily lower `Cost` in `Config/Strata.luau` and/or `Config/Tuning`, then restore.)

### E2. Expeditions (unseen in Studio)
- At any unlocked pad station a second prompt "Begin Expedition" (hold F) appears above "Start blasting". Holding it starts floor 1 of 8 on that pad; the HUD shows "EXPEDITION floor n / 8, Haul, Relics" under the shard counter.
- Blast a floor. Shards do NOT go up while diving (they build the Haul). When charges run out or the grid is clear, a full-screen choice appears with three cards (route + relic) and a "Bank N shards & leave" button.
- Each card changes the next floor: Steady Vein +1 charge, Rich Vein x2 payouts but -1 charge, Rest Stop full refill; the relic (e.g. Resonant Core, Echo Chamber) should visibly change chain results and the planning preview should match the real payout.
- Bank: shards jump by haul x (1 + 0.15 x floors cleared) and you leave the pad (blast mode ends). Collapse (under half cleared and no charges): only 40% of the haul, toast "The tunnel collapsed". Clear floor 8: x1.5 bonus and the "Expedition complete" toast.
- Goals "Deep Diver" (depth) and "Expedition wins" progress. Tapping the grid or detonating while the cards show must do nothing. Using a different pad or "Start blasting" mid-run says "Finish or bank your expedition first."
- Known: leaving the pad mid-run forfeits the unbanked haul (idle release).

### E3. Daily Puzzle (unseen in Studio)
- Menu > Daily: a "Daily Puzzle" row with a Play button. Away from any pad: toast "Walk up to a free blast pad first". Standing at a pad: it starts (HUD explains: Basic charges only, ONE volley of up to 3).
- Everyone (test with 2 players) sees the identical grid; the charge picker is ignored (only Basic). Detonate: the chain plays, then a toast shows score vs par and the medal (Bronze 50% / Silver 80% / Gold 100% / Perfect 125% of par) with shards; the row now shows the medal and "already played".
- Streak: play on consecutive UTC days for +10% per day (max 7). Skipping a day resets it. Leaving the pad before detonating does not use the attempt.
- Puzzle results must NOT change pops/best chain/daily objectives (they are separate by design).

### E4. Crystal Farm (unseen in Studio)
- Menu > Farm tab (opening it refreshes the number). New/old saves start at level 1 producing 300 shards/hour, stored up to 8 hours, also while you are offline (rejoin after a while to see it). Collect adds shards; Upgrade collects first, then charges; the farm never pays for time before your first load after the update.
- Try: leave for 2+ minutes, reopen the tab, the store should show ~10 shards; collect; the store should read Empty.

### E5. Lurkers (hidden monsters, unseen in Studio; design in docs/MONSTERS.md)
- Blast several seams (about 1 in 8 in area 1). When a volley pops the secret crystal: toast "A Gnasher burst out of the rock!", a dark ball with name and health bar appears on that cell, the blast HUD (top-left) shows "Rig hearts" and the monster's HP.
- Fight: aim charges so their blast covers its cell (Basic 2, Shaft 3, Cross 3 damage; adjacent pops add splash). Each volley it then acts: Gnasher eats adjacent crystals (they vanish, toast) or walks; Sapper drains a charge; Brute smashes a heart every 2nd turn and the label warns "SMASH NEXT" a turn earlier.
- Kill it: toast with the bounty, the ball disappears, goals "Monster Hunter" etc. progress. Lose all 3 hearts: normal seam ends with "rig knocked out, repairs cost N" (no clear bonus); on an Expedition the run collapses. Expeditions heal one heart between floors.
- With the Seismograph upgrade the HUD says "Something stirs beneath the rocks..." while one hides. Without it there is no hint.
- Watch for: monster label positions above the grid, the planning preview ignoring the monster (it does not model it), hearts staying correct after an eaten-crystal turn, another player NOT seeing your monster (by design).

### E6. Boss + Critical Mass (unseen in Studio; design in docs/MONSTERS.md)
- Start an Expedition, clear floors 1-3 (bank if you like; to test faster raise Base charges). Floor 4: toast "BOSS: Crystal Titan!", a big dark body sits in the middle 3x3, gold markers on 4 crystals, a boss bar with a phase hint at the top.
- ARMOR: pop the gold nodes ("Armor node broken! N left"). Last one: phase toast "PHASE: ATTACK (+1 charge)", boss HP drops a little.
- ATTACK: red flat tiles mark a row/column every second turn. Test all three answers: (a) do nothing, the line's crystals vanish and you lose a heart; (b) plant charges so 3+ crystals on the red line pop, "cut": no damage, crystals stay; (c) press Dodge (button or Q) before detonating: "Dodged!", no heart lost, crystals still destroyed, button says recharging.
- WEAK: two magenta pillars. Hit one, then chain through both and compare damage in the boss bar (both should be much bigger).
- ENRAGE: two lines at once; body turns red. FINISHER: 12+ pops or a Critical Mass volley ends it; a smaller chain heals it slightly.
- Win: "Crystal Titan DEFEATED", bursts, rings, big camera punch, +6,000 to the haul, then the run continues (or bank). Lose all hearts or run out of charges/crystals: the Expedition collapses.
- Critical Mass: any chain of 15+ pops shows the CRITICAL MASS banner and a gold "CRITICAL MASS x2" HUD counter for two volleys with higher damage/shards. Watch for: camera punch too strong, label overlapping the boss bar, marker parts hidden under rocks, boss body blocking the hover ghost.
- Not built: boss-specific music intensity, the real-time arena, a boss outside Expeditions.

### E7. Expedition rooms, chaos and relics (unseen in Studio)
- Between floors each of the 3 cards now lists ROOM, ROUTE and RELIC (with family). Before floor 4 and floor 8 every card says "Boss Arena".
- Pick Lurker Nest: at floor start a Lurker is already out on the grid (toast "A Gnasher is awake!"), no waiting for a hidden one. Elite Lurker: it has visibly more health; killing it gives "ELITE REWARD: <family> relic gained" (check the Relics count in the top-left run label goes up, and an Iron Rig reward adds a heart, Deep Pockets a charge on the spot).
- Treasure Vault: payouts about double and more rainbow (Prismatic) crystals, no Lurker ever. Chaos Rift: toast "CHAOS RIFT: <name>" and the run label shows the event; Frenzy costs 2 charges (never below 1).
- Relics: Shockwave Core makes Lurker/boss damage bigger, Last Stand at exactly 1 heart, Second Wind refunds a charge on a kill, Focused Lens starts Critical Mass at 11 pops, Vampiric Sparks heals a heart when Critical Mass starts, Bounty Hunter doubles bounties but Lurkers are tougher.
- Also test the new Lurkers: a Skitter should cross two cells per turn and eat on arrival; a Leech should show "The Leech stole N shards!" after each volley until killed (your shard counter drops by that amount).
- Watch for: card text overflowing the 200x250 cards on a phone, an awake Lurker standing on a crystal that still shows, hearts/charges going out of sync after an Elite relic.

### E8. Collection, mastery and titles (unseen in Studio)
- Menu > Codex now continues below the blast colors with Lurkers (???, then name x kills after your first kill), Bosses, Relics found N/M, and Boss mastery rows.
- Beat the Titan and check the toasts "MASTERY: Flawless! Title unlocked: Untouchable (+6000 shards)". Try a win with no hearts lost, one in 8 or fewer volleys, a 20+ pop finisher, and one that ends on exactly 1 heart. Each objective pays only once.
- Wear a title from the Codex: it should float above your head (gold text) and other players should see it; "Remove" takes it off; it should reappear after respawn and after rejoining.
- Kill a Lurker and pick a relic card: their Codex rows should change from ??? to the name.

### F. Multi-player and phones (Test > 2 players, and the Device emulator)
23. Two players use different pads and see each other's grids and blasts (distant grids appear only when you are near: level of detail). A pad in use is labelled "In use". Walking 130+ studs away for a minute releases it.
24. Phone-size window (for example 390 x 844): top bar (shards, Menu, ?) does not overlap; the Menu panel's 5 tabs fit; the grid is fully visible in the free band; buttons are tappable; text readable.

### G. Publishing-only (do these last, see MANUAL_ACTIONS.md)
25. Save persistence, the leaderboard, product prompts, and 2x Shards / Prismatic Luck can only be verified in a published place.
