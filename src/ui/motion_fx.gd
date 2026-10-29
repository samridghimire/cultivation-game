class_name MotionFx
extends RefCounted
## Pure helpers for hit and breakthrough feedback (WU-397). Everything here is a no-op
## when the `reduce_motion` setting is on.

const HEAVY_HIT_FRACTION := 0.15


## True when the `reduce_motion` setting is on.
static func reduced() -> bool:
	return bool(Settings.get_value("reduce_motion"))


## A bounded shake offset `elapsed` seconds into a `duration` shake of `amplitude` px;
## it fades out linearly and is Vector2.ZERO when reduced, finished or not started.
static func shake_offset(elapsed: float, duration: float, amplitude: float, reduce_motion: bool) -> Vector2:
	if reduce_motion or duration <= 0.0 or elapsed < 0.0 or elapsed >= duration:
		return Vector2.ZERO
	var fade := 1.0 - elapsed / duration
	return Vector2(sin(elapsed * 90.0), cos(elapsed * 70.0)) * amplitude * fade


## True when a blow took more than 15% of the struck fighter's max hp.
static func is_heavy_hit(hp_lost: int, max_hp: int) -> bool:
	return max_hp > 0 and float(hp_lost) > HEAVY_HIT_FRACTION * float(max_hp)
