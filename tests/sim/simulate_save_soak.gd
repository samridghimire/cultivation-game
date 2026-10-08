extends SceneTree
## Save round-trip soak (QA-031): plays a real GameState session headless and
## every `every` years does to_save_dict -> JSON -> load_save_dict -> to_save_dict,
## then compares the two (both JSON-normalised) and reports the first differing
## key path. Play continues from the loaded state. Exit code 1 on any difference.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_save_soak.gd -- [years] [seed] [every]

var _diffs: Array[String] = []


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 50
	var seed_value := int(args[1]) if args.size() > 1 else 1
	var every := int(args[2]) if args.size() > 2 else 5
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	gs.rng.seed = seed_value
	var player := CharacterFactory.create("Soak Patriarch", gs.data, gs.rng)
	gs.start_session(player)
	gs.pending_event = ""
	player.realm_index = gs.data.realms.size() - 2
	print("Save soak: %d years, seed %d, round trip every %d years" % [years, seed_value, every])
	gs.load_save_dict(_normalise(gs.to_save_dict()))  # settle: loading silently awards milestones the jump above implies
	var failures := 0
	for year in range(1, years + 1):
		for month in 12:
			clock.advance(Calendar.DAYS_PER_MONTH)
		if year % every == 0:
			var before := _normalise(gs.to_save_dict())
			gs.load_save_dict(_normalise(gs.to_save_dict()))
			var after := _normalise(gs.to_save_dict())
			_diffs.clear()
			_compare(before, after, "")
			if _diffs.is_empty():
				print("  year %3d: ok (%d kB)" % [year, JSON.stringify(before).length() / 1024])
			else:
				failures += 1
				print("  year %3d: DIFFERS, first: %s" % [year, _diffs[0]])
	print("Done: %d differing round trips." % failures)
	gs.end_session()
	quit(1 if failures > 0 else 0)


func _normalise(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d))


func _compare(a: Variant, b: Variant, path: String) -> void:
	if not _diffs.is_empty():
		return
	if a is Dictionary and b is Dictionary:
		for k in a:
			if not b.has(k):
				_diffs.append("%s/%s missing after load" % [path, k])
				return
			_compare(a[k], b[k], "%s/%s" % [path, k])
		for k in b:
			if not a.has(k):
				_diffs.append("%s/%s appeared after load" % [path, k])
				return
	elif a is Array and b is Array:
		if a.size() != b.size():
			_diffs.append("%s size %d -> %d" % [path, a.size(), b.size()])
			return
		for i in a.size():
			_compare(a[i], b[i], "%s[%d]" % [path, i])
	elif typeof(a) != typeof(b) or a != b:
		_diffs.append("%s: %s -> %s" % [path, str(a).left(60), str(b).left(60)])
