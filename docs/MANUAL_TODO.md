# Everything you have to do by hand (master list)

The code is finished; these are the things only you can do (your Roblox account, Studio, your eyes and ears). Do them in order. Each section links to the detailed guide.

- [ ] **1. Playtest** the whole game once (section 1)
- [ ] **2. Balance** the numbers from what you saw (section 2)
- [ ] **3. Publish** the experience and set its settings (section 3)
- [ ] **4. Create the paid items** and paste their ids (section 4)
- [ ] **5. Make and upload the art** (section 5, the asset list with prompts)
- [ ] **6. Optional audio** (section 6)
- [ ] **7. Store page, thumbnails, description** (section 7)
- [ ] **8. Final checks and launch** (section 8)

---

## 1. Playtest (about 1 to 2 hours)
1. Terminal in the project folder: `rojo serve`. Studio: open a Baseplate, Rojo plugin > Connect, press Play (also try Test > 2 players).
2. Walk through `docs/TESTING.md`, sections E2 to E27 (each section says what you should see). Keep Output open: there should be no red errors.
3. Test on a phone-size window too: Studio > Test > Device Emulator, both portrait and landscape. Look for text that is cut off, overlapping buttons, and the top boss info column crowding the left status cards.
4. Write down anything wrong or ugly and send it to me, or fix numbers yourself (section 2).

## 2. Balance (after the playtest)
The numbers are estimates from simulations, not from real play. Everything lives in `src/ReplicatedStorage/Shared/Config/*`:
- Prices and pace: `Upgrades`, `Charges`, `Strata`, `Traits`, `Farm` (list of placeholders in `docs/BALANCE_BACKLOG.md`).
- Rewards: `Dailies`, `Weeklies`, `Achievements`, `Contracts`, `Track`, `Streak`, `Assay`, `Specimens`, `WorldBoss`, `Ascension`.
- Then run `tools/bin/luau.exe tools/tests/core.spec.luau` (all tests should still pass) and the simulators in `tools/sim` (`docs/ECONOMY.md`).
Questions to answer while playing: how long until the first area unlock (target: a couple of Expeditions), do specimens drop often enough to feel exciting (about 1 volley in 20), are the Track levels arriving at a good rate, is Ascension 1 to 5 hard but fair.

## 3. Publish and experience settings
1. Studio: File > Publish to Roblox (keep it private while you test).
2. Game Settings > Security: turn on "Enable Studio Access to API Services" (needed to test saving).
3. Game Settings > Basic Info: **Max players = 16** (there are 16 blast pads).
4. Game Settings > Avatar: leave the default.
5. Fill in the maturity questionnaire (no chat features, no user content, fantasy mining).

## 4. Paid items (18 products, 4 passes, 1 optional subscription)
Follow **`docs/PAID_ITEMS_GUIDE.md`**. It has every name, description and suggested price to copy, where to click, how to paste the ids into `Config/Products.luau`, and how to test each purchase. You can start with a few and add the rest later: anything left at `Id = nil` shows "Not for sale yet". Never invent an id.

Also for each product/pass you need a **purchase-prompt icon** (512 x 512): see the asset list, group C.

## 5. Art to make and upload (the full list, with prompts)
Read **`docs/SHOP_ART_GUIDE.md`** first for the workflow. This section is the complete asset list, ready to paste into an image tool.

### 5.0 The style (use it for EVERY image so they match)
**Master style prompt (put this first, then add the subject):**
> chunky cartoon game art for a Roblox mining game, thick dark purple outline (#1A1228), bold saturated colours, glossy highlights, soft top-left light, subtle drop shadow, high contrast, clean shapes, centred subject, simple gradient background, no text, no letters, no watermark, mobile game UI style

**Negative prompt (if your tool has one):** text, letters, numbers, watermark, logo, realistic photo, blurry, thin lines, dark muddy colours, multiple subjects, cropped subject

Rules: same tool, same settings and same style prompt for all images; generate 4 to 8 versions of each and pick the best; view at 25% size (it must still read on a phone); check that the tool's licence allows commercial use.
Palette to stay inside: crystal blue #3A96FF, gold #FFCA28, red #EE3E4E, green #46C660, purple #AA5AFF, orange #FF9228, lime #8ECE3A, dark outline #1A1228.

### 5.A Shop card pictures (23 images, 1024 x 512 PNG, 2:1)
Paste the master style prompt, then the subject. File name = the product name. Keep the bottom 25% uncluttered (the price and BUY button sit on top).

| # | Product name (exact key) | Subject to add to the prompt |
|---|---|---|
| 1 | Shard Pouch | a small leather pouch spilling a few glowing blue crystal shards |
| 2 | Shard Satchel | a satchel bag overflowing with glowing blue crystal shards |
| 3 | Shard Chest | an open wooden treasure chest heaped with glowing blue crystal shards |
| 4 | Shard Vault | a huge steel vault door open, a mountain of blue crystal shards glowing inside |
| 5 | Neon Pink Blasts | a hot pink neon crystal explosion with sparks and a shockwave ring |
| 6 | Void Blasts | a deep violet dark-matter explosion swallowing light, purple rim glow |
| 7 | Toxic Blasts | an acid green toxic explosion with bubbling glowing slime sparks |
| 8 | Golden Blasts | a pure gold explosion with shimmering gold shards and a crown-like flare |
| 9 | 2x Shards | a big glowing gem with a large shiny multiplication-style "2x" energy burst (no letters, use a stylised X made of light) |
| 10 | Prismatic Luck | a rainbow prismatic crystal with a four-leaf-clover shaped sparkle |
| 11 | Blastwright Plus | a golden crown with a small bomb and crystals on it, premium gold and purple |
| 12 | Track Premium | a glowing golden ticket / pass with a star and a ribbon, premium gold |
| 13 | Emergency Charges | three round bombs with lit fuses in a small crate, red and orange |
| 14 | 2x Shards (15 min) | a gem with a lightning bolt and a stopwatch, blue and gold |
| 15 | 2x Prismatic Luck (15 min) | a rainbow crystal with a stopwatch and sparkles |
| 16 | Expedition Revive | a red heart with a lightning bolt through it, glowing |
| 17 | Starter Blast | a gift box bursting with crystals, a bomb, and a small bolt, celebratory |
| 18 | Expedition Kit | a mining backpack with a heart, three bombs and a lantern strapped on |
| 19 | Celestial Finish | a blue-white celestial explosion, star burst and halo rings |
| 20 | Inferno Finish | a roaring red-orange inferno explosion with flames and embers |
| 21 | Boss Hunter Pack | a stone boss trophy head (crystal golem) on a gold plaque with crossed bombs |
| 22 | Ultimate Blastwright | a legendary golden treasure hoard: crown, trophy, crystals, bombs, rainbow glow |
| 23 | Blastwright Club | a golden membership badge shield with a crystal in the middle |

### 5.B In-game UI icons (16 images, 256 x 256 transparent PNG)
Chunky, one subject filling about 80% of the square, thick dark outline, transparent background (ask the tool for "transparent background" or remove the background afterwards). These replace the drawn icons only if you fill `Icons.Assets`; leave any out to keep the drawn one.

| Icon name (exact key) | Subject |
|---|---|
| Forge | an anvil with a glowing hot crystal on it and a hammer |
| Loadout | a round black bomb with a lit fuse and a small spark |
| Shop | a market stall / shopping bag with a red awning and a gem |
| Daily | a calendar page with a big star |
| Goals | a golden trophy cup |
| Codex | an open glowing book with a blue crystal above it |
| Farm | a crystal plant / sprout growing from soil, green |
| Gem | a faceted cyan diamond |
| Bomb | a round black bomb, lit fuse |
| Bolt | a yellow lightning bolt |
| Close | a white chunky X on a red rounded button |
| Heart | a red heart with a highlight |
| Lock | a golden padlock |
| Skull | a friendly cartoon skull with big eye sockets |
| Star | a gold five-point star |
| Clock | a round clock with a red centre and white face |

### 5.C Purchase-prompt icons (Roblox dashboard, 512 x 512 PNG, one per item)
Reuse the shop card picture, cropped to a square around the subject (or generate a square version with the same prompt). Needed for all 18 products, the 4 passes and the subscription: 23 images, same subjects as table 5.A. Upload them in the Creator Dashboard on each item (`docs/PAID_ITEMS_GUIDE.md`, section 1 to 3). Passes cannot go on sale without an icon.

### 5.D Experience icon and thumbnails
| Asset | Size | Subject and prompt addition |
|---|---|---|
| Game icon | 512 x 512 | the master style + "a glowing blue crystal cavern explosion, a miner's bomb in the foreground, dramatic chain reaction of crystals, vivid, big and simple so it reads tiny" |
| Thumbnail 1 | 1920 x 1080 | a huge chain reaction of glowing crystals exploding in a cavern, gold and blue, cinematic (or a screenshot of a big chain in the game) |
| Thumbnail 2 | 1920 x 1080 | the boss fight: a giant crystal golem with glowing weak points (best as a real screenshot) |
| Thumbnail 3 | 1920 x 1080 | the loot: specimens and rewards (a screenshot of the Specimen Cabinet or a reveal) |
| Thumbnail 4-5 | 1920 x 1080 | the hub with the trophy hall / four areas (screenshots) |
Real in-game screenshots (Studio: Test > Play, then the screenshot tool) usually convert better than generated images; take them at the biggest chain and boss moments.

### 5.E Optional extras (nice to have, not required)
- **Specimen grade artwork** (6 small badges, 256 x 256): Rough, Polished, Faceted, Flawless, Radiant, Celestial as one crystal in six increasingly fancy cuts and colours (grey, green, blue, purple, gold, pink). They are not wired to anything yet; the reveal uses a spinning 3D-style crystal. If you make them, tell me and I will hook them into the Cabinet rows.
- **Title badges** for the trophies and titles (Track Master, Grand Curator, Ascendant I to V): not wired; optional future work.

### 5.F Upload, get the ids, paste them in
1. Studio > View > **Asset Manager** > right-click **Images** > **Bulk Import** > choose all PNGs. Or upload at create.roblox.com > your experience > Assets/Development Items > Images.
2. Right-click each image > **Copy ID to Clipboard**. Turn it into `rbxassetid://` + number.
3. Test one in an ImageLabel in Studio first. If it does not show, you copied a Decal id: use the Image entry or upload again as an Image.
4. Paste into the two tables:
   - Shop pictures: `ShopArt.Images` in `src/StarterPlayer/StarterPlayerScripts/Client/ShopArt.luau`, key = the exact product name, e.g. `["Shard Pouch"] = "rbxassetid://123",`.
   - UI icons: `Icons.Assets` in `src/StarterPlayer/StarterPlayerScripts/Client/Icons.luau`, key = the icon name, e.g. `Shop = "rbxassetid://456",`.
   - Or send me the list (name and id) and I paste them.
5. Run `python tools/lint/ui_qa.py` and `python tools/lint/roblox_api_check.py` (both should print 0 errors) and the test suite.

## 6. Optional audio
The game already has music, ambience and 7 sound cues, all working. Optional upgrades:
- **Rarity sounds:** the specimen reveals reuse existing cues with different pitch and layering. For dedicated sounds, find or record 6 short stingers (Rough to Celestial, 0.5 to 3 seconds) in the Creator Store/Audio library (use `tools/asset-search/audio_search.py <cue> <max_secs> <keywords>`), then add cues to `Config/Sounds.luau` and use them in `Client/Reveal.luau`. Suggested keywords: "coin", "chime", "magic sparkle", "level up", "epic reveal", "legendary".
- **Extra music:** add tracks in `Config/Music.luau`.
- Do not paste an audio id you have not checked in Studio; unowned or moderated audio simply will not play.

## 7. Store page
- Experience name and a one-sentence hook (ideas in `docs/GAME_CONCEPT.md`), description (what you do, chain reactions, bosses, collecting), genres/tags (adventure, action, simulator-like, PvE).
- Attribution for third-party assets is listed in `docs/ASSET_REGISTRY.md` if you want to credit creators.
- Turn on the Roblox features you want (private servers are fine; the game does not need them).

## 8. Final checks and launch (see `docs/LAUNCH_CHECKLIST.md`)
1. In the published place: play, earn shards, buy an upgrade, leave and rejoin (progress must be there).
2. Buy each paid item once in a private server (grants once, persists).
3. Two players in one server: pads, the world boss, leaderboards behave.
4. Phone check on a real device if you have one.
5. Run all three checks: tests, `roblox_api_check.py`, `ui_qa.py`.
6. Soft launch to friends first, watch the Output/analytics, then set the game public.

## What is NOT a manual step (already done in code)
Everything else: gameplay, saving, security checks, receipts, the shop layout, the trait tree, Ascension, Specimens, the Track, streaks, events, the world boss, the trophy hall and all the documentation.
