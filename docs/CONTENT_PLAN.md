# Content Plan

Adding content is a data change:
- **New crystal:** add an entry in `Config/Crystals.luau` (+ `Order`), pick an existing `Behavior` or add one in `ChainSim.Run` and a silhouette builder in `CavernView.luau`. Add a test.
- **New charge:** `Config/Charges.luau`; add a shape in `ChainSim.blast` if needed.
- **New stratum:** append to `Config/Strata.luau` and set crystals' `Stratum`.
- **New goal:** one `goal(...)` line in `Config/Achievements.luau`; keep targets and rewards rising within a stat (a test enforces it, and that the target is reachable).
- **New upgrade:** `Config/Upgrades.luau` plus its effect wiring in `Game.contextFor`/`Preview`.

## Backlog (ordered)
1. Slice playtest and fixes.
2. Verified audio and visual assets.
3. Stratum 4 with another new mechanic (e.g. magnet crystals). Stratum 3 (Slowburn) is done.
4. (Daily objectives done.) Weekly challenges and events.
5. Co-op linked seams. Leaderboard for longest chain.
6. (Monetization framework done; needs product IDs.) Cosmetic blast colors as a tiny-tier product.
