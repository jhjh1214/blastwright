# Audio Direction

Groups: Music, Ambient, Ui, Sfx, Reward (`AudioManager`). Cues are named in `Config/Sounds.luau`.

- **Pop:** short crystalline chime; pitch rises with chain length (implemented as `PlaybackSpeed`).
- **Detonate:** low thud plus a rising fizz.
- **Tier:** distinct sting per tier.
- **Reward:** bright pickup; **Error:** soft dull tick.
- **Music:** low ambient cave pad with a pulse that intensifies during chains (planned).

## Status
Seven placeholder-grade SFX cues are wired from Creator Store results (see `ASSET_REGISTRY.md`). They were chosen from metadata only: **not yet listened to, in-experience playback not yet confirmed** (`AudioManager.Verify` logs OK/FAILED to Output). A looping cave ambience bed plays from join and ducks to 45% in blast mode. A shuffled, crossfaded **classical playlist** (11 cheerful pieces from the APMOfficial partner library, see `ASSET_REGISTRY.md`) plays under everything at low volume and ducks slightly in blast mode. Players can switch **Music** (music + ambience), **Effects** and **Screen shake** off independently in the "?" panel; the choices are saved. Tracks were picked from titles and metadata only.
