# Testing

## Automated (runs outside Studio)
```
tools/bin/luau.exe tools/tests/core.spec.luau
```
`tools/bin` is git-ignored; it holds the Luau CLI, analyzer and compiler (v0.739, from the luau-lang GitHub release).

**Covered (297 tests, plus a developer smoke run in Studio that showed the cavern and UI):** chain propagation, ordering, bounds, amplifier, unstable, prism/column shapes, tiers, momentum, radius bonus, determinism and grid immutability, seed/stratum generation, save-schema migration/sanitizing, and hostile Detonate payloads, the delayed-fuse crystal (timing, multiplier cash-in, follow-on blast, stratum gating), the world layout (sites/caches unique, in bounds, off roads and each other), area names, the v1 to v2 save migration, the objective/guide logic, daily objectives (deterministic rotation, progress rules, claim rules, day reset, reward scaling), purchase idempotency and bounded history, product config validity, Prismatic Luck spawn chance, the v3 save migration, prop config validity, sound config validity, the music playlist config, the settings validator, round-pad geometry (grid corners fit, station on the rim, clearance), chain sources (which cell set each crystal off: charges, chains, beams, delayed blasts, shaft charges), blast cell targeting (`ChainSim.BlastCells`: radius, column, row and cross shapes, distances, clipping at the grid edge), goals (config validity and reachability, where each stat is read from, claim rules, the client view, v4 migration, objective nudge), and the Echostone relay (far links, timing, sources, independence from table layout) plus the fourth area (sites, spawn gating), cosmetics (ownership derived from goals and purchases, equipping rules, fallback, view, v5 migration), cosmetic products (every shop style is buyable, receipts grant it idempotently), goal announcements (reported once, silent at join, several at once in config order), the leaderboard ranking and text (ordering, tie-breaks in every arrival order, junk rows, truncation), the Server Goal (target scaling and cap, single completion at the exact boundary, contributors, junk input, frenzy timing, new rounds, config sanity), the rate limiter (burst, refill, independence, clock safety), live events (Monday-based weekday, window edges, time left, combining effects, config validity), a balance guard (one charge must not clear the grid on average; chains must still happen), the screen-shake setting (validated key, default on, old saves filled in), and weekly challenges (Monday-aligned week boundaries and countdown, rising and harder-than-daily targets and rewards, v6 migration, objective nudge).

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
19b. Live events: on a Saturday/Sunday, Wednesday or 18:00-19:00 UTC a gold banner appears under the dock. (To test any time, temporarily edit the weekday or hours in `Config/Events.luau`.) Prismatic Weekend should show noticeably more Prismatic crystals; Overcharge Wednesday gives +1 charge; Happy Hour raises blast payouts 1.5x.
19c. Server Goal: a right-hand line under the event banner shows "Server goal: n / target pops together". Blast until it fills: a "Server goal reached" toast pays you, and the line switches to a frenzy countdown. In a 2-player test both players' pops add to the same bar.
20. Geode caches (22) hidden off the roads: crack open once each, reward + "n/22", then the cache goes dull.

### E. New mechanics
21. Slowburn (area 3): fuse flash, pops about a second later at your peak multiplier.
22. Echostone (area 4): popping one sets off every other Echostone on the grid; a long line shows the jump. (To reach these quickly, temporarily lower `Cost` in `Config/Strata.luau` and/or `Config/Tuning`, then restore.)

### E2. Expeditions (unseen in Studio)
- At any unlocked pad station a second prompt "Begin Expedition" (hold F) appears above "Start blasting". Holding it starts floor 1 of 8 on that pad; the HUD shows "EXPEDITION floor n / 8, Haul, Relics" under the shard counter.
- Blast a floor. Shards do NOT go up while diving (they build the Haul). When charges run out or the grid is clear, a full-screen choice appears with three cards (route + relic) and a "Bank N shards & leave" button.
- Each card changes the next floor: Steady Vein +1 charge, Rich Vein x2 payouts but -1 charge, Rest Stop full refill; the relic (e.g. Resonant Core, Echo Chamber) should visibly change chain results and the planning preview should match the real payout.
- Bank: shards jump by haul x (1 + 0.06 x floors cleared) and you leave the pad (blast mode ends). Collapse (under half cleared and no charges): only 40% of the haul, toast "The tunnel collapsed". Clear floor 8: x1.25 bonus and the "Expedition complete" toast.
- Goals "Deep Diver" (depth) and "Expedition wins" progress. Tapping the grid or detonating while the cards show must do nothing. Using a different pad or "Start blasting" mid-run says "Finish or bank your expedition first."
- Known: leaving the pad mid-run forfeits the unbanked haul (idle release).

### E3. Daily Puzzle (unseen in Studio)
- the Daily button: a "Daily Puzzle" row with a Play button. Away from any pad: toast "Walk up to a free blast pad first". Standing at a pad: it starts (HUD explains: Basic charges only, ONE volley of up to 3).
- Everyone (test with 2 players) sees the identical grid; the charge picker is ignored (only Basic). Detonate: the chain plays, then a toast shows score vs par and the medal (Bronze 50% / Silver 80% / Gold 100% / Perfect 125% of par) with shards; the row now shows the medal and "already played".
- Streak: play on consecutive UTC days for +10% per day (max 7). Skipping a day resets it. Leaving the pad before detonating does not use the attempt.
- Puzzle results must NOT change pops/best chain/daily objectives (they are separate by design).

### E4. Crystal Farm (unseen in Studio)
- the Farm button tab (opening it refreshes the number). New/old saves start at level 1 producing 300 shards/hour, stored up to 8 hours, also while you are offline (rejoin after a while to see it). Collect adds shards; Upgrade collects first, then charges; the farm never pays for time before your first load after the update.
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
- Win: "Crystal Titan DEFEATED", bursts, rings, big camera punch, +2,000 to the haul (4,000 for the Warden), then the run continues (or bank). Lose all hearts or run out of charges/crystals: the Expedition collapses.
- Critical Mass: any chain of 15+ pops shows the CRITICAL MASS banner and a gold "CRITICAL MASS x2" HUD counter for two volleys with higher damage/shards. Watch for: camera punch too strong, label overlapping the boss bar, marker parts hidden under rocks, boss body blocking the hover ghost.
- Music: during a boss fight or Critical Mass the music should get about 15% louder and a little higher in pitch (twice that with both), then relax afterwards. If the pitch effect sounds bad, the switch is `AudioManager.SetIntensity`.
- **Real-time attacks (replaces the old turn-based marking)**: after the armor breaks, red/orange/purple markers appear ON A TIMER with a live "SLAM 2.4" countdown that blinks faster as it nears, whether or not you fire. Test each answer: SLAM (pop 3+ crystals on the red line -> "Slam cut!", marker turns green), METEOR (needs a Lensglass popped: "Prism beam deflected", zone turns cyan), CORRUPTION (pop the purple-marked crystals -> "Purified"; unpopped ones turn into Dreadgeodes), and DODGE (Q or the button: "SHIELD UP" for ~1.2 s, then "Dodge 6s" counting down; a landing hit inside the window says "Shield! The hit was blocked", crystals still fall). Doing nothing should cost a heart per landed attack (Corruption costs crystals instead). Enrage should stack two attacks.
- Watch for: threats landing during a volley playback, the countdown text drifting from the real landing time (server clock vs your receive time), too little time to react on a phone, markers hidden under rocks, the Dodge label freezing.
- **Floor 8 is now a different boss, the Prism Warden** (a glassy tower with orbiting prisms): meteors from the start (bring/keep a Lensglass), corruption in the Weak phase, slams only in Enrage. Its mastery objectives (Unbroken, Prism Rush, Shatter) appear in Codex > Boss mastery.
- Not built: a free-roaming 3D arena (see docs/MONSTERS.md).

### E7. Expedition rooms, chaos and relics (unseen in Studio)
- Between floors each of the 3 cards now lists ROOM, ROUTE and RELIC (with family). Before floor 4 and floor 8 every card says "Boss Arena".
- Pick Lurker Nest: at floor start a Lurker is already out on the grid (toast "A Gnasher is awake!"), no waiting for a hidden one. Elite Lurker: it has visibly more health; killing it gives "ELITE REWARD: <family> relic gained" (check the Relics count in the top-left run label goes up, and an Iron Rig reward adds a heart, Deep Pockets a charge on the spot).
- Treasure Vault: payouts about double and more rainbow (Prismatic) crystals, no Lurker ever. Chaos Rift: toast "CHAOS RIFT: <name>" and the run label shows the event; Frenzy costs 2 charges (never below 1).
- Relics: Shockwave Core makes Lurker/boss damage bigger, Last Stand at exactly 1 heart, Second Wind refunds a charge on a kill, Focused Lens starts Critical Mass at 11 pops, Vampiric Sparks heals a heart when Critical Mass starts, Bounty Hunter doubles bounties but Lurkers are tougher.
- Also test the new Lurkers: a Skitter should cross two cells per turn and eat on arrival; a Leech should show "The Leech stole N shards!" after each volley until killed (your shard counter drops by that amount).
- Watch for: card text overflowing the 200x250 cards on a phone, an awake Lurker standing on a crystal that still shows, hearts/charges going out of sync after an Elite relic.

### E8. Collection, mastery and titles (unseen in Studio)
- the Codex button now continues below the blast colors with Lurkers (???, then name x kills after your first kill), Bosses, Relics found N/M, and Boss mastery rows.
- Beat the Titan and check the toasts "MASTERY: Flawless! Title unlocked: Untouchable (+6000 shards)". Try a win with no hearts lost, one in 8 or fewer volleys, a 20+ pop finisher, and one that ends on exactly 1 heart. Each objective pays only once.
- Wear a title from the Codex: it should float above your head (gold text) and other players should see it; "Remove" takes it off; it should reappear after respawn and after rejoining.
- Kill a Lurker and pick a relic card: their Codex rows should change from ??? to the name.

### E9. Boosts, tokens, revive, finishers, club and the new shop (unseen in Studio; no product IDs exist)
- the Shop button is now grouped: Club, Boosts and run support, Boss finishers, Bundles, Permanent perks, Blast colors, Shard packs. Every button says "Not for sale yet" and is disabled until IDs are pasted into `Config/Products.luau`.
- To test WITHOUT real products, temporarily grant yourself things in the command bar (server): `require(game.ServerScriptService.Server.Data).Get(game.Players.<you>).Inventory.Revive = 3` and similar for `Charge`, then rejoin/sync; or (better) create the products in a private test place and paste real IDs.
- Emergency charge: with a stock and 1 or fewer charges, a "+1 emergency charge (n)" button appears above Dodge; pressing it adds a charge and lowers the count. It must NOT appear in the Daily Puzzle.
- Revive: lose an Expedition floor (0 charges and under half cleared, or 0 hearts) while holding a token: a full-screen "THE TUNNEL IS COLLAPSING! Use a Revive?" appears; accepting restores 3 charges and 2 hearts and continues the SAME floor; declining or waiting 25 seconds collapses normally (40% salvage). Only one offer per floor.
- Boosts: a gold line at the top right shows "2x shards 14:59"; payouts should double while it runs.
- Finishers: the Codex button > Boss finishers lets you wear an owned finish; beat the Titan and the FINAL BLAST bursts should use that colour.
- Club: with a subscription id configured, Shop shows Subscribe; when active, a monthly Claim button pays 25,000 and grants the title.

### E10. Combat live events (unseen in Studio)
- New calendar events (UTC): Lurker Swarm Friday (Lurkers 3x as common, bounties 1.5x), Crystal Storm (every day 20:00-21:00: rare crystals 3x, damage +25%, Lurkers 1.5x), Explosive Sunday (damage +50%, bounties 1.5x). To test without waiting, temporarily change an event's Weekdays/hours in `Config/Events.luau` to include now. The event banner (top right) should name it; Lurkers should appear noticeably more often and fights should end faster during the damage events.

### E11. Hub boards (unseen in Studio; need a published game with API access)
- Three boards now stand by the spawn: LONGEST CHAINS, DEEPEST EXPEDITIONS, BOSS SLAYERS (each an OrderedDataStore, refreshed every 90 s, written at most every 30 s). Check they do not clip into other hub decor, face the spawn, and show "Unavailable" (not an error) in an unpublished Studio place. After reaching a new depth or slaying the Titan, the right board should list you within a couple of minutes.

### E12. UI polish (unseen in Studio)
- Everything now has depth and colour: buttons have a light top and shade and grow on hover / squash on press; the Menu panel has a gradient background and a slowly travelling rainbow-ish border; each tab has its own colour; section headers are colour banners; toasts are coloured pills with a star or "!"; Detonate has a light band sweeping across it; the boss bar glows and changes colour per phase; CRITICAL MASS is a gold-to-orange gradient; the shard counter glows.
- Rows have a glowing icon tile and an accent strip; Daily, Weekly and Goals rows have progress bars (a full bar shimmers and a claimable button glows).
- Codex: crystals are spinning 3D gems in their rarity colour (grey and still until discovered); Lurkers/Bosses/Relics/finishers/titles/blast colors have coloured icon tiles (relic tiles use the family colour). Shop rows are tinted by price tier.
- Expedition choice cards are tinted per room (red Nest, purple Elite, gold Treasure, magenta Chaos, dark red Boss) with a colour band naming the room.
- Creatures now have real models (`Creatures.luau`): Gnasher (green with teeth and claws), Skitter (small gold beetle with legs), Leech (purple with stripes and a glowing mouth), Sapper (blue orb with electric spikes), Brute (armoured with horns), Crystal Titan (a stacked stone body with arms, head, glowing core and crystal spikes). They rise out of the rock, bob and sway, flash red when hit, and the Titan core changes colour per phase (red body in Enrage).
- Combat feedback: red "-N" floating numbers and a burst when you hit a Lurker or the boss, a gold burst/ring and "+bounty" when one dies, a red screen flash when a heart is lost or the Leech steals, pulsing red attack tiles, and during CRITICAL MASS the whole screen warms up (gold tint, more saturation) then relaxes.
- Watch for: gems flickering or not spinning (ViewportFrames inside the scroll list), performance while the Codex is open (about 12 gems), text overflowing the toast pills or headers on a phone, the shimmer overlay covering button text, hover scaling on touch devices.

### E13. Shop cards with artwork (unseen in Studio)
- the Shop button is now a grid of product cards (two columns, one on narrow screens), each with animated procedural art on a tier-coloured banner: spinning gem piles for shard packs (more gems for bigger packs), ringed "x2" for boosts, a beating heart for Revive, three pulsing orbs for emergency charges, an exploding-rings-and-orbiting-sparks preview in the finisher's own colour, glowing orbiting orbs for blast colors, a gold title ribbon, and a fanned stack of icon tiles for every bundle. Cards have a tier ribbon, badges (BEST VALUE, HOT, ULTIMATE, BUNDLE, OWNED), a price hint chip and a buy button that shimmers when for sale.
- A "Featured" section at the top shows the Ultimate Blastwright, Boss Hunter and Starter Blast bundles. Prices shown are my hints (about R$) and are NOT read from Roblox; the real price appears in the Roblox prompt.
- Watch for: hitches when the Shop tab opens (many animations at once), text overflow inside cards on a phone, gems not rendering inside cards, the card border animation looking too busy.

### E14. Shared threat (unseen in Studio)
- Killing a Lurker adds 5 and a boss 40 to the server-wide Server Goal counter (the same one chain pops feed), so everyone in the server is pushing the same bar. After a collapse without Revive tokens the toast mentions the Shop once; it is a plain message, never a purchase prompt.

### E15. "Blast what for which attack": the combat planning read + chain feel (unseen in Studio)
- With a Lurker or boss on the grid, planting charges shows a red panel at the bottom centre using the SAME rules the server uses: Lurker "~N damage (HP a -> b)" or "KILLS IT" or "does not reach it"; boss "Core hit ~N (HP a -> b)", "Armor: breaks 2 nodes, 2 left", "Weak points hit 1/2", "FINISHER: this volley kills it!"; and for each wound-up attack "SLAM: cut" / "METEORS: 1/3 deflected (pop Lensglass)" / "CORRUPTION: 2/4 purified". Without the Seismograph it only counts direct hits and says so; with it, whole chains. Check the numbers against what actually happens after you detonate.
- Chain feel: chain tier banners (Rumble, Cascade, Avalanche, Cataclysm) and CRITICAL MASS now fire LIVE the moment the chain reaches that length (with a camera punch and ring), not after it ends; the CHAIN counter grows and heats up (orange, gold, red, magenta) as the chain grows.
- Onboarding: after about 30 pops the objective card points at Expeditions ("HOLD F at a pad"), then at reaching floor 4 for the Titan; the first seams after 40 pops have a 60% chance of a Lurker until you kill your first, and a Lurker on the grid replaces the beginner hint with a fight hint.

### E16. UI overhaul: dock, message feed, banners, boss HUD (unseen in Studio)
- **Dock:** in the world (not at a pad) a row of six tiles sits at the bottom centre: Forge, Shop, Daily, Goals, Codex, Farm, each a flat coloured tile with a drawn icon (hammer, bag, calendar, star, book, sprout) and a caption. Pressing one opens that page above the dock (the open tile stays pressed down; press again to close). Red badges appear on Daily / Goals when something is claimable and on Farm when an hour of income is waiting. The objective card can outline a tile in gold ("open Daily to claim"). There is no "Menu" button any more; only a small "?" (help) top right. Check the dock fits on a phone (it scales down) and does not overlap the panel.
- **Fonts and text:** headings, numbers and buttons use the rounded display font (Fredoka), body text the clean Builder Sans; text no longer has glow/stroke, and the shimmer, sparkle and rainbow-border effects were removed on purpose.
- **Messages:** things that happen appear as cards in a column on the RIGHT edge (newest on top, max 4, slide in/out, an icon tile, a bold title and a smaller body; goals/mastery/unlocks get a purple card). Big moments (chain tiers, Critical Mass, boss intro/phases/defeat) show as ONE banner plate in the upper middle, queued so they never pile up. Boss wind-up warnings no longer spam the feed (the boss panel shows them).
- **Boss HUD:** a header plate under the top pills: name, health bar with numbers, five labelled phase pips (the current one lit), and ONE line of "what to do now"; below it a card per wound-up attack (SLAM / METEORS / CORRUPTION) with a live countdown, a draining bar, and the one-line answer, turning green ("Stopped") once you counter it. Dodge sits bottom right with its cooldown. Left column: Critical Mass, run/puzzle and rig cards STACK (no overlap). Bottom centre: crystal info and the combat read stack. The chain counter now pops in the middle of the screen.
- **Boss presentation:** a banner with the boss name and description when it appears; the arena gets a coloured border and a sigil under the boss in the phase colour; the boss recoils when hit; landing attacks throw fire where crystals died with a shake; phase changes fire a big ring, a white flash and a banner naming the new phase and its goal.
- **Kept the 9x9 grid for boss fights on purpose** (the pad, camera, preview and every rule assume it); the arena is made to feel bigger with the border, sigil, model size and camera punches instead.
- Watch for: the right-hand feed overlapping the boss threat cards on a phone, the dock covering the Farm/Forge panel bottom, text sizes in the phase pips, the arena border z-fighting the pad rim.

### E17. Chunky UI overhaul (unseen in Studio; supersedes the flat look in E16)
- **Design system:** `Theme.luau` (colours per system, thick dark outline, display/body fonts, timings, z-layers) and `Kit.luau` (Button, SideButton, ActionButton, CloseButton, Panel, Bar, Currency, Chip, Card, Popup, Label). Everything chunky is built in layers: soft drop shadow, dark outlined edge (the thickness), coloured face with a light-to-shade gradient, inner highlight border and a gloss strip, big drawn icon, outlined text.
- **Interaction:** hover grows (0.10 s) with a tiny tick, press squashes and sinks onto its edge (0.06 s) with the click, release bounces back with an overshoot (0.14 s). Legacy menu buttons share the same feel. Works on touch (hover is optional).
- **World HUD:** a big red SHOP action button (bag icon, huge label) bottom-left with a vertical stack of square icon buttons above it: Forge (orange), Daily (green), Goals (yellow), Codex (blue), Farm (lime). The stack shrinks to fit short screens. Badges show on Daily/Goals/Farm; the objective can outline a button. The shard count is a chunky currency pill with a gem that bounces and counts up when you earn; boosts and events are outlined chips.
- **Blast HUD:** a huge DETONATE button with a bomb icon (bottom-right), DODGE and +1 CHARGE buttons with bolt icons above it, an orange LEAVE button top-right. The blast HUD scales down on small/narrow screens.
- **Menus:** one modal panel with a coloured title ribbon (colour = the page) and a big red close button; rows are thick-outlined cards with big icon tiles, outlined titles and chunky progress bars; section headers are coloured banners. Shop cards have outlined tier tags, big names, price chips and a green BUY button. Messages are chunky coloured cards on the right (icon tile, big outlined title); banners are a big outlined plate; mastery/victory/relic moments also open a reward popup with a big icon and a NICE! button. The boss header and threat cards use the same thick outlines, a chunky health bar and big countdown numbers.
- **Icons:** all drawn in code from rounded boxes (no asset ids exist for icons and none were invented): Forge, Shop, Daily, Goals, Codex, Farm, Gem, Bomb, Bolt, Close, Heart, Lock. If you want painted art later, drop real assets into `Icons.luau`.
- **Safe area:** the ScreenGui uses CoreUI-safe insets. Checked only by reading; test phone landscape and portrait, a tablet and an ultrawide.
- Watch for: dock and panel overlap on narrow screens, text not fitting inside the big buttons, the feed hiding non-critical cards during a boss fight (by design), icons looking too busy at small sizes, hover sounds being annoying, popups queueing wrongly.

### F. Multi-player and phones (Test > 2 players, and the Device emulator)
23. Two players use different pads and see each other's grids and blasts (distant grids appear only when you are near: level of detail). A pad in use is labelled "In use". Walking 130+ studs away for a minute releases it.
24. Phone-size window (for example 390 x 844): top bar (shards, Menu, ?) does not overlap; the Menu panel's 5 tabs fit; the grid is fully visible in the free band; buttons are tappable; text readable.

### G. Publishing-only (do these last, see MANUAL_ACTIONS.md)
25. Save persistence, the leaderboard, product prompts, and 2x Shards / Prismatic Luck can only be verified in a published place.

## E18. Trophy hall and combat dailies (unseen in Studio)
- West of the hub plaza: two gold pedestals (Crystal Titan, Prism Warden). Before your first kill each shows a black silhouette and "???"; after a kill the model gets its colours back and the sign reads "<name> Slain xN". Expect: updates right after leaving an Expedition boss fight; no Output errors from `[trophy hall]`; model is not floating or clipping into the pedestal (tune `MODEL_SCALE` / height in `Client/Trophies.luau`).
- Daily/Weekly (Daily and Goals buttons): new objectives "Slay N Lurkers" and "Trigger Critical Mass N times" appear in the rotation and progress as you kill Lurkers / start Critical Mass.

## E19. Status tiles, area banner, text colour (unseen in Studio)
- Walk between areas: the area name fades in at the top-centre when you ENTER a new area, holds about 3 seconds, and fades away. It must not stay on screen.
- Bottom-right corner: one tile per live event (Prismatic Weekend = gem, Overcharge = bolt, Happy Hour = clock, Lurker Swarm = skull, Crystal Storm = star, Explosive Sunday = bomb) showing "ends in ..." and a Server Goal tile with a progress bar (turns into "SERVER FRENZY" with a countdown). Tap a tile to read its description. Nothing event-related should sit in the middle of the screen any more. To force an event for testing, change an event's Weekdays/StartHour/EndHour in `Config/Events.luau`.
- Text that used to be dark navy on coloured buttons (Let's go, selected tabs and charge buttons, disabled-vs-enabled buy buttons) is now white with the dark outline. Report any label that still looks dark.

## E20. Notice Board contracts (unseen in Studio)
- Daily button > "Notice Board": three offers (Easy / Standard / Hard) with rewards (shards, plus emergency charge tokens on Standard and a revive token on Hard). Accept one; the other two grey out. Hunt a specific Lurker, set a chain, trigger Critical Mass, beat bosses or clear an Expedition floor: the bar moves only after you accepted. Claim when complete; "Give up" drops it. Offers change at 00:00 UTC. The Daily button shows a badge when a contract can be claimed.
- The status tiles, objective card and Dock spacing were tightened (E19): the objective card must not overlap the Forge button; on a short screen the dock should shrink instead.

## E21. Fixes after playtest (unseen until re-run)
- Quest card under the shards (now titled QUEST): fixed-size card, white text, height set from the text. Server Goal / event tiles: fixed size (the earlier version grew huge because a full-size tap button sat inside an auto-sizing tile and covered the ? button); tiles no longer expand on tap. The ? button must click again.
- Leaderboard boards: two posts now stand directly behind each board's left and right edges (they used to be offset in world Z, so on a rotated board they missed it).

## E22. World boss, Assay Office, Blastwright Plus (unseen in Studio)
- **Crystal Colossus:** every half hour on the clock (:00 and :30 UTC) a huge Titan hovers over the hub for 7 minutes and a red WORLD BOSS tile with an HP bar and timer appears bottom-right. Blast anywhere (not the Daily Puzzle): each volley hurts it, big chains hit hardest. HP scales with players at spawn (min 3). When it falls (or time runs out) contributors who dealt 20+ damage are paid: shards, extra for beating it, plus a revive token for the top 3. To test alone, temporarily lower `Config/WorldBoss.luau` BaseHP and HPPerPlayer, or shorten CycleSeconds.
- **Assay Office:** Codex tab, under the crystal list. Each crystal kind counts your pops (50 / 250 / 1,000 / 4,000); Claim pays shards per milestone. Every kind at 1,000 pops earns the "Master Assayer" title when you claim any milestone afterwards.
- **Blastwright Plus:** appears under Permanent perks in the Shop ("Not for sale yet" until the pass id is set). To test without buying, temporarily set `Purchases.Owns` to return true for it; you should get the title and one supply drop per day.

## E23. Loadout, new charges, pacing, locked pads, calm mode (unseen in Studio)
- **Loadout tab** (new dock button, also a tab in the menu): one section per charge (Blasting Cap, Bore, Cross, Shockwave) with its own tree: Tier 1, then a FORK (pick one of two), then a capstone. The header shows how many cells the charge covers now and its direct-hit multiplier; the hover ghost and blast area in a seam must match (wider bore lanes, star diagonals, ring with a hole, filled core). "Reset" clears a branch for 5,000 shards so you can take the other fork. Buy the charge in the Forge first (Bore 12k, Cross 60k, Shockwave 120k).
- **Shockwave Charge:** hits a ring 1 to 2.5 cells away and skips the middle (Shock Core fills it). Try it next to a cluster: the crystals touching the charge stay for a follow-up.
- **New rig upgrades (Forge):** Reinforced Plating (+1 heart), Weak Point Scope (+15% damage), Overcharge Capacitor (Critical Mass 2 pops sooner), Prospector's Lens (+15% Prismatic chance).
- **Pacing:** all prices went up 3x to 8x (areas 30k / 100k / 300k, upgrades, charges, traits) and the Crystal Farm was cut (150 to 3,500 an hour, 6 hour store). One Expedition should no longer buy everything; the first area should take a couple of runs. Report how long each unlock actually takes.
- **Locked pads:** a pad in an area you have not unlocked says "LOCKED - press E to unlock" with the price and its prompt reads "Unlock area". Pressing E buys the next area if you can afford it (otherwise a message says how many shards are missing); areas further ahead say to unlock the earlier one first. Distances now read in m.
- **Calm mode** (boss floors and Expeditions): rings are real outlines instead of filled discs, fewer particles, weaker camera shake, only boss/phase banners (smaller, higher), boss armor/weak-point/corruption markers are a flat tile plus a thin beam. You should always be able to read the grid and the threat cards. Report anything that still hides the field.

## E24. Top info stack and boss markers (unseen in Studio)
- On a boss floor everything that explains the fight is ONE column at the top-centre: boss header, threat cards (wrap to a second line if there are three), then "what this volley does" and the crystal info line. Nothing sits at the bottom any more, and the camera fits the grid below the column. Check on a small/phone-size window that the grid is still big enough and the column does not hit the left status cards.
- Armor nodes (gold), weak points (magenta) and corruption marks (purple) show as a floating diamond above their cell, plus a flat tile and a thin beam, so they can no longer hide under the rocks.

## E25. Specimens, Track, streak, reveals (unseen in Studio)
- **Specimens:** blast normally. About 1 volley in 20 to 25 drops a specimen (more for big chains). Rough/Polished show as a feed card, Faceted as a banner, Flawless/Radiant/Celestial as a full reveal (spinning crystal, rays, shimmering title; Celestial adds a white flash). Reveals must never appear during a boss floor or an Expedition: they wait until it is over. The Codex tab now has a "Specimen Cabinet" section (one row per crystal, six grades, x-counts and "?" for missing) and duplicates pay shards. To test a mythic quickly, temporarily set `Base = 1` and the Celestial `Weight` high in `Config/Specimens.luau`.
- **Track:** Goals tab, top section. Each level has a FREE row and a PREMIUM row. Levels come from XP (volleys, Lurkers, bosses, floors, contracts, specimens, streak). Premium rows say "Premium" until the pass id exists, then open the purchase prompt. The Goals dock button gets a badge when something can be claimed.
- **Daily reward streak:** Daily tab, top. Claim once per UTC day; day 7 is the big one. To test another day, lower `Streak` `LastDay` in a test save, or change the system clock.
- **UI QA:** run `python tools/lint/ui_qa.py` before publishing (it should print 0 errors, 0 warnings).

## E26. Ascension (unseen in Studio)
- Loadout tab, top section "Expedition difficulty". Winning your first Expedition on Normal unlocks Ascension 1; winning at your highest unlocked tier unlocks the next (5 tiers). Each tier stacks its rule on the ones below (25% tougher Lurkers, one fewer charge, 30% tougher bosses, one fewer heart, and a harsher clear requirement plus more monster health) and pays a bigger banked haul (shown as "Total haul x..."). Winning a tier also earns the title "Ascendant I..V".
- Check: pick a tier, start an Expedition (a warning states the rule), and confirm the effect (starting charges, hearts, Lurker/boss health bars). The tier cannot be changed mid-run. Banking early and victory both apply the haul multiplier; a collapse (salvage) does not.

## E27. UI split, refresh, sounds, FREE shop section (unseen in Studio)
- Every menu tab (Forge, Loadout, Daily, Farm, Goals, Shop, Codex) is now its own file in `Client/Tabs/`. This was a pure move: open each tab once and confirm it looks and behaves as before (buttons work, rows appear, nothing errors in Output).
- The menu now refreshes at most every 0.3 s after server updates and keeps your scroll position; switching tabs starts at the top. Click Buy on something and check the list does not jump.
- Specimen sounds: each grade has its own pitch/layer signature (Rough soft coin up to a rising run under a deep boom for Celestial). They reuse the existing cues, so they will sound like variations of the reward and bling sounds.
- Shop: a "FREE rewards" section is now first (daily reward and the next free Track reward, both with a Claim button).

## E28. Camera stability, boss defeat window, shop scroll (unseen in Studio)
- **Camera:** during a boss fight, hover different cells and let threat cards appear/disappear. The camera should ease smoothly, never suddenly snap in or out, even as the top info column changes height.
- **Boss defeated:** killing a boss now opens a full-window card ("VICTORY! ... DEFEATED") with a CONTINUE button; tapping anywhere on the dimmed background also closes it. If a Mastery title was earned on the same kill, its reward card shows either just before or just after (queued, never both on screen at once).
- **Shop scroll:** open the Shop, scroll to the bottom, then buy something near the top (or wait for a Sync to arrive) and confirm the list still ends exactly at the last card, with nothing from the top peeking in, and nothing from below visible before you scroll to it. Do the same after scrolling partway and switching areas/claiming a daily reward while the panel is open.

## E29. Real product ids are live (do this before any more Robux testing)
- `Config/Products.luau` now has real ids for everything except the `TrackPremium` gamepass. Open the Shop in a **published, non-Studio** session (private server or live) and confirm every card that has an id shows a real **Buy** button, not "Not for sale yet" — only the Track Premium card should still say that.
- Buy one of each category once (a shard pack, a blast color, a boost/offer, and the Club subscription) and confirm: the purchase prompt shows the right name/price, the reward grants exactly once, the Shop updates, and it survives leaving and rejoining.
- `docs/PAID_ITEMS_GUIDE.md` section 5 has the full purchase checklist. Studio test purchases do not prove the live flow; use a published server.

## E30. Trophy hall boards no longer sunk; a bad Config/* can't take the whole server down silently
- The two hub trophy boards (west of the plaza) now stand on a small post, clearly above the plaza floor, with the statue's feet resting on the pedestal. Check both (Titan and Warden) at spawn: no clipping into the ground, "???" readable before a kill.
- `Server/init.server.luau`: if `Game.Init()` throws (for example a bad edit to a `Config/*` file), the Output now shows a clear `[Server] Game.Init failed...` warning instead of the whole server silently doing nothing (remotes exist but nothing answers them, characters never load). This does not make gameplay work when config is broken — it only makes the failure visible instead of silent.
