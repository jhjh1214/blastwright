# Manual Assets

**Status: DONE (2026-09-21).** The developer added the 8 models to their inventory and all load ("8/8 props available"). The block below is kept as the record and as the fix if it ever recurs (for example on a different account or a published game).

```
========================================
MANUAL ASSET ACTION REQUIRED
========================================
ASSET:
The 8 decor models listed below (crystal clusters, lamp, mushrooms, stalagmites, crate).

WHY IT IS REQUIRED:
The game loads them at runtime with InsertService:LoadAsset. Studio replied to every one with
"User is not authorized to access Asset": free Creator Store models must be in the owning account's inventory
before a place can load them. Until then the world uses procedural fallbacks (nothing is broken, it just looks plainer).

WHY AUTOMATION CANNOT COMPLETE IT:
Adding a free model to an inventory needs your logged-in Roblox account. Claude has no access to it.
(I have not been able to test that this fixes it: it is the documented requirement and matches the error text.)

EXACT STEPS (for each of the 8 links, ~1 minute total):
1. Open https://create.roblox.com/store/asset/<ID> while logged in to the account that owns/tests this place.
2. Click "Get" (free models show a Get button; no Robux is charged).
3. Repeat for all eight IDs.
4. Press Play again.

  15618160671  Crystal Cluster (kingOfcats9912828)
  12882247457  crystals6 (senya0079)
  17451005959  lamp (metrox1223)
  2986139359   Glowing Mushroom (CaptainOwlin)
  1532334716   Glowing Mushroom (Chooonky)
  9687949418   Stalagmite 1 (Jey_Jacule)
  10186366587  stalagmite 2 (Firesquirrel777)
  182451181    Wooden Crate (Quenty)

WHERE IT GOES:
Nowhere by hand. The server loads them by id (see Config/Props.luau).

EXPECTED RESULT:
Output shows "[Props] <name> loaded ..." for each and "[Props] 8/8 props available".
If some still fail, paste the warning lines to Claude; those props keep their procedural fallback.

NOTE FOR A PUBLISHED GAME:
If loads work in Studio but fail in a live server, tell Claude. The fallback is to import the models into your own
account (Studio > Toolbox > Inventory > "Add to Experience"/re-upload), which changes the ids.
========================================
```

## Music (optional)
The background playlist is already wired (11 classical tracks, see `ASSET_REGISTRY.md`). To add your own licensed track:
add an entry to `src/ReplicatedStorage/Shared/Config/Music.luau` with its `rbxassetid://` id, name, artist and length in seconds.
