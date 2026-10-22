extends SceneTree
## QA-123: does the curious player practise? Runs the curious first-hour policy with and without
## FirstHour.practise_hint (GUIDE-081's practice hint followed to the next level).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_practise.gd -- [seeds] [months]

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
	print("Curious practiser: %d seeds, %d months" % [seeds, months])
	for practise in [false, true]:
		FirstHour.practise_hint = practise
		var levels := {3: [], 6: [], 12: []}
		var wolf: Array = []
		var qr3: Array = []
		var won: Array = []
		var lost: Array = []
		var no_wolf := 0
		print("  --practise=%s" % practise)
		print("  seed  fist@m3  fist@m6  fist@m12  wolf win day  won  lost  QR3")
		for s in range(1, seeds + 1):
			var at := {}
			var hook := func(month: int) -> void:
				if levels.has(month + 1):
					var p: CharacterData = gs.player
					at[month + 1] = Techniques.level(p, "iron_fist") if p.techniques.has("iron_fist") else 0
			var r: Dictionary = FirstHour.play(gs, clock, s, months, true, hook)
			for m: int in levels:
				levels[m].append(int(at.get(m, 0)))
			var wd := FirstHour.wolf_win_day
			if wd >= 0:
				wolf.append(wd)
			else:
				no_wolf += 1
			if r["layer_day"].has(3):
				qr3.append(r["layer_day"][3])
			won.append(r["fights_won"])
			lost.append(r["fights_lost"])
			print("  %4d  %7d  %7d  %8d  %12s  %3d  %4d  %s" % [s, at.get(3, 0), at.get(6, 0), at.get(12, 0), str(wd) if wd >= 0 else "-", r["fights_won"], r["fights_lost"], str(r["layer_day"].get(3, "-"))])
			gs.end_session()
		print("  Medians: iron_fist level m3 %.0f, m6 %.0f, m12 %.0f; first wolf win day %.0f (%d seeds never); fights won %.0f, lost %.0f; QR3 day %.0f (%d/%d reached)" % [_median(levels[3]), _median(levels[6]), _median(levels[12]), _median(wolf), no_wolf, _median(won), _median(lost), _median(qr3), qr3.size(), seeds])
	FirstHour.practise_hint = false
	quit()
