# Shop art guide: replacing the drawn graphics with real painted art

(The complete asset list with a ready-to-paste prompt for every image is in `docs/MANUAL_TODO.md`, section 5.)

The game draws its shop art and icons in code so it always works. You can replace any of them with painted images (from an artist, an AI image tool, or an asset pack) without touching game logic. There are two hooks, each a small table you fill with **real image asset ids**. Anything you leave empty keeps the drawn version, so you can replace things gradually. Never invent an id: only paste ids of images you uploaded yourself.

## A. The four things you can replace
| What | Where it is used | Table to fill | Recommended image |
|---|---|---|---|
| Shop card pictures (one per product) | The art window at the top of every card in the Shop | `ShopArt.Images` in `src/StarterPlayer/StarterPlayerScripts/Client/ShopArt.luau` | 1024 x 512 PNG (2:1), subject centred, keep the important part in the middle 70% (edges are cropped to fit) |
| UI icons | Dock buttons, menu tabs, tiles, status tiles | `Icons.Assets` in `src/StarterPlayer/StarterPlayerScripts/Client/Icons.luau` | 256 x 256 transparent PNG, chunky with a thick dark outline (colour `#1A1228`), no text |
| Purchase-prompt icons (what Roblox shows when buying) | The Roblox purchase pop-up | Set in the Creator Dashboard on each product/pass (not in code) | 512 x 512 PNG |
| Game icon and thumbnails | The experience page | Creator Dashboard > Your experience > Configure > Icon and Thumbnails | Icon 512 x 512, thumbnails 1920 x 1080 |

## B. Get consistent art (this is what makes it look "damn good")
The single most important rule is **one consistent style**: same outline weight, same lighting direction, same colour palette. The UI is chunky and cartoony with thick dark outlines and saturated colours, so paint everything in that style.

Options, best first:
1. **Commission an artist** (Fiverr, ArtStation, the Roblox DevForum "Collaboration" boards). Give them this guide, the item list in section D, and a screenshot of the game. Ask for a single sheet first to approve the style.
2. **AI image tool** (any you have access to). Use ONE style prompt for every image, only changing the subject. Style prompt to reuse:
   > chunky cartoon game item icon, thick dark purple outline, bold saturated colours, soft top-left lighting, glossy highlights, simple background gradient, centred subject, no text, mobile game shop art
   Subjects: "a sack of glowing blue crystal shards", "a treasure chest overflowing with crystals", "a clock with a lightning bolt", and so on (see the list in D). Generate several, pick the best, keep the same tool and settings for all so they match. Check the licence of the tool for commercial use.
3. **Marketplace/Creator Store packs**: fine for a start, but mixing styles looks messy. Only use one pack for everything.
4. **Draw it yourself** (Figma, Canva, Krita, Photopea).

Tip: view the image at 25% size. If you can still tell what it is, it works on a phone.

## C. Upload and get the image id
1. Go to https://create.roblox.com/dashboard/creations, Assets (or Development Items) > **Images**, click **Upload**, choose your PNG. (Roblox reviews images; it can take a minute.)
2. Alternative: in Studio open **View > Asset Manager**, right-click **Images > Bulk Import**, pick all your files at once. This is the fastest for many images.
3. Copy the **asset id** (a long number). In Asset Manager right-click the image > **Copy ID to Clipboard**.
4. Turn it into the text `rbxassetid://` + the number, for example `rbxassetid://1234567890`.
5. Quick check before using it everywhere: in Studio create an ImageLabel in a ScreenGui, paste the text into its `Image`, and make sure the picture appears. If it does not, you copied a Decal id instead of an Image id: in Asset Manager use the Image entry, or upload again as an Image.
6. Images used inside your own experience must be uploaded by the same account or group that owns the experience.

## D. Fill in the tables

### Shop card pictures (`ShopArt.Images`)
The key is the product name exactly as shown on the card (from `Config/Products.luau`). Example:
```lua
ShopArt.Images = {
	["Shard Pouch"] = "rbxassetid://1111111111",
	["Shard Satchel"] = "rbxassetid://2222222222",
	["Starter Blast"] = "rbxassetid://3333333333",
}
```
All keys to make (23): Shard Pouch, Shard Satchel, Shard Chest, Shard Vault, Neon Pink Blasts, Void Blasts, Toxic Blasts, Golden Blasts, 2x Shards, Prismatic Luck, Blastwright Plus, Track Premium, Emergency Charges, 2x Shards (15 min), 2x Prismatic Luck (15 min), Expedition Revive, Starter Blast, Expedition Kit, Celestial Finish, Inferno Finish, Boss Hunter Pack, Ultimate Blastwright, Blastwright Club.

Suggested subjects: shard packs = a pile, bag, chest and vault of blue crystals growing in size; blast colors = a glowing explosion in that colour; 2x Shards = gem with "x2" energy (no text needed); revive = a heart with a lightning bolt; finishers = the actual explosion colours (blue-white, red inferno, purple void); bundles = several of the items fanned together; Plus and Club = a golden crown.

The price chip and the BUY button stay drawn on top, so leave the bottom of the picture uncluttered.

### UI icons (`Icons.Assets`)
```lua
Icons.Assets = {
	Shop = "rbxassetid://4444444444",
	Forge = "rbxassetid://5555555555",
}
```
Names you can replace: Forge, Shop, Daily, Goals, Codex, Farm, Gem, Bomb, Bolt, Close, Heart, Lock, Skull, Star, Clock, Loadout. Transparent background, subject fills about 80% of the square.

## E. Check it
1. `rojo build` or `rojo serve`, press Play, open the Shop: your images should appear in the card windows; anything missing still shows the drawn art.
2. Look at it on a phone-sized viewport (Studio Device Emulator) to check that nothing important is cropped.
3. Run `python tools/lint/roblox_api_check.py` and `tools/bin/luau.exe tools/tests/core.spec.luau` (they should both still pass) before you publish.
4. If you send me the ids I can paste them into both tables for you.
