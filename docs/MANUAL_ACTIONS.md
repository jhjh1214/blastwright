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
A dark crystal mine: hub plaza, roads, three biomes, blast pads. Using a pad station opens the top-down grid; tapping plants charges; Detonate triggers a cascade; shards count up. Geode caches are hidden off the roads.

THEN:
Return to Claude and say "Done: playtest" and paste any Output errors or notes on how it felt.
========================================
```

Later (not needed yet): publish the experience; create Developer Products and Gamepasses (see `MONETIZATION.md`); enable Studio access to API Services if you want to test persistence.
