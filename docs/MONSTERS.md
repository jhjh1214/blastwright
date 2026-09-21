# Lurkers: risk and combat

Why: the game was "blast, collect, repeat" with no way to lose. Lurkers add danger everywhere, and a fight that is won with the same tool you already love (chains and charge types).

## The loop
1. **Hidden.** When a seam is created there is a chance (`Config/Lurkers.Spawn`: 10% base, +5% per area, +4% per Expedition floor, capped at 60%) that a Lurker hides under one random valuable crystal. The location is a server secret. Seismograph owners see "Something stirs beneath the rocks..." (a hint, not a place).
2. **Wake.** When a volley pops that crystal the Lurker bursts out on that cell. It does not act on the turn it appears.
3. **Fight (turn-based).** Every volley you fire is your turn. Each charge whose blast covers the Lurker's cell hits it (Basic 2, Shaft 3, Cross 3); crystals popping right next to it add splash (1 each, up to 3). Armor cuts each direct hit (never below 1); a weakness doubles it. Then it acts.
4. **Kinds** (all data in `Config/Lurkers.luau`):
   - **Gnasher** (area 1+, 6 HP): eats up to 2 adjacent valuable crystals per turn, or walks toward the nearest one. The threat is to your payout.
   - **Sapper** (area 2+, 8 HP, weak to Shaft): drains one charge every turn. The threat is to your tempo.
   - **Brute** (area 3+, 14 HP, armor 1, weak to Cross): smashes the rig every other turn, with a warning the turn before. The threat is to your life.
5. **Stakes.** The rig has 3 hearts. At 0 the rig is knocked out:
   - normal seam: no clear bonus, and repairs cost 15% of what the seam earned (never more than you own);
   - Expedition floor: the run collapses (40% salvage).
   Killing a Lurker pays its bounty (added to the haul on an Expedition) and counts toward the "Slay" goals. An Expedition heals one heart between floors.
6. **Pressure without a timer.** A Lurker keeps acting every volley, so ignoring it costs crystals, charges or hearts, and fighting it costs charges you would have spent earning. That is the decision.

## Built now (grid fights, stage 1)
Pure rules in `Shared/Lurker.luau` (unit-tested and mutation-checked), server in `Game.luau` (`resolveMonster`), client: monster body with name and health bar (`CavernView.SetMonster`), rig hearts and monster line in the blast HUD, `MonsterTurn` remote for eaten crystals and camera shake. Only the owner of the seam sees their monster.

## Chain power and CRITICAL MASS (built)
Better chains hit monsters and bosses harder (`Shared/Power.luau`, `Config/Bosses.Power`): 6+ pops x1.25 (Strong), 10+ x1.5 (Overcharge), 15+ x2 (Critical). A 15+ pop chain also starts **CRITICAL MASS** for the next 2 volleys: x1.5 damage and x1.25 shards, with a banner, camera punch and a HUD counter. It is earned by play, never sold.

## Boss: the Crystal Titan (built as a grid fight, floors 4 and 8 of an Expedition)
Pure phase machine in `Shared/Boss.luau`; numbers in `Config/Bosses.luau`. The 3x3 middle of the grid is the Titan's body. Phases, each with its own puzzle:
1. **ARMOR**: it takes no damage. Pop the 4 glowing gold armor nodes (crystals on the grid). Breaking the last one hurts it and refunds a charge.
2. **ATTACK**: hit the core (charges whose blast reaches it, crystals popping near it, long chains). Every 2nd turn it MARKS a row or column in red; the turn after, the slam lands (destroys the crystals on it and costs a rig heart). Defences: pop 3+ crystals on the marked line to CUT the attack (no cost), or press Dodge (Q / button, 2-volley cooldown), which saves the heart but not the crystals.
3. **WEAK POINTS** (HP 65%): two magenta weak points appear on far-apart crystals. One hit is good, chaining through BOTH is massive (x3).
4. **ENRAGE** (HP 35%): two lines marked every turn.
5. **FINISHER** (HP 15%): one chain of 12+ pops, or any Critical-power volley, ends it. A failed try heals it a little.
Each phase change refunds a charge. Defeat = the Expedition collapses; victory pays a 6,000 shard bounty into the haul, the "Titan Slayer" goals, and a FINAL BLAST (bursts, rings, camera punch).
Balance evidence (`tools/sim/boss.luau`, greedy one-charge bot, no planning): at 30 HP it wins about 33% with Basic charges only and about 68% with all charges; humans who plan multi-charge volleys should do better. At 60 HP it won 2-4%, so HP was cut.

## Not built yet (stage 2: real-time boss arena)
Expedition bosses (floors 4 and 8) pull the player into a small real-time arena inside the seam. Needs its own design pass (movement, dodging, throwing/planting explosives live, boss telegraphs, server-side hit validation). Nothing of it exists yet. The grid Lurkers do not depend on it.

## Numbers are placeholders
Spawn chances, HP, damage, hearts, repair fraction and bounties are unbalanced; see `docs/BALANCE_BACKLOG.md`.
