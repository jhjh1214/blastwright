# Monetization

**Status:** framework built and unit-tested where it can be; **no real purchase has ever been made or tested**, because no product IDs exist yet. Every ID in `Config/Products.luau` is `nil` on purpose and nothing is invented.

## Principles
- Free players get the whole game. Everything is earnable by playing; purchases save time.
- Nothing is granted because a client said so. Developer products grant **only** in `MarketplaceService.ProcessReceipt` (`Server/Purchases.luau`).
- With a `nil` ID the shop shows the item as "Not for sale yet", the button is disabled, and nothing crashes.

## What is for sale (all defined in `Config/Products.luau`)
| Tier | Item | Type | What it does |
|---|---|---|---|
| Tiny | Neon Pink Blasts | Developer Product | Unlocks the Neon Pink blast color (cosmetic only) |
| Tiny | Shard Pouch | Developer Product | +2,500 shards x areas unlocked |
| Small | Shard Satchel | Developer Product | +12,500 x areas |
| Medium | Shard Chest | Developer Product | +40,000 x areas |
| Premium | Shard Vault | Developer Product | +150,000 x areas |
| Permanent | 2x Shards | Gamepass | Doubles shards earned from blasting (payouts and clear bonus; not daily or cache rewards) |
| Permanent | Prismatic Luck | Gamepass | Doubles the chance crystals spawn Prismatic (4% to 8%) |

Shard amounts scale with areas unlocked so a pack stays worth buying later in the game.

**Suggested Robux prices (my recommendation, not a fact about the platform; you decide):** Neon Pink 49, Pouch 49, Satchel 199, Chest 599, Vault 1,999; 2x Shards 499, Prismatic Luck 299. Consider tuning after seeing real player behavior.

## The full ladder (added 2026-09-21, all in `Config/Products.luau` `Offers`; IDs all nil)
Design rules from the developer brief: cheap impulse buys, a ladder of tiers, cosmetics as a pillar, premium bundles that are COLLECTIONS (not "10x currency"), no purchase prompts mid-run, nothing that gates core play. Prices below are hints for you when creating the products (the real price is set in the Creator Dashboard; code never reads it).

| Tier | Item (key) | What it gives |
|---|---|---|
| Tiny (~15) | Emergency Charges (`EmergencyCharge`) | 3 emergency-charge tokens: press the button when running dry, +1 charge each (not in the Daily Puzzle) |
| Small (~49) | 2x Shards 15 min (`ShardBoost`) | Timed x2 shards, stacks up to 2 hours |
| Small (~49) | 2x Prismatic Luck 15 min (`LuckBoost`) | Timed x2 rare-crystal chance |
| Small (~49) | Expedition Revive (`ReviveToken`) | One Revive token: when an Expedition floor is about to collapse, spend it to continue with 2 hearts and 3 charges (offer appears once per floor, only if crystals remain) |
| Small (~99) | Starter Blast (`StarterBlast`) | Shards + 15 min boost + 3 emergency charges |
| Medium (~199) | Expedition Kit (`ExpeditionKit`) | 3 revives, 5 emergency charges, 30 min boost |
| Medium (~249) | Celestial / Inferno Finish (`CelestialFinisher`, `InfernoFinisher`) | The colours of your boss FINAL BLAST (cosmetic) |
| Large (~499) | Boss Hunter Pack (`BossHunter`) | Void finisher, "Boss Hunter" title, 5 revives, shards |
| Premium (~1,499) | Ultimate Blastwright (`UltimateBlastwright`) | All finishers, Void + Toxic blasts, title, 10 revives, 20 charges, 60,000 shards x areas |
| Cosmetic | Neon Pink / Void / Toxic / Golden Blasts (`CosmeticProducts`) | Blast colors |
| Subscription | Blastwright Club (`Club.SubscriptionId`) | Monthly 25,000 shards and the "Club Member" title; claim in Shop (Roblox is asked at claim time whether the subscription is active) |

Grants live in pure `Shared/Grants.luau` (tested, mutation-checked: boosts stack and cap, tokens cap, invalid grants are ignored entirely). Receipts stay idempotent through the existing path. Not built: Blastwright Plus pass, price optimisation hooks, private-server features, rotating shop and analytics (conversion / spend tracking) beyond what Roblox itself reports.

## How a purchase is processed (Server/Purchases.luau)
1. Player buys through the Roblox prompt (opened from the Shop tab).
2. Roblox calls `ProcessReceipt`. We find the player, check their data is loaded, look up the product, and record the `PurchaseId` in `data.Purchases` (`Receipts.Apply`). A repeated id is a duplicate and grants nothing.
3. We grant, then **save**. Only when the save succeeds do we return `PurchaseGranted`; otherwise `NotProcessedYet`, and Roblox retries. The retry skips the (already recorded) grant and only retries the save.
4. If the grant itself throws, the record is reverted so the retry can grant it properly.
5. Gamepasses: ownership is read with `UserOwnsGamePassAsync` on join and updated by the server-side `PromptGamePassPurchaseFinished` event.

## Tested vs not
- Tested (unit tests + mutation tests): idempotency, bounded purchase history, shard amounts, config validity (no malformed/duplicate ids), the Prismatic Luck spawn chance.
- **Not tested:** `ProcessReceipt` end to end, `UserOwnsGamePassAsync`, the purchase prompts, and the effect of 2x Shards in a live session. These need real product IDs in a published place.

## To turn it on
See `docs/MANUAL_ACTIONS.md`. In short: publish the place, create the 18 Developer Products and 3 Gamepasses in the Creator Dashboard, paste their IDs into `Config/Products.luau` (or send them to Claude to paste), test in a private server.

## Blastwright Plus (gamepass, built)
`Gamepasses.BlastwrightPlus` (id nil until you create it). Comfort and recognition only: the "Blastwright Plus" title (equip it in the Forge) and a free supply drop once per UTC day (3 emergency charges + 1 revive token), paid on join or at once after buying. Logic in `Shared/Plus.luau` (tested, once per day), numbers in `Config/Plus.luau`. Suggested price 399 Robux.

## Roblox's own "Shop" button (native, not our code)
Roblox has a separate, native "Shop" surface: a system overlay listing your Game Passes and eligible Developer Products automatically, plus Robux packages. It appears two ways: inside Roblox's own in-game menu (on by default) and as an optional persistent icon at the top-left of the screen next to the Roblox top bar, which is off by default and is turned on per-experience at create.roblox.com > your experience > **Monetization > Shop > Overview** (a dashboard setting, not a Studio or code setting).

**It does not clash with our custom SHOP dock button.** They are two independent systems: Roblox's is a CoreGui overlay Roblox itself renders (`Enum.CoreGuiType.ExperienceShop`) with no API to trigger, embed or restyle it from game code — it cannot be "wrapped" in our own UI, and nothing in this codebase touches it (verified: no `CoreGuiType`/`SetCoreGuiEnabled` calls anywhere in `src/`). Ours is a normal ScreenGui button drawn by `Client/Dock.luau` that opens `Client/Tabs/Shop.luau`. No shared remotes, no shared state, no z-index conflict (it renders above all game UI, by Roblox's design, like the Backpack or Chat).

**What it shows vs. what ours shows:** Roblox's native Shop is a flat list Roblox auto-ranks, with no categories, no bundle framing, no art beyond the icon you set per item, and no non-Robux content — it cannot show the FREE rewards section, the daily streak, or the Track. Our Shop tab is the themed, categorized, art-capable one (Featured, Boosts, Support, Finishers, Bundles, Perks, Blast colors, Shard packs, FREE rewards) and is the one to keep improving.

**Recommendation: leave the native one enabled.** Roblox recommends it, it costs nothing (no code, no maintenance — it is populated automatically from whatever products/passes you've created), and it is a second free discovery path for the same purchases, including possible surfacing outside the experience itself. It does not replace or reduce the value of our own Shop tab. `Config/Products.luau`'s existing `ProcessReceipt` implementation (`Server/Purchases.luau`) is idempotent and already reports `PurchaseGranted` only after a durable save, which is what Roblox requires for a product to be "eligible" for this surface, so no code change is needed either way.

Sources: [Shop docs](https://create.roblox.com/docs/production/monetization/shop), [Per-place control over the global Shop button (DevForum)](https://devforum.roblox.com/t/per-place-control-over-the-global-shop-button/4715060).
