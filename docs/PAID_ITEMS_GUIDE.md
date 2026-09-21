# Paid items: exactly how to create them and hook them up

Everything you sell is defined in `src/ReplicatedStorage/Shared/Config/Products.luau`. Every `Id` is `nil` until you create the item on Roblox and paste its number in. **Until then the Shop shows "Not for sale yet" for that item and nothing else is affected**, so you can start with a few items and add the rest later. Never invent an id.

Total: **18 Developer Products, 3 Gamepasses, 1 optional Subscription.**

## 0. Before you start (once)
1. Studio: File > Publish to Roblox. The experience must exist before products can.
2. Studio: Game Settings > Security > turn on "Enable Studio Access to API Services".
3. Open https://create.roblox.com/dashboard/creations and click your experience. All items below live under **Monetization** in the left menu.
4. Prepare an icon per item if you can (512 x 512 PNG, see `docs/SHOP_ART_GUIDE.md`). Icons are optional for the game to work, but Roblox shows them on the purchase prompt, so they matter for conversion.

## 1. Developer Products (consumables): Monetization > Developer Products > Create
For each row: click **Create**, paste the **Name** and **Description**, set the **Price**, upload an icon, **Save**. Then open the item and copy its numeric **Product ID** (also shown in the URL). Prices are Robux and are only suggestions: the code never reads them, so change them freely in the dashboard.

| # | Config key | Name (copy exactly) | Description (copy) | Suggested price |
|---|---|---|---|---|
| 1 | `ShardPouch` | Shard Pouch | A small pouch of shards. | 49 |
| 2 | `ShardSatchel` | Shard Satchel | A satchel of shards. | 199 |
| 3 | `ShardChest` | Shard Chest | A heavy chest of shards. | 499 |
| 4 | `ShardVault` | Shard Vault | A whole vault of shards. | 1499 |
| 5 | `NeonPinkStyle` | Neon Pink Blasts | A hot pink blast color for your charges. | 99 |
| 6 | `VoidStyle` | Void Blasts | Deep violet blasts that seem to swallow the light. | 149 |
| 7 | `ToxicStyle` | Toxic Blasts | Acid green blasts. | 149 |
| 8 | `GoldenStyle` | Golden Blasts | Pure gold blasts for a proper flex. | 399 |
| 9 | `EmergencyCharge` | Emergency Charges | 3 spare charges you can use any time you are running dry. | 15 |
| 10 | `ShardBoost` | 2x Shards (15 min) | Double shards from blasting for 15 minutes. Stacks up to 2 hours. | 49 |
| 11 | `LuckBoost` | 2x Prismatic Luck (15 min) | Twice as many Prismatic crystals for 15 minutes. | 49 |
| 12 | `ReviveToken` | Expedition Revive | Continue a collapsed Expedition floor instead of losing your haul. | 49 |
| 13 | `StarterBlast` | Starter Blast | Shards, a boost and an emergency stock to kick things off. | 99 |
| 14 | `ExpeditionKit` | Expedition Kit | 3 revives, 5 emergency charges and a 30 minute shard boost. | 199 |
| 15 | `CelestialFinisher` | Celestial Finish | Your boss kills end in a blue-white celestial FINAL BLAST. | 249 |
| 16 | `InfernoFinisher` | Inferno Finish | Your boss kills end in a roaring red inferno. | 249 |
| 17 | `BossHunter` | Boss Hunter Pack | Void finisher, the Boss Hunter title, 5 revives and a pile of shards. | 499 |
| 18 | `UltimateBlastwright` | Ultimate Blastwright | Every finisher, Void and Toxic blasts, an exclusive title, revives, emergency charges and a huge shard pile. | 1499 |

What each one gives is defined in the config (`Amount`, `Cosmetic`, `Grants`), not by the dashboard, so the dashboard only needs the name, description, price and icon.

## 2. Gamepasses (permanent): Monetization > Passes > Create
| Config key | Name | Description | Suggested price |
|---|---|---|---|
| `DoubleShards` | 2x Shards | Permanently doubles the shards you earn from blasting. | 499 |
| `PrismaticLuck` | Prismatic Luck | Doubles the chance that crystals spawn Prismatic (worth 3x). | 299 |
| `BlastwrightPlus` | Blastwright Plus | The Blastwright Plus title and a free supply drop every day (3 emergency charges and a revive token). Supports the game; no power, nothing locked. | 399 |

A pass needs an icon before it can be put on sale, and "Item for sale" must be switched on. Copy each pass's numeric ID from its page (the number in the URL).

## 3. Subscription (optional): Monetization > Subscriptions > Create
Name "Blastwright Club", monthly, a price you choose (for example 199 to 299 Robux a month). Copy its **subscription id**, which is a text like `EXP-123456...` (not a number), into `Club.SubscriptionId` (keep the quotes). Members claim a monthly shard allotment and the "Club Member" title in the Shop. If you skip it the Club card just says it is not available.

## 4. Paste the ids into the code
Open `src/ReplicatedStorage/Shared/Config/Products.luau`. Replace each `Id = nil` with the number, for example:
```lua
ShardPouch = { Id = 1234567890, Name = "Shard Pouch", ... },
```
Keep the `Name` and everything else. The file's own test checks that ids are positive whole numbers with no duplicates: run `tools/bin/luau.exe tools/tests/core.spec.luau` afterwards (all tests should still pass). Then in Studio with Rojo connected the change goes live in your test place; publish again for the real game (File > Publish to Roblox).

You can also send me the list and I will paste them for you.

## 5. Test every purchase before launch
1. Publish, then open the game from the Roblox website (not Studio) in a **private server** or with a test account, because Studio test purchases do not prove the live flow.
2. Buy each item once with real Robux (you can refund yourself later) or a low-cost test: check that it grants, that the Shop updates, and that after leaving and rejoining it is still there.
3. Things to check: shard packs add shards; boosts show a timer and stack; revive and emergency charge counts change; finishers and blast colors can be equipped (Forge/Codex); Blastwright Plus gives the title and a supply drop once per day; Club claim works.
4. If a purchase charges but does not grant, look at the Output/Developer Console (F9) for a `[Purchases]` warning and tell me the text. Purchases are safe against double-granting: the same receipt is never applied twice.

## 6. Making it look good on the Roblox purchase prompt
The prompt shows the item's icon and name from the dashboard. Use the same art you use in the in-game shop (`docs/SHOP_ART_GUIDE.md`) so the two match.

## Pricing and fairness notes
- Nothing gates the core game: you can play everything for free. Paid items are speed-ups (shards, boosts), safety nets (revives), and cosmetics/flex items (blast colors, finishers, titles).
- The shard packs give `Amount` shards per area you have unlocked, so a pack stays worth something later. With the new slower progression (docs/BALANCE_BACKLOG.md), look at the pack sizes after your balance pass and adjust `Amount` if packs feel too strong or weak.
- Robux prices in the dashboard are yours to change at any time without touching the code.
