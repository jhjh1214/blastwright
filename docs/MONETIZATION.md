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
| Tiny | Shard Pouch | Developer Product | +500 shards x areas unlocked |
| Small | Shard Satchel | Developer Product | +2,500 x areas |
| Medium | Shard Chest | Developer Product | +8,000 x areas |
| Premium | Shard Vault | Developer Product | +30,000 x areas |
| Permanent | 2x Shards | Gamepass | Doubles shards earned from blasting (payouts and clear bonus; not daily or cache rewards) |
| Permanent | Prismatic Luck | Gamepass | Doubles the chance crystals spawn Prismatic (4% to 8%) |

Shard amounts scale with areas unlocked so a pack stays worth buying later in the game.

**Suggested Robux prices (my recommendation, not a fact about the platform; you decide):** Neon Pink 49, Pouch 49, Satchel 199, Chest 599, Vault 1,999; 2x Shards 499, Prismatic Luck 299. Consider tuning after seeing real player behavior.

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
See `docs/MANUAL_ACTIONS.md`. In short: publish the place, create 5 Developer Products and 2 Gamepasses in the Creator Dashboard, paste their IDs into `Config/Products.luau` (or send them to Claude to paste), test in a private server.
