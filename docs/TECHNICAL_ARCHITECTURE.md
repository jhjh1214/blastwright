# Technical Architecture

Rojo source of truth: `default.project.json` maps `src/*` to Roblox services.

```
ReplicatedStorage/Shared     ChainSim (pure), Geometry, Remotes, Config/*  (data-driven; Config/World = layout)
ServerScriptService/Server   init.server (boot), Game (authority), Data (DataStore), World (builds terrain, hub,
                             sites, caches from Config/World), Seam (pure generation), Schema (pure), Validate (pure)
StarterPlayerScripts/Client  init.client (wiring), State, Blasting (enter/leave blast mode), CavernView, Preview,
                             Playback, UI, Input, CacheView, Ambience, VFX, FloatingNumbers, CameraFeedback, AudioManager
```

## Data flow
0. `init.server` sets `CharacterAutoLoads = false`, builds the world (pcall-guarded), then loads each character after data loads, so nobody spawns before the world exists.
1. A player uses a site's station (server-side `ProximityPrompt.Triggered`; proximity re-checked on the server). The server checks the stratum is unlocked and the pad is free, reserves it, generates a seam (grid) and sends `SeamStart` (compact cell list) to all clients, then `Engage` to that player. **Crystal visuals are built client-side**; the server holds no crystal Parts.
2. Client sends `Detonate` with `{X, Z, Kind}` entries only.
3. Server validates (`Validate.Volley`), runs `ChainSim.Run`, updates the grid, pays out, and broadcasts `VolleyResult` (event timeline).
4. Clients replay the timeline (`Playback`). Owner also receives `Sync` (full state snapshot).
5. `Buy` carries `(kind, id)` strings only; the server checks cost and ownership.

## Determinism
`ChainSim` is pure and deterministic. The server uses it for rewards; the client uses the same code for the planning preview. Config modules are Roblox-free so the Luau CLI tests load the real configs.

## Persistence
`Data.luau`: DataStore `PlayerData_v1`, `UpdateAsync` with a job-id session lock (stale after 300s), 6 load / 4 save attempts with backoff, autosave every 60s, `BindToClose` save, schema versioning and reconcile in `Schema.luau`. Studio without API access falls back to a volatile profile and warns.

## Security
- All remotes are validated server-side; extra fields are stripped, numbers must be finite integers in range, and charge kinds must be unlocked by the *server's* record.
- Cooldowns: 0.15s Detonate, 0.2s Buy. Only one volley in flight per player. Detonate requires the character within 45 studs of the site station; site and cache prompts re-check proximity (30 / 25 studs). Caches pay once per player, tracked in the save (`Caches`, schema v2).
- Nothing purchases yet (Phase 10).

## Performance notes (reasoned from the code; nothing profiled on a device)
- **Grid level of detail:** every client keeps every player's grid *data*, but builds crystal models (about 400 parts per grid) only for your own grid and for grids within 190 studs of the camera (dropped beyond 240). At most one grid is built per second so walking into a biome does not hitch. Volley effects are skipped for unbuilt grids.
- **Overlay:** the planning overlay reuses a pool of adornments (up to roughly 300 while planning) and only redraws when the hovered cell or plan changes.
- **Effects:** particle emitters are pooled and capped at 24; bursts are 9-14 particles.
- **World:** built once at server start (terrain fills, then decor). Real-model props are loaded once and cloned. If a low-end phone struggles, the first levers are fewer decor clusters and lights in `World.luau`, and enabling `Workspace.StreamingEnabled` (not enabled yet because it changes behaviour that has not been tested).
- **Server:** one 5s idle loop, one 60s autosave loop; simulation runs only on Detonate.

## Known limits
- Roblox-facing code (`Game`, `Data`, `World`, all Client modules) is **compile-checked only**, not run in Studio.
- Volley playback is not broadcast-throttled for many players.
- 16 blast pads total: set the experience max players to 16 or fewer (dashboard setting) or extra players will find every pad taken.
- The world is generated at server start (a few seconds of terrain fills); nothing has measured this on a real server.
