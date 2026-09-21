# Game Design

## The world (explorable mine)
The game is a walkable mine, not a single screen. Layout data and tests: `Config/World.luau`.
- **Blastwright Depot (hub):** spawn plaza with a beacon and signposts to each biome.
- **Four biomes,** each with 4 blast pads and a landmark beacon, linked to the hub by lantern-lit roads: Glimmer Shallows (west, stratum 1), Prism Veins (east, stratum 2), Ember Hollows (north, stratum 3), Echo Caverns (south, stratum 4). You can walk into any biome at any time; you can only *blast* there once its stratum is unlocked in the Forge. Seeing where you are heading is part of the pull.
- **Blast pads:** round cavern floors (34-stud radius) ringed by rocks and crystal clusters, open on the station side. Walk to a pad's station and use its prompt. The camera lifts to the fixed top-down view of that pad's grid and your movement locks; "Leave" (or X) returns to free roaming. A pad is reserved for you until you take another pad, leave the game, or wander more than 130 studs away for 60s.
- **Geode caches:** 22 hidden caches (5 per biome, 2 near the hub) reward shards once per player (500 hub / 300 Shallows / 750 Prism / 2,000 Ember / 4,000 Echo). They sit off the roads, so exploring pays.
- **Terrain and look:** Roblox Terrain rock, cliffs, spires and mounds, glowing crystal clusters, lanterns, and drifting motes tinted by area.

## Daily objectives
Menu > Daily shows three objectives that rotate each UTC day (same for everyone, deterministic from the day number). Targets and rewards rise by slot. Progress is recorded by the server as you blast. Claiming pays shards once. Unclaimed rewards are lost at reset, but a missed day costs nothing else (no streaks). A dot on the Menu button and a pulsing objective tell you when one is ready.

## Server Goal (co-op)
Everyone on a server pools their pops toward one shared target (`Config/Community.luau`): 250 with one player, plus 150 for each extra player online when the round starts, capped at 2,500. The progress is shown under the event banner. When it is reached, **everyone who contributed** gets 1,500 shards and the whole server gets a 3-minute **Frenzy** (payouts x1.25, stacking with events and passes); a new round starts 20 seconds later, retargeted for the players then online. It gives a lone player and a full server the same feeling of "we did it together" with no matchmaking. The rules (target scaling, one completion per round, contributor tracking, frenzy timing) are pure, tested code; the broadcasting is server code that has not been run.

## Live events
A calendar (UTC, `Config/Events.luau`) switches rules on for everyone with no update or restart: **Prismatic Weekend** (Saturday and Sunday: 3x Prismatic chance), **Overcharge Wednesday** (+1 charge every seam), and **Happy Hour** (18:00 to 19:00 every day: payouts x1.5). A gold banner under the Menu button names the active event and its time left. Seams generated during an event use its rules; payouts use the rate in force when you detonate. Adding an event is one table in the config (a test checks weekdays, hours, effect names and that no shard bonus exceeds 3x). Event rates multiply with the 2x Shards and Prismatic Luck passes.

## Weekly challenges
Below the daily objectives in Menu > Daily: three larger challenges per week (Monday 00:00 UTC to the next Monday), same recording as the dailies but with much bigger targets (for example 400 to 2,000 pops) and rewards (600, 1,400, 3,000 shards, scaled by areas unlocked). Every weekly target is enforced by a test to exceed the matching daily target. Unclaimed rewards are lost at reset; a missed week costs nothing else.

## Blast colors (cosmetic)
Menu > Codex > Blast colors. Styles recolor your planting markers and your detonation rings and bursts (other players see your color on your blasts). No gameplay effect. Classic is free; Frostfire, Rose Gold, Verdant, Royal and Solar unlock by claiming specific Goals (ownership is derived from claimed goals, so nothing extra is tracked); Neon Pink is a shop item. Equipping is validated by the server, and a bad or stale saved choice falls back to Classic.

## Leaderboard
A "Longest Chains" board stands beside the hub spawn: the top 10 best chains across all players (names resolved from Roblox). Your best chain is queued after every volley and written at most every 30 seconds (only improvements are stored); the board refreshes every 90 seconds. It needs a published game with API access; otherwise it says it is unavailable and nothing else is affected. Ranking and text are pure, tested code (`Shared/Board.luau`); the DataStore part (`Server/Leaderboard.luau`) is best-effort and untested.

## Goals
Menu > Goals lists permanent milestones (pops, chain records, seams cleared, shards earned, geode caches, Codex, Prismatic finds, areas unlocked) in three or so rising tiers each, 23 in total. Progress is derived from stats the save already keeps, so nothing extra is tracked; only "claimed" is stored. Each pays shards once (about 233,500 in total across all goals). Ready goals are listed first. The moment a goal becomes claimable a "Goal ready" toast appears (never for goals that were already done when you joined), and a dot on the Menu button plus a pulsing objective say one can be claimed. Adding a goal is one line in `Config/Achievements.luau`.

## Guidance
`Shared/Objectives.luau` (pure, tested) decides the next step: go to a blast pad, open the Forge for a first upgrade, earn shards for the next area, unlock it, then hunt caches. The client `Guide` shows it as an objective card, a gold floating marker with distance, a glowing dot trail on the ground, an edge-of-screen arrow when the target is off-view, and a pulsing Forge button. In blast mode a short hint says "Tap the grid to plant a charge" then "Press DETONATE" until the player has popped 40 crystals. New players get a welcome panel; the "?" button reopens it. Caches deliberately get no arrow.

## Rules of a seam
- A **seam** is a 9x9 grid of crystals (some cells empty), private to each player, generated by the server.
- The player has a **charge budget** (base 4, +1 per Deep Satchel level).
- The player plants charges (tap a cell; tap again to remove), then presses **Detonate**. That is a **volley**. Several volleys fit in one seam.
- The server simulates the volley (`ChainSim`) and pays out. The client replays the timeline.
- A seam ends when charges run out or no valuable crystals remain. Clearing at least 50% of valuable crystals pays a **clear bonus** (25% of seam earnings x cleared fraction). Then a new seam is generated.

## Crystals (data: `Config/Crystals.luau`)
| Crystal | Rarity | Behavior | Stratum |
|---|---|---|---|
| Glimmerstone | Common | Inert ore, base value 5 | 1 |
| Kindlequartz | Uncommon | Volatile: blasts radius 1.5 when popped, spreading the chain | 1 |
| Resonite | Rare | Amplifier: +0.5 to the volley's multiplier | 1 |
| Lensglass | Epic | Prism: beams along its row (range 5) | 2 |
| Dreadgeode | Uncommon | Unstable: worth 0, halves the multiplier (min 1) | 2 |
| Echostone | Legendary | Relay: when it pops it sets off every other Echostone on the grid however far away (0.12s later), and blasts its own neighbours (radius 1). Value 12 | 4 |
| Slowburn | Rare | Delayed: lights a fuse when hit, pops 1s later (after the rest of the chain, so it cashes in the peak multiplier), then blasts radius 2. Value 20 | 3 |

Any crystal with value has a 4% chance to be **Prismatic** (3x value).

The multiplier is applied in pop order, so hitting Resonite *before* the valuable crystals matters, and a Dreadgeode popped early hurts. Slowburn flips the puzzle: it is worth the most when it pops *last*, so you want the multiplier built up before its fuse ends.

## Charges (`Config/Charges.luau`)
- **Blasting Cap:** radius blast (1.5 cells; Fat Fuse upgrade widens it).
- **Shaft Charge:** whole column, 4 cells each way. Unlocked for 2,000 shards.

## Chain tiers
Rumble (5 pops, +10%), Cascade (10, +25%), Avalanche (20, +50%), Cataclysm (35, +100%).

## Momentum
A volley of 10+ pops (Momentum Coil lowers this to 8 then 6) refunds one charge. Big chains keep the seam alive: this is the "one more volley" hook.

## Planning aid
In blast mode an overlay drawn ON TOP of the world (so rocks and crystals cannot hide it) explains the floor:
- a bright outline around the whole grid and faint lines between cells show where charges can go;
- on PC, hovering a cell outlines it in gold and tints the exact cells a charge there would blast (a plus-shaped blob for a Blasting Cap, a strip for a Shaft Charge); on touch, the last tapped cell acts as the hover cell;
- planted charges fill their cell orange and tint the cells they blast;
- crystals it will hit are ringed and linked by lines back to whatever sets them off. **White** = hit directly by a charge, **gold** = chain reaction, **cyan** = prism beam;
- a second line describes the crystal you are pointing at (name, what it does, Prismatic bonus).

Base game: direct hits only, so early play is still about reading crystal types. **Seismograph** upgrade: the whole chain, estimated shards, tier bonus and whether it refunds a charge. While a volley plays, a short line shows which crystal set each chained crystal off.

## HUD layout
All planning text is one compact block under the top row (shard counter left, Leave button right). The camera reserves screen space for it and for the bottom buttons and fits the grid into the free band, so the HUD never covers the grid. It sits low (55 degree tilt, 60 degree field of view), roughly half as high as the first version. Proximity prompts such as "Start blasting" are switched off while you are at a grid. The "press Detonate" hint is a pulsing gold outline on the Detonate button, not floating text. Charges remaining are part of the preview line.

## Server authority
The client sends only cell coordinates and charge kinds. The server validates them (`Validate.luau`), runs the simulation itself, applies results and pays out.
