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
