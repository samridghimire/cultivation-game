# Assets

No binary assets are shipped yet. Placeholder art is drawn in code (`_draw()`). Sprites are mapped in `data/sprites.json`
(GFX-001); packs live in `assets/third_party/<pack>/` with their license file, and CC-BY authors appear on the credits screen.

| file | pack | author | license | url |
|---|---|---|---|---|

- **Sound effects:** procedural, synthesized in code at startup by `src/autoload/audio.gd` (sine/noise envelopes). No audio files.
- **Ambient music:** procedural too (`Audio.synth_music`): a seeded pentatonic pluck loop plus drone per mood (calm / normal / dark), on the Music bus.
- **Engine:** Godot Engine (MIT), see `Engine.get_license_text()`.
