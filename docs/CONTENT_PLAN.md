# Content Plan

Adding content is a data change:
- **New crystal:** add an entry in `Config/Crystals.luau` (+ `Order`), pick an existing `Behavior` or add one in `ChainSim.Run` and a silhouette builder in `CavernView.luau`. Add a test.
- **New charge:** `Config/Charges.luau`; add a shape in `ChainSim.blast` if needed.
- **New stratum:** append to `Config/Strata.luau` and set crystals' `Stratum`.
- **New upgrade:** `Config/Upgrades.luau` plus its effect wiring in `Game.contextFor`/`Preview`.

## Backlog (ordered)
1. Slice playtest and fixes.
2. Verified audio and visual assets.
3. Stratum 4 with another new mechanic (e.g. magnet crystals). Stratum 3 (Slowburn) is done.
4. Daily objectives and rotating challenges.
5. Co-op linked seams. Leaderboard for longest chain.
6. Monetization (Phase 10).
