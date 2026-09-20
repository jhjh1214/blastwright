# Audio Direction

Groups: Music, Ambient, Ui, Sfx, Reward (`AudioManager`). Cues are named in `Config/Sounds.luau`.

- **Pop:** short crystalline chime; pitch rises with chain length (implemented as `PlaybackSpeed`).
- **Detonate:** low thud plus a rising fizz.
- **Tier:** distinct sting per tier.
- **Reward:** bright pickup; **Error:** soft dull tick.
- **Music:** low ambient cave pad with a pulse that intensifies during chains (planned).

## Status
Hooks are in place. **No audio assets are set:** every `Id` is `nil`, so the game is currently silent. Sounds must be found via the Creator Store API, verified as usable in-experience, and recorded in `ASSET_REGISTRY.md`. No copyrighted music.
