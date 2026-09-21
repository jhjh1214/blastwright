# Full game audit (2026-09-22)

Audit of the real project as it is in the repository (source read, tests and linters run), not of earlier plans. Nothing here was verified in a live Studio session: everything visual and networked is code-reviewed and unit-tested only. Where I say "verified" I mean by a test, a linter, a compile or a Rojo build; those results are at the end.

## 1. Current state

### What is already good (keep)
- **The core mechanic is strong and deterministic.** `ChainSim` (pure, tested) drives payouts, the client preview and combat, so what you see is what happens. Four charge types with per-charge shape extras.
- **Combat is built from the crystal system**, not bolted on: Lurkers, two bosses with real-time threats answered by crystal behaviours, chain power and Critical Mass.
- **Server authority is consistent.** All 22 client-to-server remotes go through `guarded` (per-player token bucket; the other 11 of the 33 remotes only carry server-to-client messages) and validate arguments with pure functions; purchases only through `ProcessReceipt` with idempotent receipts.
- **Many interacting loops already exist:** Expeditions (rooms, relics), Notice Board contracts, dailies/weeklies, Goals, Assay, world boss, Farm, Puzzle, events, Server Goal, Codex, titles, trait tree.
- **One design system** (Theme, Kit, Icons, Dock, Feed, StatusDock, BossHud) with drawn icons that cannot fail to load.
- **Test discipline:** 292 pure-logic tests, new logic mutation-checked, three linters (Luau compile/analyse, Roblox API name check, and the new UI QA).

### What is weak
- **Feel of rare moments.** Before this pass a "rare" result was mostly text in the feed. Only bosses and the tier banners had presentation.
- **No random reward chase.** Everything was deterministic progress bars. There was no "what will I get?" loop, no collection with grades, no pity, no duplicate handling.
- **No free reward habit.** There was no login streak and no permanent reward track; dailies only cover active play.
- **Monetization was a shop, not a ladder.** 18 products, 3 passes, a subscription, but no free/premium reward track and little reason to buy a pass on day 1.
- **Prototype visuals.** Crystals, creatures and pads are procedural Parts; UI icons are drawn shapes, not painted art. Shop card art is drawn (a painted-art hook exists).
- **UI is one 1,300-line file (`UI.luau`)** that rebuilds the whole menu panel on every snapshot; rows are created and destroyed constantly.

### What was missing (and what this pass added)
| Gap | Status |
|---|---|
| Randomised, collectible, rarity-graded rewards with pity | **Added:** Specimen Cabinet (`Shared/Specimens.luau`) |
| Rarity-scaled reveal presentation | **Added:** `Client/Reveal.luau` (feed card, banner, full reveal, mythic flash) |
| Permanent free/premium reward track | **Added:** Blastwright Track (`Shared/Track.luau`), Track Premium pass |
| Free daily habit | **Added:** 7-day login streak (`Shared/Streak.luau`) |
| Static UI QA | **Added:** `tools/lint/ui_qa.py` |
| Real device UI testing, painted art, balance from real play | **Not possible from here** (see section 6) |

### What becomes a problem at scale
- **Economy inflation.** Prices were raised 3x to 8x last pass; unchanged faucets (Goals rewards up to 120k, boss bounties, shard packs) can still front-load income. Track and Streak rewards are all scaled by areas unlocked; watch that they do not become the main income.
- **Progression inflation.** Trait tree (about 1.2M shards), upgrades, areas: the sink total is about 2M+, an endgame of 20+ hours, but no prestige. Recommended: do not add rebirth yet; extend depth instead (see section 4 future work).
- **DataStore.** One profile per player with a growing table: `Specimens.Found` (at most 42 keys), `Track.Claimed` (at most about 60 keys plus one per level beyond 30), `Codex`, `Assay`, `Collection`. Small. The session-lock code (`Data.luau`) autosaves; per-save size is well under the 4 MB limit. Watch `Track.Claimed` if levels beyond 30 are used heavily (one key per level).
- **Remotes.** 33 RemoteEvents (22 client-to-server, all rate limited); the Sync snapshot is re-sent after most actions. The snapshot now includes `Specimens.Found` (≤42 entries) and `Track` (small); it grows slowly. If it becomes an issue: send deltas.
- **UI complexity.** `UI.luau` should be split into per-tab modules (Forge, Loadout, Daily, Goals, Codex, Shop). Not done: it is a refactor and must not share a commit with behaviour changes.
- **Performance.** See the QA results in section 6.
- **Mobile screen space.** The top stack (boss fights) and the bottom-left dock are the tight spots; see the QA results in section 6.
- **Content production.** Painted art and audio are the bottleneck, not code.

## 2. Retention audit (what a player experiences)
- **First 10 seconds:** spawn in the hub with a welcome panel and a guide arrow; a blast pad is nearby. (Unchanged.)
- **First 60 seconds:** first volley pays shards; the first Track XP and level come after about 120 XP (about 30 volleys) but the first **specimen** can drop from the very first volley (1% + 0.4% per pop, 10 pops = 5%): the first "I got something" moment arrives early.
- **First 5 minutes:** first upgrade (Deep Satchel 3,000 shards after about 4 seams), first daily streak reward (free, immediate on the first login), first Track level.
- **First 20 minutes:** first Lurker fight, first contract, first specimens of higher grades from bigger chains, Codex/Cabinet filling, the goal chain of Goals.
- **First session:** the Track shows a visible ladder of free rewards, the Cabinet shows 42 empty slots, an Expedition is the big next step. That gives several parallel things to chase.
- **Second session:** the streak (day 2, better reward), fresh dailies and contracts, the world boss on the clock, the unclaimed Track rewards, and Plus supply drop if owned.
- **Long term:** Cabinet (42 slots, rare grades and pity), Track (30 levels then a repeating free reward), trait builds (four branches with forks and respec), Assay mastery, titles, Expedition depth and boss trophies, world boss, leaderboards.

### "Why keep playing after unlocking everything?"
1. **The Cabinet:** Celestial grades are 0.2% of drops (before chain luck), so completing all 42 slots is a long random chase that uses the core mechanic (bigger chains find rarer specimens), not a separate minigame.
2. **The build space:** each charge has a fork; a different fork changes how you play and what you plan. Respec costs 5,000 shards, so experimenting is cheap.
3. **Mastery and records:** Assay tiers to 4,000 pops per crystal, best chain, best depth, boss kills, the trophy hall, three leaderboards.
4. **Recurring things:** the streak, dailies, weeklies, contracts, the half-hourly world boss and the event calendar.
5. **The Track's free tail:** after level 30 every level still pays a free reward.
What is honestly still missing for a *month*: seasonal rotation of cabinet variants. Those are recommended future work, not built.

## 3. Gameplay loops now
- **Micro (seconds):** plan, plant, detonate, chain, floating numbers, camera feedback, possible specimen drop.
- **Short (10 to 60 s):** clear a seam, kill a Lurker, trigger Critical Mass, hit a chain tier, cut a specimen.
- **Session (5 to 20 min):** an Expedition (rooms, relics, bosses), a contract, a world boss window, a Track level, a streak claim.
- **Long term:** Cabinet completion, Track, builds, mastery, collections (Codex, Lurkers, bosses, relics), titles, leaderboards.

## 4. Priorities
- **P0 (done in this pass):** none of the earlier work was broken enough to block; the P0 gap was "no random chase and no free reward habit".
- **P1 (done):** Specimens + reveals, Track + Track Premium, Streak, UI QA tool, gem-animation performance fix.
- **P2:** done: split `UI.luau` per tab, per-grade sounds, shop FREE section, coalesced refresh. Still open: painted art, a small "Collection" dock entry, dedicated rarity recordings.
- **P3 (future):** rotating cabinet variants, seasonal Track (only if it stays optional), trading/showcase of specimens, cabinet display in the hub.

## 4b. Ideas deliberately NOT added (and why)
- **Prestige/rebirth:** the economy is not yet balanced from real play; a reset on top of an unverified curve would multiply the balance risk.
- **More areas:** four exist; adding more would recreate the "next area" treadmill.
- **Loot boxes for Robux:** the Cabinet is earned by playing only. Paid random rewards are not offered.

## 5. Monetization
**Existing (all ids nil until you create them):** 4 shard packs, 4 blast colours, 10 offers (tokens, boosts, bundles, finishers), 4 gamepasses (2x Shards, Prismatic Luck, Blastwright Plus, **Track Premium**), 1 optional subscription (Club).
**Free vs premium structure:** free daily streak, free Track reward on every level, dailies, weeklies, contracts, Goals, world boss and the whole Cabinet are free. Premium adds: the premium reward on every Track level (boosts, tokens, finishers, blast colours, titles), Plus daily supply drop and streak forgiveness, cosmetic finishers/blasts, convenience (tokens, boosts).
**Rules kept:** no random paid rewards, no fake countdowns, no purchase pop-ups without a click, price and contents always shown on the card, all grants server-side via `ProcessReceipt` (idempotent receipts), the Track Premium pass is checked on the server at claim time (`Purchases.Owns`).
**Still open:** a rotating/limited shop, first-purchase bundle timing rules, analytics beyond Roblox's own. The shop sections are: Featured, Boosts, Run support, Finishers, Bundles, Permanent perks, Blast colors, Shard packs. A dedicated "Free" section in the shop (streak + Track shortcut) is not built: free rewards live in the Daily and Goals tabs with dock badges.

## 6. QA results
### Verified (by tools)
- Tests: 292 passed (Luau CLI); new logic (Specimens, Track, Streak, traits, contracts, world boss, Assay, Plus) was mutation-checked; survivors were reviewed (equivalent mutants, listed in the commit notes).
- `python tools/lint/roblox_api_check.py`: 0 problems. `python tools/lint/ui_qa.py`: 0 errors, 0 warnings (see below for what it checks).
- `rojo build` succeeds; every client/server file compiles.
- Remote security review: all 22 client-to-server remotes are `guarded` (checked by grep: no `OnServerEvent` without it); argument types are validated (`Buy`: string kind and id; `Detonate`: pure `Validate.Volley`; `TrackClaim`: integer level, boolean track, level reached, pass owned, once; `StreakClaim`: no argument, once per UTC day; `Specimen` is server-to-client only).
- Client-trust check: the client never sends an amount, price or result; rewards are computed and stored server-side. XP, specimen rolls, streak and track claims are server-only.

### NOT verified (I cannot run Roblox Studio here)
- All visuals and layouts on desktop, tablet and phone (portrait/landscape), text overflow, clipping, overlap, ZIndex order, modal stacking, and touch targets beyond what `ui_qa.py` can see statically.
- Reveal animations, sounds, camera punch, the mythic flash.
- Real DataStore behaviour, purchase flows, multi-player behaviour, world boss with several players.
- Frame rate on phones.
These need your playtest; `docs/TESTING.md` E25 says what to look at.

### Issues found in this audit
- Gem spinners kept running in closed menus (a closed panel keeps its objects alive): **fixed** (visibility check every 0.5 s).
- No static UI QA existed: **added** `tools/lint/ui_qa.py` (placeholder text/ids, buttons without a handler, asset ids outside the allowed files, ZIndex outside the layer scheme, small touch targets, fixed widths over 640, fonts outside the design system). It found nothing in the current code beyond two false positives in its own first version.
- The menu panel rebuilt on every snapshot while open: **mitigated** (refreshes are coalesced to one per 0.3 s and keep the scroll position); a true per-row diff is not built.
- Several Heartbeat/RenderStepped connections exist (Fx gems and per-frame animations, Guide, Ambience, UI pulses, camera): each is a single shared loop, not per object; no leaks found by reading. Not profiled on a phone.
- `UI.luau` was about 1,400 lines: **split** (now about 920, with the tabs in `Client/Tabs/`).

## 7. Implementation status
| Item | Status |
|---|---|
| Specimen drops, pity, dupes, milestones, Cabinet tab | Implemented, logic tested; UI unseen |
| Rarity reveals (`Reveal.luau`) | Implemented; unseen, sounds reuse existing cues |
| Blastwright Track + Track Premium pass | Implemented, logic tested; UI unseen; **pass needs creating (manual)** |
| Daily streak | Implemented, logic tested; UI unseen |
| UI QA tool | Implemented and run |
| Painted art, real device QA, balance from play | **Requires you** |
| Ascension (5 opt-in Expedition difficulty tiers, `Shared/Ascension.luau`) | Implemented, logic tested and mutation-checked; UI unseen (added after the audit) |
| `UI.luau` split into `Client/Tabs/*` (pure move, checked line by line and with the analyser) | Implemented |
| Menu refresh coalescing (at most every 0.3 s, scroll position kept) | Implemented; unseen |
| Per-grade specimen sound signatures (pitch/layering of existing verified cues) | Implemented; unheard |
| Shop "FREE rewards" section (daily reward and free Track reward) | Implemented; unseen |
| Painted art, real recordings for rarity sounds, a true row-level diff of the menu | Future work |
