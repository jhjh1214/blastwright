# Manual Actions

```
========================================
MANUAL ACTION REQUIRED
========================================
ACTION:
Run the first playtest in Studio.

WHY:
I can compile, unit-test and Rojo-build the code, but cannot run Roblox Studio interactively.
Whether the game works and is fun has not been verified.

EXACT STEPS:
1. In a terminal in this folder: rojo serve
2. In Studio: new Baseplate place, open the Rojo plugin, click Connect.
3. Press Play (or Test > 2 players).
4. Follow the checklist in docs/TESTING.md.

WHAT YOU SHOULD SEE:
A dark crystal mine: hub plaza, roads, four biomes, blast pads. Using a pad station opens the top-down grid; tapping plants charges; Detonate triggers a cascade; shards count up. Geode caches are hidden off the roads.

THEN:
Return to Claude and say "Done: playtest" and paste any Output errors or notes on how it felt.
========================================
```

```
========================================
MANUAL ACTION REQUIRED (when you want to sell things)
========================================
ACTION:
Publish the experience, then create the Developer Products (18 in total, you can start with a few) and 2 Gamepasses (optionally 1 subscription).

WHY:
Only your Roblox account can create products. Until then the Shop shows "Not for sale yet" and everything else works.

EXACT STEPS:
1. Studio > File > Publish to Roblox (also enables DataStore saving and the Studio API access toggle below).
2. Studio > Game Settings > Security > turn on "Enable Studio Access to API Services" (lets you test saving in Studio).
3. create.roblox.com > Creations > your experience > Monetization > Developer Products > Create. The full list is in `Config/Products.luau` (docs/MONETIZATION.md has names and price hints): 4 shard packs, 4 blast-color products (Neon Pink, Void, Toxic, Golden) and 10 offers (Emergency Charges, 2x Shards 15 min, 2x Luck 15 min, Expedition Revive, Starter Blast, Expedition Kit, Celestial Finish, Inferno Finish, Boss Hunter Pack, Ultimate Blastwright). Start with a handful if you prefer; anything left at `Id = nil` simply shows "Not for sale yet".
   Optional: Monetization > Subscriptions > create "Blastwright Club" and paste its subscription id into `Products.Club.SubscriptionId`.
4. Same area > Passes > Create. Make two: "2x Shards" and "Prismatic Luck".
5. Copy each product's numeric ID.
6. Paste the IDs into src/ReplicatedStorage/Shared/Config/Products.luau (replace each `Id = nil`), or send them to Claude to do it.
7. Test in a published Private Server (Studio test purchases cannot prove the live flow).

WHAT YOU SHOULD SEE:
The Shop tab shows "Buy" instead of "Not for sale yet". After buying a shard pack the shard total rises and it stays after rejoining.

THEN:
Return to Claude and say "Done: products created" with the IDs.
========================================
```

Also set the experience's max players to 16 or fewer (Game Settings > Basic Info) because there are 16 blast pads.

## Painted icons (optional, later)
The UI icons are drawn from Frames (`Client/Icons.luau`) so they always show and match the chunky style. To upgrade to painted art: make or commission one consistent icon set (same outline weight and palette), upload it in the Creator Dashboard under your own account, and paste the real image ids into `Icons.Assets` (name -> `rbxassetid://<id>`). Never guess an id. Icons without an entry keep the drawn version.
