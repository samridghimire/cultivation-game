extends SceneTree
## PERF-014: times an autosave's parts for a 1-year and a 10-year curious session (fixed seed):
## `GameState.to_save_dict`, JSON stringify, the atomic file write and a full `load_save_dict`
## (the region rebuild is not part of it). 20 runs each; prints median and worst ms and the save size.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/profile_saves.gd -- [seed] [runs]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const SESSIONS := [["1 year", 12], ["10 years", 120]]
const TMP_SLOT := "perf014_profile"


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(v: Array) -> float:
	var s := v.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _row(label: String, v: Array) -> void:
	print("  %-22s median %7.2f ms  worst %7.2f ms" % [label, _median(v) / 1000.0, float(v.max()) / 1000.0])


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var saves: Node = root.get_node("SaveManager")
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var runs := int(args[1]) if args.size() > 1 else 20
	var path: String = saves.save_path(TMP_SLOT)
	for s: Array in SESSIONS:
		FirstHour.play(gs, clock, seed_value, int(s[1]), true)
		if not gs.player.alive:
			print("%s: the player died, pick another seed" % s[0])
			gs.end_session()
			continue
		var t_dict: Array = []
		var t_json: Array = []
		var t_write: Array = []
		var t_load: Array = []
		var size := 0
		var first: Dictionary = {}
		for i in runs:
			var t0 := Time.get_ticks_usec()
			var game: Dictionary = gs.to_save_dict()
			var t1 := Time.get_ticks_usec()
			var text := JSON.stringify({"version": saves.SAVE_VERSION, "game": game}, "\t")
			var t2 := Time.get_ticks_usec()
			saves._write_atomic(path, text)
			var t3 := Time.get_ticks_usec()
			var parsed: Variant = JSON.parse_string(text)
			var t4 := Time.get_ticks_usec()
			gs.load_save_dict((parsed as Dictionary).get("game", {}))
			var t5 := Time.get_ticks_usec()
			t_dict.append(t1 - t0)
			t_json.append(t2 - t1)
			t_write.append(t3 - t2)
			t_load.append(t5 - t4)
			size = text.length()
			if i == 0:
				first = game
		print("%s (seed %d, %d days, %.0f KB):" % [s[0], seed_value, clock.total_days, size / 1024.0])
		_row("to_save_dict", t_dict)
		_row("JSON.stringify", t_json)
		_row("file write", t_write)
		_row("load_save_dict", t_load)
		var sizes := {}
		for k: String in first:
			sizes[k] = JSON.stringify(first[k]).length()
		var keys := sizes.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return sizes[a] > sizes[b])
		var top: Array[String] = []
		for k: String in keys.slice(0, 5):
			top.append("%s %.0f KB" % [k, sizes[k] / 1024.0])
		print("  biggest keys: ", ", ".join(top))
		gs.end_session()
	for ext in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(path + ext)
	quit()
