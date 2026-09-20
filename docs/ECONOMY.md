# Economy

## Currency
**Shards** are the only currency in the slice. No premium currency yet: add one only if monetization needs it.

## Sources
- Volley payout: sum of (crystal value x multiplier) x (1 + tier bonus).
- Seam clear bonus: 25% of seam earnings x cleared fraction, if at least 50% cleared.

- Daily objectives: 3 per day, 120 / 250 / 450 shards by slot, times (1 + 0.5 x extra areas unlocked).
- Goals: one-time shard rewards, 100 to 20,000 each, about 46,700 in total (`Config/Achievements.luau`).
- Geode caches: one-time 60-800 shards each (22 total).
- Shard packs (real money): see `MONETIZATION.md`.

## Sinks
Upgrades, charge unlocks, stratum unlocks (see `PROGRESSION.md`).

## Rough pacing (paper math, **not** playtested)
- A 9x9 seam is ~70 crystals. A decent volley pops 10-20 for roughly 60-150 shards.
- A seam pays roughly 150-350 shards, so the first upgrade (150) comes within the first seam or two, and Stratum 2 (1200) after roughly 5 seams.

## Late game / inflation
Not designed yet. Upgrade costs grow roughly 3x per level. Stratum values should rise with stratum; that needs playtest data first.

## Tuning knobs
All in `Config/Tuning.luau`, `Crystals.luau`, `Upgrades.luau`, `Charges.luau`, `Strata.luau`.
