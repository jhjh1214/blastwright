# Economy

## Currency
**Shards** are the only currency in the slice. No premium currency yet: add one only if monetization needs it.

## Sources
- Volley payout: sum of (crystal value x multiplier) x (1 + tier bonus).
- Seam clear bonus: 25% of seam earnings x cleared fraction, if at least 50% cleared.

- Daily objectives: 3 per day, 600 / 1,250 / 2,250 shards by slot, times (1 + 0.5 x extra areas unlocked).
- Weekly challenges: 3 per week at 3,000 / 7,000 / 15,000 shards (times 1 + 0.5 x extra areas unlocked).
- Goals: one-time shard rewards, 500 to 100,000 each, about 233,500 in total (`Config/Achievements.luau`).
- Geode caches: one-time 300-4,000 shards each (22 total).
- Shard packs (real money): see `MONETIZATION.md`.

## Sinks
Upgrades, charge unlocks, stratum unlocks (see `PROGRESSION.md`).

## Rough pacing (paper math, **not** playtested)
## Measured pacing (simulation, not a promise)
`tools/sim/economy.luau` plays whole careers with the real rules and prices; `tools/sim/balance.luau` measures how hard the puzzle is for a given crystal mix. Both count blasting income only (no dailies, weeklies, goals or caches, so real progress is somewhat faster) and assume about 100 seconds of real play per seam.

Income per seam with no upgrades: about 590 shards (casual planner, area 1) rising to about 860 (area 4); a brute-force planner earns about 30% more. With 100 seconds per seam the casual timeline is:

| Milestone | Seam | Roughly |
|---|---|---|
| Deep Satchel 1 | 2 | 3 min |
| Shaft Charge | 6 | 10 min |
| Seismograph | 23 | 40 min |
| Prism Veins (area 2) | 27 | 45 min |
| Ember Hollows (area 3) | 87 | 2.4 hours |
| Echo Caverns (area 4) | 139 | 3.9 hours |

The brute-force planner reaches the same points about 25 to 30% sooner. Prices were originally set by feel and were about 5x too low: the first seam earned about 1,600 shards and the whole career took about 30 minutes. The crystal mix was the deeper cause (see below); both were fixed from these simulations.

## Crystal mix (why the spawn weights are what they are)
With Kindlequartz at 20 of about 112 total weight, every volatile crystal set off more than one more, so almost any charge cascaded across the whole grid (a casual planner cleared about 86% of a grid, area 4 about 96%) and planning did not matter. Spawn weights were lowered (Kindlequartz 7, Resonite 10, Lensglass 4, Slowburn 4, Echostone 3, Dreadgeode 14). Now the best single charge pops about 26%, 36%, 45% and 52% of the grid in areas 1 to 4, a casual planner clears roughly 70 to 85%, and the longest chains are about 24 (area 1) to 57 (area 4). A unit test (`balance:`) fails if the mix drifts back towards trivial chains.

## Late game / inflation
Not designed yet. Upgrade costs grow roughly 3x per level. Stratum values should rise with stratum; that needs playtest data first.

## Tuning knobs
All in `Config/Tuning.luau`, `Crystals.luau`, `Upgrades.luau`, `Charges.luau`, `Strata.luau`.
