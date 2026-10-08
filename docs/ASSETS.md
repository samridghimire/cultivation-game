# Assets

No binary assets are shipped yet. Placeholder art is drawn in code (`_draw()`).

- **Sound effects:** procedural, synthesized in code at startup by `src/autoload/audio.gd` (sine/noise envelopes). No audio files.
- **Ambient music:** procedural too (`Audio.synth_music`): a seeded pentatonic pluck loop plus drone per mood (calm / normal / dark), on the Music bus.
- **Engine:** Godot Engine (MIT), see `Engine.get_license_text()`.
