# Art Direction

**Style:** "Deep Glow": dark, cool basalt caves where saturated neon crystals carry all the color.

- **Shape language:** angular, faceted shards. Each crystal type has its own silhouette (fan of spikes, star burst, spire with ring, standing lens disc, jagged dark spikes).
- **Color:** rock is desaturated blue-grey; crystals are the only saturated things. Each type owns a hue (cyan, orange, violet, gold, red) so type is readable at a glance and for colour-blind players by shape too.
- **Lighting:** dark ambient, bloom on Neon, light atmosphere haze. No dynamic lights per crystal (performance).
- **UI:** dark navy panels, cyan accent, gold for shards, orange for the detonate action. Rounded corners, GothamBold/GothamBlack.
- **Camera:** fixed high-angle over the cavern, auto-fit for any aspect ratio.

## World look (Terrain + Parts + vetted Creator Store models)
Roblox Terrain (slate ground, basalt cliffs, rock mounds and stacked-cylinder spires), cobblestone roads with warm lanterns, neon crystal clusters tinted per biome (cyan / gold / magenta), a pale-blue hub, strong dark atmosphere with bloom. Drifting motes follow the player. Real models (see `ASSET_REGISTRY.md`) add tinted crystal clusters, lamp posts, glowing mushrooms, stalagmites and crates; each has a procedural fallback.

## Blast grid look
The game rules are a 9x9 grid, but it must not *look* like one. Each crystal sits on a lumpy half-buried rock (not a square slab), and gets a small random offset, turn and size, so rows and columns never line up. The pad is a round cavern floor with a soft glowing edge, ringed by terrain boulders and crystal clusters. Clicking still snaps to the invisible cells.

## Current state
Crystals and floor are **procedural from Parts**. That is a deliberate slice placeholder and does not meet the final quality bar. Replacing or enhancing with verified assets is planned (see `DEVELOPMENT_PLAN.md`).
