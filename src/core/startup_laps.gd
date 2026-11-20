class_name StartupLaps
extends RefCounted
## PERF-023: startup timing laps. Silent unless the game runs with the `--profile-startup` user arg
## (`godot ... -- --profile-startup`); then each `lap()` prints the ms since engine start and since the last lap.

static var _last_msec: int = 0


static func enabled() -> bool:
	return OS.get_cmdline_user_args().has("--profile-startup")


static func lap(step: String) -> void:
	if not enabled():
		return
	var now: int = Time.get_ticks_msec()
	print("[startup] %-28s +%4d ms  (t=%d ms)" % [step, now - _last_msec, now])
	_last_msec = now
