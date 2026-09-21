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

## Not built yet (stage 2: boss arena, chosen by the developer)
Expedition bosses (floors 4 and 8) pull the player into a small real-time arena inside the seam. Needs its own design pass (movement, dodging, throwing/planting explosives live, boss telegraphs, server-side hit validation). Nothing of it exists yet. The grid Lurkers do not depend on it.

## Numbers are placeholders
Spawn chances, HP, damage, hearts, repair fraction and bounties are unbalanced; see `docs/BALANCE_BACKLOG.md`.
