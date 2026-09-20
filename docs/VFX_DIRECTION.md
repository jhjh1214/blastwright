# VFX Direction

Reusable client modules: `VFX` (pooled particle bursts, ring shockwaves, beams), `FloatingNumbers` (pooled), `CameraFeedback` (shake + FOV punch), `CavernView.Pop` (shrink-out).

- Burst particle counts are small (9-14) and the emitter pool is capped at 24 for mobile.
- Volatile crystals emit a ring; Prism crystals fire a beam along their row; tier events add a big ring, shake and FOV punch.
- Particle texture is Roblox's built-in `rbxasset://textures/particles/sparkles_main.dds`; no external asset IDs are used.
- All effect calls are wrapped in `pcall`: a VFX failure never breaks gameplay.

## Not done
Trails, rare-reveal presentation, ambient dust, area transitions. Nothing measured on a real device.
