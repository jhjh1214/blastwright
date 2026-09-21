# Launch checklist

Every manual step in one place: `docs/PUBLISH_GUIDE.md`. This is the verification list.

Ordered. Items marked **(you)** need your Roblox account; the rest are things to verify. Nothing here has been done yet unless ticked.

## 0. Before publishing
- [ ] Complete the manual playtest in `docs/TESTING.md` (sections A to F) and fix what breaks.
- [ ] Do the balance pass (`docs/BALANCE_BACKLOG.md`): the developer reports the game feels too fast and the daily/weekly objectives are too easy and too generous.
- [ ] Re-read `docs/SECURITY.md` against the current code.
- [ ] `rojo build` produces a place file; open it and press Play once more with a clean Output.
- [ ] Decide the experience name, a one-sentence hook, and a description (see the hook in `docs/GAME_CONCEPT.md`).

## 1. Publish **(you)**
- [ ] Studio > File > Publish to Roblox (create a new experience). Keep it **private** while testing.
- [ ] Game Settings > Security: enable "Enable Studio Access to API Services" (lets Studio test saves and the leaderboard).
- [ ] Game Settings > Basic Info: **max players 16** (there are 16 blast pads).
- [ ] Game Settings > Avatar: leave default (R15). The game does not depend on avatar type.
- [ ] Complete the experience questionnaire / content maturity (the game has no violence, chat features or user content beyond names on the leaderboard).

## 2. Verify persistence in the published place
- [ ] Play, earn shards, buy an upgrade, leave, rejoin: progress is there.
- [ ] Open two servers: a pad and the leaderboard behave; the session lock prevents dupes.
- [ ] Stop the server from the dashboard; the shutdown save keeps progress.
- [ ] Output shows no `[Data]` warnings about failed loads or saves.

## 3. Monetization **(you)** (see `docs/MANUAL_ACTIONS.md`)
- [ ] Create the 18 Developer Products (4 shard packs, 4 blast colors, 10 offers) and 2 Gamepasses (optionally the Club subscription); paste ids into `Config/Products.luau` (table in `docs/PUBLISH_GUIDE.md`).
- [ ] Test each purchase once in a private server: grants once, persists, and the Shop tab updates.
- [ ] Confirm 2x Shards and Prismatic Luck behave as described; boosts, revive and finishers grant once and persist.
- [ ] Check prices (suggestions in `docs/MONETIZATION.md`).

## 4. Devices
- [ ] Phone (or the Device emulator at 390x844 and 844x390): top bar, dock buttons (Shop, Forge, Daily, Goals, Codex, Farm), grid framing and taps.
- [ ] Low-end phone frame rate in a full server; if poor, see the levers in `docs/TECHNICAL_ARCHITECTURE.md` (fewer decor lights, StreamingEnabled).
- [ ] Gamepad/keyboard: Space to detonate, X to leave, Backspace to clear.

## 5. Presentation **(you)**
- [ ] Thumbnail and icon (a blast cascade over the Glimmer Shallows works well); 3 to 5 screenshots.
- [ ] Description and tags; check nothing implies things that are not in the game.
- [ ] Add audio and models attribution if desired (creators are listed in `docs/ASSET_REGISTRY.md`).

## 6. Soft launch
- [ ] Set the experience to public for friends only first; watch the Output/analytics for errors.
- [ ] Use live events (`Config/Events.luau`) and weekly challenges as the reason to return.
- [ ] Collect feedback and re-balance (economy simulators in `tools/sim`).

## Known limits to keep in mind
- Everything in `docs/TESTING.md` "NOT covered by any automated test" was written without being run in a live server.
- The environment look uses Terrain, Parts and free Creator Store models; there is no custom art.
- No music beyond the licensed classical playlist; provenance is the partner library's listing, not an audited license.
