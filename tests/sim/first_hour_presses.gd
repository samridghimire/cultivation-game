extends SceneTree
## SIM-017: the first hour measured in menu presses. The hints player (tests/sim/first_hour.gd) counts the presses of every
## action it takes (PRESS_COST: open + choose + confirm, plus travel); this prints, per milestone, the median and worst of N
## seeds for presses and in-game days. A milestone held at day 0 counts as 0. "never" = not reached in the run.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/first_hour_presses.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 and not args[0].begins_with("--") else 10
	var months := int(args[1]) if args.size() > 1 and not args[1].begins_with("--") else 12
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	FirstHour.hints_policy = true
	var presses := {}
	var days := {}
	for m in FirstHour.MILESTONES:
		presses[m] = []
		days[m] = []
	for s in range(1, seeds + 1):
		FirstHour.hints_log = {"acted": {}, "idle_weeks": 0, "weeks": 0, "unmatched": {}}
		var start_day: int = clock.total_days
		FirstHour.play(gs, clock, s, months)
		var first: Dictionary = FirstHour.press_log["first"]
		for m in FirstHour.MILESTONES:
			if first.has(m):
				presses[m].append(int(first[m]["presses"]))
				days[m].append(int(first[m]["day"]) - start_day if start_day <= int(first[m]["day"]) else int(first[m]["day"]))
		gs.end_session()
	print("first hour in presses (hints player, seeds 1-%d, %d months)" % [seeds, months])
	print("  %-20s %7s %14s %14s %14s %14s" % ["milestone", "reached", "presses med", "presses worst", "days med", "days worst"])
	for m in FirstHour.MILESTONES:
		var p: Array = presses[m]
		var d: Array = days[m]
		p.sort()
		d.sort()
		var reached := "%d/%d" % [p.size(), seeds]
		if p.is_empty():
			print("  %-20s %7s %14s %14s %14s %14s" % [m, reached, "never", "-", "never", "-"])
		else:
			print("  %-20s %7s %14d %14d %14d %14d" % [m, reached, p[p.size() / 2], p[-1], d[d.size() / 2], d[-1]])
	quit(0)
