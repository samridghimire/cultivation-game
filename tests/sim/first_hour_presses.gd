extends SceneTree
## SIM-017: the first hour measured in menu presses. The hints player (tests/sim/first_hour.gd) counts the presses of every
## action it takes (PRESS_COST: open + choose + confirm, plus travel); this prints, per milestone, the median and worst of N
## seeds for presses and in-game days. A milestone held at day 0 counts as 0. "never" = not reached in the run.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/first_hour_presses.gd -- [seeds] [months] [--trace=<seed>]
## SIM-023: --start=<region_id> plays from that region; --starts=a,b,c prints one table per start (the baseline's "first hour in every start").
## (--trace: one seed, each week's top 4 hint lines and the action taken until its first win, first technique and first friend; every run prints each seed's first_win day.)

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
	var trace_seed := -1
	var starts: Array = [""]
	for a in args:
		if a.begins_with("--trace="):
			trace_seed = int(a.substr(8))
		if a.begins_with("--trace-friend="):
			trace_seed = int(a.substr(15))
			FirstHour.trace_friend = true
		if a.begins_with("--starts="):
			starts = Array(a.substr(9).split(","))
		FirstHour.parse_start_arg(a)
	for st in starts:
		if st != "":
			FirstHour.start_region = st
		_measure(gs, clock, seeds, months, trace_seed)
	quit(0)


func _measure(gs: Node, clock: Node, seeds: int, months: int, trace_seed: int) -> void:
	var presses := {}
	var days := {}
	for m in FirstHour.MILESTONES:
		presses[m] = []
		days[m] = []
	for s in range(1, seeds + 1):
		FirstHour.hints_log = {"acted": {}, "idle_weeks": 0, "weeks": 0, "unmatched": {}}
		var start_day: int = clock.total_days
		if trace_seed >= 0 and s != trace_seed:
			continue
		FirstHour.trace_first_win = trace_seed >= 0 and not FirstHour.trace_friend
		FirstHour.play(gs, clock, s, months)
		var first: Dictionary = FirstHour.press_log["first"]
		if first.has("first_win"):
			var fw := int(first["first_win"]["day"])
			print("seed %d first_win day %d" % [s, fw - start_day if start_day <= fw else fw])
		for m in FirstHour.MILESTONES:
			if first.has(m):
				presses[m].append(int(first[m]["presses"]))
				days[m].append(int(first[m]["day"]) - start_day if start_day <= int(first[m]["day"]) else int(first[m]["day"]))
		gs.end_session()
	print("first hour in presses (hints player, seeds 1-%d, %d months%s)" % [seeds, months, (", start " + FirstHour.start_region) if FirstHour.start_region != "" else ""])
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
