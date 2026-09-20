# Testing

## Automated (runs outside Studio)
```
tools/bin/luau.exe tools/tests/core.spec.luau
```
`tools/bin` is git-ignored; it holds the Luau CLI, analyzer and compiler (v0.739, from the luau-lang GitHub release).

**Covered (17 tests):** chain propagation, ordering, bounds, amplifier, unstable, prism/column shapes, tiers, momentum, radius bonus, determinism and grid immutability, seed/stratum generation, save-schema migration/sanitizing, and hostile Detonate payloads.

**Mutation-tested:** removing the unstable multiplier, amplifier bonus, volatile propagation, tier bonus, bounds check, and the validator's unlock/duplicate/charges-left checks each fails the suite. One mutant (the redundant `dead[key]` re-check in the pop loop) survives because it is logically redundant, not because of a test gap.

Also run: `luau-compile --text <file>` on every `.luau` (syntax) and `rojo build`.

## NOT covered by any automated test
`Game.luau` (rewards, seam end, purchases), `Data.luau` (DataStore, locking, retries, shutdown), `World.luau`, and every client module (rendering, UI, input, camera, playback). These are compile-checked only.

## Manual Studio checklist (developer)
1. `rojo serve`, connect the plugin in Studio, press Play.
2. Expect a cavern, HUD, and "Tap the cavern to plant a charge". Plant, Detonate, watch the cascade; shards should count up.
3. Clear a seam or run out of charges: expect a toast and a new seam after ~3s.
4. Open Forge: buy an upgrade; check shards drop and Lv rises. Open Codex.
5. Test with 2 players (Test tab, 2 players): each has their own cavern and can see the other's.
6. Stop and play again: in Studio the profile is volatile, so progress will not persist (expected; see output warning). Real persistence requires "Enable Studio Access to API Services" and a published place.
7. Emulate a phone (Device emulator): check the layout, tap targets, and that the whole grid is visible in portrait.
8. Report anything odd from the Output window.
