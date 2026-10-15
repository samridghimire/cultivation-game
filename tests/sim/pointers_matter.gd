extends SceneTree
## QA-044: do pointers and spars speed the first year? Runs the curious policy with and
## without them and prints median combat-technique levels and fights won at months 6 and 12.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/pointers_matter.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 12
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	for no_help in [false, true]:
		var levels: Dictionary = {6: [], 12: []}
		var wins: Dictionary = {6: [], 12: []}
		var helped := 0
		var dead := 0
		for s in range(1, seeds + 1):
			var snap: Dictionary = {}
			var hook := func(month: int) -> void:
				if levels.has(month + 1):
					var c: CharacterData = gs.player
					var total := 0
					for tech_id: String in c.techniques:
						total += Techniques.level(c, tech_id)
					snap[month + 1] = [total, LifeStats.get_stat(c, "fights_won")]
			var out := FirstHour.play(gs, clock, s, months, true, hook, no_help)
			for m: int in snap:
				levels[m].append(snap[m][0])
				wins[m].append(snap[m][1])
			helped += out["kind_sets"].filter(func(k: Dictionary) -> bool: return k.has("pointer") or k.has("spar")).size()
			if not out["player"].alive:
				dead += 1
		print("%s (%d seeds, %d months): pointer/spar months %d, deaths %d" % ["NO pointers/spars" if no_help else "with pointers/spars", seeds, months, helped, dead])
		for m: int in levels:
			if m <= months:
				print("  month %d: median summed technique levels %.1f, median fights won %.1f" % [m, _median(levels[m]), _median(wins[m])])
	quit()
