# Balance backlog

Balancing is deliberately done LAST (developer's call, 2026-09-21). This file collects everything that needs tuning so nothing is forgotten. Tools: `tools/sim/economy.luau`, `tools/sim/balance.luau`, and the `balance:` unit test.

## Developer playtest feedback (after the x5 rebalance)
- **The game feels too fast.** Progression through upgrades and areas is quicker than it should be.
- **Daily and weekly objectives are cleared too easily, and then pay a large pile of shards.** Targets are too low relative to income, and the rewards are too big relative to prices.

## Likely causes (from the simulations, to verify)
- Objective targets were written when a seam paid ~150 shards; income is now several hundred to ~1,000 per seam, and one seam already clears "Volleys 4", "Pops 60" and part of "Shards 400".
- Daily rewards (600 / 1,250 / 2,250) and weekly rewards (3,000 / 7,000 / 15,000) are worth about one to twenty seams of income, so claiming them dwarfs blasting for the first hours.
- The simulator counts only blasting income, so real progression (with dailies, caches and goals) is faster than its timeline.
- Time per seam (100 s) is an assumption; a real player may be faster or slower.

## Things to tune when balancing (all data, no code changes)
- Objective targets: `Config/Dailies.luau`, `Config/Weeklies.luau` (targets are per slot; a test requires weekly > daily).
- Objective rewards: `SlotRewards` in the same files.
- Prices: `Config/Upgrades.luau`, `Config/Charges.luau`, `Config/Strata.luau`.
- Reward sizes: `Config/Achievements.luau`, cache rewards in `Config/World.luau`, shard packs in `Config/Products.luau`.
- Income itself: crystal `Value` in `Config/Crystals.luau`, `Tuning.ClearBonusRate`, chain tier bonuses, `Tuning.BaseCharges`.
- Puzzle difficulty: crystal spawn `Weight`s (guarded by the `balance:` test).

## Suggested approach
1. Decide target pacing (for example: first area done in about 2 hours, whole game in about 15 to 20 hours of play).
2. Fix the target time per seam from real playtest logs.
3. Make objective targets scale with income (or with the player's area) so they stay meaningful, and cap the reward at a fraction of what blasting earns in the same time.
4. Re-run the simulators and update `docs/ECONOMY.md`.

- Daily Puzzle medal rewards (1.5k/3k/6k/12k, +10%/day streak) and Expedition rewards (depth +15%/floor, x1.5 win, 40% salvage) are unmeasured placeholders; also check whether greedy par is too easy/hard to beat on typical grids (run a sweep over many days).
- Crystal Farm rates/costs (300-15,000/h, upgrades 4k-280k) are placeholders; compare with career pacing so offline income does not trivialise active play.
- Lurkers: spawn chance (10%+5%/area+4%/floor), HP, damage values, 3 hearts, 15% repair fee and bounties (400/1000/3000) are placeholders; check that fights are a real decision (not always optimal to ignore, not always a forced loss) with a simulation.
- Boss: MaxHP 30 chosen from sim (greedy 1-charge bot wins 33% Basic-only, 68% all charges); recheck with real playtests. Attack cadence (every 2 turns), Cut needs 3 pops, Dodge cooldown 2, bounty 6000, Critical Mass (x1.5 dmg, x1.25 shards, 2 volleys) are placeholders.
- Expedition rooms/relics: room weights, Elite 1.75x HP, Treasure x2, chaos events (x3 payouts for -2 charges, 10x rare, x3 bounty) and every relic strength are placeholders; needs a run simulation (bot through 8 floors) to check the safe/greed choice is a real trade-off and no relic combination trivialises boss floors (Shockwave x Last Stand x Critical can make the finisher automatic).
- 2026-09-21 income check (tools/sim/expedition.luau): a greedy bot with no monsters clears 84-96% of every floor and finishes 98% of Expeditions, and a full win paid about 3.3x the 8 floors' plain shards plus 18,000 in boss/Lurker bounties, i.e. roughly 9x normal seam income per minute. That would have made plain blasting obsolete and skipped every area unlock, so the rewards were cut: depth bonus 0.15 -> 0.06 per floor, victory bonus 1.5 -> 1.25, boss bounties 6,000/12,000 -> 2,000/4,000, Lurker bounties roughly halved. Target: a skilled full win pays about 2-2.5x the same time spent mining, for real risk. Still unmeasured against human play; recheck after the first playtests. Also: greedy play clears far more than a human will, so `ClearToAdvance` (0.5) may be too lenient for the average player and too harsh for a beginner. Watch collapse rates.

## 2026-09-22 pacing pass (developer: "progress way too fast, one Expedition fully upgrades everything")
Prices raised (Strata 6k/20k/60k -> 30k/100k/300k; Deep Satchel 750/2.5k/7.5k -> 3k/12k/40k; Fat Fuse 1.2k/4k/12k -> 5k/20k/60k; Momentum 3k/10k -> 12k/45k; Seismograph 4.5k -> 20k; Bore 2k -> 12k; Cross 15k -> 60k), the Crystal Farm cut (300-15,000/h with an 8 h store -> 150-3,500/h with 6 h), and new sinks added: four rig upgrades (Plating, Scope, Capacitor, Lens) and a 20-node trait tree (about 1.2M shards for a full four-branch build, one fork per branch so about 0.55M for a real build) plus the Shockwave charge (120k). `tools/sim/economy.luau` (mining only) shows the first area unlock after about 4 hours of pure mining; Expeditions are meant to be roughly 2x faster, so the target is a few Expedition runs per area unlock. Still to check with real play: Goals rewards (several 5k-120k rewards) and boss/Lurker bounties are unchanged and could still front-load income; dailies (600/1,250/2,250) are small against the new prices; shard packs (2.5k-150k per area unlocked) now buy much less progress than before, so raise them if you want packs to matter.
