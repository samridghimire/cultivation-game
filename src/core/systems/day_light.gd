class_name DayLight
extends RefCounted
## GFX-217: the light of one quick day-night cycle played behind a time-skip overlay.
## phase 0..1 is one day: 0 morning (the normal look), 0.35 dusk, 0.5 night, 0.85 dawn, 1 morning again.

## [phase, multiply colour] keyframes, phase ascending.
const KEYS: Array = [
	[0.0, Color(1, 1, 1)],
	[0.35, Color(1.0, 0.82, 0.68)],
	[0.5, Color(0.45, 0.5, 0.75)],
	[0.85, Color(0.95, 0.85, 0.85)],
	[1.0, Color(1, 1, 1)],
]
const NIGHT_FROM := 0.4
const NIGHT_TO := 0.75


## The base (season) tint multiplied by the day colour at `phase`.
static func tint_at(phase: float, base: Color) -> Color:
	var p := clampf(phase, 0.0, 1.0)
	for i in range(1, KEYS.size()):
		var b: Array = KEYS[i]
		if p <= float(b[0]):
			var a: Array = KEYS[i - 1]
			var t := (p - float(a[0])) / (float(b[0]) - float(a[0]))
			t = t * t * (3.0 - 2.0 * t)
			return base * (a[1] as Color).lerp(b[1] as Color, t)
	return base


## Quick cycles shown for a skip of `days` days (a month shows at most 3).
static func cycles_for(days: int) -> int:
	return clampi(days, 1, 3)


static func is_night(phase: float) -> bool:
	return phase >= NIGHT_FROM and phase <= NIGHT_TO


## 0..1 glow strength of lamps at `phase` (fades in at dusk, out at dawn).
static func lamp_strength(phase: float) -> float:
	return clampf(minf((phase - 0.3) / 0.15, (0.85 - phase) / 0.15), 0.0, 1.0)
