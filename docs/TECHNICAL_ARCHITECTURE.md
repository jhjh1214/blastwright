# Technical Architecture

Rojo source of truth: `default.project.json` maps `src/*` to Roblox services.

```
ReplicatedStorage/Shared     ChainSim (pure), Geometry, Remotes, Config/*  (data-driven)
ServerScriptService/Server   init.server (boot), Game (authority), Data (DataStore), World,
                             Seam (pure generation), Schema (pure), Validate (pure)
StarterPlayerScripts/Client  init.client (wiring), State, CavernView, Preview, Playback, UI, Input,
                             VFX, FloatingNumbers, CameraFeedback, AudioManager
```

## Data flow
1. Server generates a seam (grid) and sends `SeamStart` (compact cell list) to all clients. **Crystal visuals are built client-side**; the server holds no crystal Parts.
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
- Cooldowns: 0.15s Detonate, 0.2s Buy. Only one volley in flight per player.
- Nothing purchases yet (Phase 10).

## Known limits
- Roblox-facing code (`Game`, `Data`, `World`, all Client modules) is **compile-checked only**, not run in Studio.
- Volley playback is not broadcast-throttled for many players.
- Slots are unbounded; server player cap should be set in experience settings.
