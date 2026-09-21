# Publish guide: everything only you can do

Single ordered list of every manual step, so you can finish and publish the game without Claude. Code-side work is done; these steps need your Roblox account, Studio, or your own taste. Tick them off in order. Details for each live in the linked docs.

## 1. Run it once (30 min)
1. Terminal in the project folder: `rojo serve`.
2. Studio: new Baseplate, Rojo plugin, Connect, Play (or Test > 2 players).
3. Walk the checklist in `docs/TESTING.md` (sections A to E17). Note anything broken or ugly; the "Output" window should have no red errors.
4. Report problems back, or fix them yourself in `src/` (Rojo is the source of truth; never keep logic only in Studio).

## 2. Balance (do this AFTER step 1)
The game is unbalanced by design until it has been played. Placeholders are listed in `docs/BALANCE_BACKLOG.md` (game speed, daily/weekly rewards, boss HP, Lurker bounties, expedition income). Change numbers only in `Config/*`, then run `tools/bin/luau.exe tools/tests/core.spec.luau` and the sims in `tools/sim` (`docs/ECONOMY.md`).

## 3. Publish
1. Studio > File > Publish to Roblox (private at first).
2. Game Settings > Security > enable "Enable Studio Access to API Services".
3. Game Settings > Basic Info > **Max players 16** (there are 16 blast pads).
4. Complete the maturity questionnaire.

## 4. Create products (optional but that is the business)
**Step by step with every name, description and price: `docs/PAID_ITEMS_GUIDE.md`. Replacing the drawn shop graphics with painted art: `docs/SHOP_ART_GUIDE.md`.** The summary below is the short version.

All ids are `nil` until you paste them into `src/ReplicatedStorage/Shared/Config/Products.luau`. Items with a nil id show "Not for sale yet"; nothing breaks. Create at create.roblox.com > your experience > Monetization.

**Developer Products (18):**

| Config key | Name | Price hint (Robux) |
|---|---|---|
| ShardPouch / ShardSatchel / ShardChest / ShardVault | Shard Pouch / Satchel / Chest / Vault | your choice (49 / 199 / 499 / 1499 suggested) |
| NeonPinkStyle / VoidStyle / ToxicStyle / GoldenStyle | Neon Pink / Void / Toxic / Golden Blasts | 149-399 |
| EmergencyCharge | Emergency Charges | 15 |
| ShardBoost | 2x Shards (15 min) | 49 |
| LuckBoost | 2x Prismatic Luck (15 min) | 49 |
| ReviveToken | Expedition Revive | 49 |
| StarterBlast | Starter Blast | 99 |
| ExpeditionKit | Expedition Kit | 199 |
| CelestialFinisher | Celestial Finish | 249 |
| InfernoFinisher | Inferno Finish | 249 |
| BossHunter | Boss Hunter Pack | 499 |
| UltimateBlastwright | Ultimate Blastwright | 1499 |

(The shard packs and blast colors above are the 8 listed in `Config/Products.luau` under `DeveloperProducts` and `CosmeticProducts`; the 10 offers are `Offers`. That is 4 + 4 + 10 = 18.) Names and descriptions are in the config; copy them. Real prices are whatever you set in the dashboard.

**Gamepasses (4):** (also "Track Premium", `Gamepasses.TrackPremium`, see `docs/PAID_ITEMS_GUIDE.md`) "2x Shards" (`Gamepasses.DoubleShards`), "Prismatic Luck" (`Gamepasses.PrismaticLuck`) and "Blastwright Plus" (`Gamepasses.BlastwrightPlus`: title + a free daily supply drop of 3 emergency charges and a revive token; no power, nothing locked). Create all four in the dashboard.
**Subscription (optional):** "Blastwright Club", paste its id (a string) into `Club.SubscriptionId`.

Then: copy each numeric id, paste over `Id = nil`, `rojo build`, republish. Test each purchase once in a published private server (grants once, persists after rejoining). Never paste an id you did not create.

## 5. Assets (see `docs/MANUAL_ASSETS.md`)
- The 8 decor models are already in your inventory (done). If you publish under a different account/group, add them to that inventory again.
- Optional painted icons: the UI draws its own icons; to replace, upload a consistent set and fill `Icons.Assets` in `Client/Icons.luau` (real ids only).
- Optional extra music: `Config/Music.luau`.

## 6. Presentation
Thumbnail, icon, 3 to 5 screenshots, description, tags. Hook text is in `docs/GAME_CONCEPT.md`. Creators to credit are in `docs/ASSET_REGISTRY.md`.

## 7. Launch (see `docs/LAUNCH_CHECKLIST.md`)
Persistence check in the published place, phone/emulator check, soft launch to friends, then public. Live events (`Config/Events.luau`) and the weekly challenges are the reasons to return; adjust numbers using the sims.

## Known gaps (not built)
Rotating shop, analytics beyond Roblox's own, painted art, and the balance pass. Built and listed for testing in docs/TESTING.md: Expeditions, bosses, Notice Board, world boss (Crystal Colossus), Assay Office, Blastwright Plus.
