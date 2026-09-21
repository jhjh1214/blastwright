# Development Plan

| Phase | Status |
|---|---|
| 0 Concept | Done |
| 1 Approval | Done: Concept 1 (Blastwright), 2026-09-21 |
| 2 Architecture | Done (`TECHNICAL_ARCHITECTURE.md`) |
| 3-4 Prototype / vertical slice | Runs in Studio; developer reports it "feels very good" (2026-09-21) |
| 5 Game feel | Hooks exist (VFX, shake, tiers); tuning needs playtest |
| 6 Progression | Basic (upgrades, charges, strata, Codex) |
| 7 World/content | Explorable mine built (hub, 4 biomes, 16 pads, 22 caches, terrain); **unseen in Studio** |
| Social | Server Goal (co-op), hub leaderboard, shared caverns (unseen in Studio) |
| Live ops | Calendar events (weekend, midweek, happy hour) with a HUD banner (unseen in Studio) |
| Retention | Daily objectives, weekly challenges and 28 goals (unseen in Studio) |
| 8 Collection | Codex, 28 milestone Goals and 7 blast colors (unseen in Studio) |
| 9 Economy | Simulated with real rules (tools/sim); prices and crystal mix rebalanced from it; not playtested |
| 10 Monetization | Framework built (products, ProcessReceipt, shop tab); **no IDs, never tested live** |
| 11 UI polish | Blast HUD moved to screen corners; roam HUD separate; further polish pending |
| 12 Audio/VFX polish | SFX, ambience and a shuffled classical music playlist wired (unheard); music/effects switches saved |
| 13 Mobile | Not tested |
| 14 Security | Audited (docs/SECURITY.md); every remote validated and rate-limited; not tested against real exploits |
| Social | Hub leaderboard of longest chains (needs a published game to test) |
| 15-16 QA / Launch | Launch checklist written (docs/LAUNCH_CHECKLIST.md); QA needs your playtest |

## Next
1. Developer confirms audio (`[Audio] ... OK` in Output), listens, and gives feel feedback; fix what breaks.
2. Asset workflow for crystal/environment visuals, then music/ambience.
3. Tune the economy from real play data.

## Direction (developer brief, 2026-09-21): fun first, then retention, then monetization
North star: the crystal system IS the combat system. Priority order: (1) moment-to-moment fun, (2) combat built from crystal mechanics, (3) one excellent boss, (4) replayable Expeditions, (5) progression, (6) collection and social flex, (7) monetization around things players already want, (8) content volume.

Status against that order:
- 1-2 done as a first slice (unseen in Studio): Lurkers, chain power tiers, CRITICAL MASS, hearts and stakes.
- 3 done as a grid fight: Crystal Titan (floors 4 and 8). Real-time arena and boss music are not built.
- 4 built (unseen in Studio; balance and sims pending): Expedition room types (mining, combat, elite, treasure, event, heal, challenge, mini-boss, boss), Safe/Greed/Chaos/Relic path choices, relic families (Echo, Explosion, Beam, Risk, Combo) with rule-changing effects instead of +%.
- 5-6 next: boss mastery objectives and trophies, Codex for enemies/bosses/relics, titles, visible cosmetics, hub showcase.
- 7 after the loop is proven: product ladder (5-25, 49-99, 149-299, 399-799, 999+ Robux), cosmetic-first shop, bundles, Club subscription, all via the existing ProcessReceipt path with IDs left nil until the developer creates them. Never gate core play; no purchase prompts mid-run.
- 8 last: live events and rotating modifiers (the Events config already supports the architecture), shared boss events.

Rule for every step: prove it is fun with a test or a sim first, then widen. Do not build 30 enemies or 200 relics before the loop is proven.
