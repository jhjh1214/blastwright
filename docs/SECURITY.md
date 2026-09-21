# Security audit

Assume the client is fully modifiable. The server decides everything that matters; the client only sends intents and draws the result. This audit was done by reading the code (2026-09-21); **nothing here was tested against a real exploit tool.**

## Every client-to-server entry point
All handlers go through a per-player, per-remote token bucket (`Server/RateLimiter.luau`, tested) before any work is done.

| Entry point | Limit (per second / burst) | What is validated | What the client can never decide |
|---|---|---|---|
| `Detonate` | 6 / 10 | Payload is a table of at most 8 entries; each entry rebuilt clean (extra fields stripped); coordinates finite integers in range; charge kind must be unlocked in the server's record; no duplicate cells; count within remaining charges; character within 45 studs of the site station; 0.15 s cooldown; one volley in flight | The outcome (the server runs the simulation), rewards, multipliers, momentum, daily/goal progress |
| `Buy` | 5 / 8 | `kind` and `id` must be strings; id looked up in config; cost checked against the server's shards; areas only in order | Prices, ownership, shards |
| `Claim`, `ClaimWeekly` | 5 / 8 | Slot must be an integer 1-3 of today's/this week's objectives, complete, and not already claimed (`Dailies.CanClaim`) | Progress, completion, reward size |
| `ContractAccept` | 4 / 6 | Tier must be an integer naming one of today's offers, or the string "abandon"; only one active contract; a finished one cannot be retaken (`Contracts.Accept`, hostile tiers tested) | Which contract is active |
| `ContractClaim` | 3 / 5 | No argument; pays only when the active contract is complete (`Contracts.Claim`) once | Reward |
| `ClaimGoal` | 5 / 8 | Id must be a string naming a real goal, complete and unclaimed (`Achievements.CanClaim`) | Progress, reward size |
| `Equip` | 5 / 8 | Id must be a string naming a style the server says the player owns (`Cosmetics.CanEquip`) | Ownership |
| `Setting` | 5 / 8 | Name must be `Music`, `Sfx` or `Shake`, value a boolean (`Validate.Setting`) | Anything except those three flags |
| Site prompt | 3 / 5 | Player within 30 studs of the station; area unlocked; pad free | Pad ownership, area gating |
| Cache prompt | 3 / 5 | Player within 25 studs; cache id from config; once per player (saved) | Reward size, repeats |

## Purchases
- Developer products grant **only** in `MarketplaceService.ProcessReceipt` (`Server/Purchases.luau`); `PurchaseId` is recorded first so retries never double-grant; success is reported only after the save succeeds.
- Gamepass ownership is read from Roblox on join and from the server-side purchase-finished event. No client message can grant anything.
- Product ids are configuration, never invented.

## Data
- Saves use `UpdateAsync` with a session lock (another server's fresh lock is never overwritten), retries with backoff, autosave, and a shutdown save. Loaded data is migrated and sanitized (`Schema.Migrate`): wrong types replaced, NaN/negative/infinite shards zeroed.
- The client never sends save data. A client cannot cause a write except through the validated actions above.

## Third-party assets
- Decor models are loaded once by the server and stripped to plain geometry (scripts, sounds, remotes, prompts, particles, lights and GUIs destroyed). Nothing from them runs. See `docs/ASSET_REGISTRY.md`.

## Known residual risks (not fixed)
- **Movement lock is client-side only.** An exploiter can walk while in blast mode; the server still requires proximity to blast, so this gives no advantage.
- **Teleporting to caches.** The server checks the player is within 25 studs when they trigger a cache, but an exploiter can teleport there, so caches can be looted quickly. The reward is once per player and modest; no server-side movement validation was built.
- **Kick on abuse.** Excess calls are silently dropped; nobody is kicked or logged. If abuse shows up in a live game, add logging of dropped calls per player.
- **Cosmetic client data.** A modified client could show its own visuals (for example a different blast color locally); other players see only what the server broadcasts.
- **Leaderboard.** Values come from the server's own stats, so they cannot be forged by remotes, but nothing detects inflated stats caused by a bug.
- **Untested in a live server:** DataStore locking, retries and the shutdown save have only been reviewed, not stress-tested.

## Before launch
1. Re-run this table against the code (new remotes must be added here and go through `guarded`).
2. Test a save/rejoin cycle and a server shutdown in a published place.
3. Make one purchase per product in a private server and confirm it grants once and persists.

Later additions: `AssayClaim` (5 / 8): kind must be a real crystal id and tier an integer for an existing tier, reached and unclaimed (`Assay.Claim`, hostile ids tested). The world boss and Plus have no client input: they run from the server clock and `Purchases.Owns`.

Pass 3 additions: `TrackClaim` (5 / 8): level must be an integer, the track a boolean, the level must be reached, premium needs `Purchases.Owns(player, "TrackPremium")` checked on the server, each reward once (`Track.Claim`). `StreakClaim` (2 / 3): no argument, once per UTC day (`Streak.Claim`). `Specimen` is server-to-client only (the server rolls with its own `Random`; the client never sends or influences a drop). Track XP is only added by server code paths. Audit result: all 22 client-to-server remotes are wrapped in `guarded`.
