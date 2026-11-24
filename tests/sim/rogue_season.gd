extends SceneTree
## SIM-031: the rogue's first season. Real games start in Qingshi Village as a rogue. The hints player
## (tests/sim/first_hour.gd) plays N days from a fresh start; per seed this prints the day of the first friend (favor 40,
## the first favor tier), first fighting style, first fair fight won, sect joined (and which), first report and first lecture.
## "-" = not by the end of the run. Lecture and report days are noted at each month end / by signal, so lectures are +-30 days.
## Also prints the 3 most-shown hint lines the hints player could not act on.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/rogue_season.gd -- [seeds] [days]

const FirstHour := preload("res://tests/sim/first_hour.gd")


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 and not args[0].begins_with("--") else 10
	var days := int(args[1]) if args.size() > 1 and not args[1].begins_with("--") else 180
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var bus: Node = root.get_node("EventBus")
	FirstHour.hints_policy = true
	FirstHour.weekly_extras = true  # SIM-033
	FirstHour.start_region = "qingshi_village"
	print("Rogue's first season (hints player, seeds 1-%d, %d days, start qingshi_village)" % [seeds, days])
	print("  %-4s %7s %6s %9s %7s %-26s %7s" % ["seed", "friend", "style", "fair win", "sect", "which", "report"])
	var cols := [[], [], [], [], [], []]
	FirstHour.hints_log = {"acted": {}, "idle_weeks": 0, "weeks": 0, "unmatched": {}}
	for s in range(1, seeds + 1):
		var rec := {"report": -1, "lecture": -1}
		var on_report := func(_id: String, _items: Dictionary) -> void:
			if rec["report"] < 0:
				rec["report"] = clock.total_days
		bus.sect_reported.connect(on_report)
		var hook := func(_month: int) -> void:
			if rec["lecture"] < 0 and gs.player != null and LifeStats.get_stat(gs.player, "lectures_attended") > 0:
				rec["lecture"] = clock.total_days
		var out: Dictionary = FirstHour.play(gs, clock, s, int(ceil(days / 30.0)), false, hook)
		bus.sect_reported.disconnect(on_report)
		var first: Dictionary = FirstHour.press_log["first"]
		var which := ""
		if gs.player != null and not gs.player.is_rogue():
			which = String(gs.player.sect.get("id", gs.player.sect.get("sect_id", "?")))
		var vals: Array[int] = [
			int(first["first_friend"]["day"]) if first.has("first_friend") else -1,
			int(out["first_style_day"]), int(out["first_win_day"]), int(out["sect_day"]),
			int(rec["report"]), int(rec["lecture"])]
		for i in vals.size():
			if vals[i] > days:
				vals[i] = -1
		var f := func(v: int) -> String: return str(v) if v >= 0 else "-"
		print("  %-4d %7s %6s %9s %7s %-26s %7s %8s" % [s, f.call(vals[0]), f.call(vals[1]), f.call(vals[2]), f.call(vals[3]), which if which != "" else "-", f.call(vals[4]), "lect " + f.call(vals[5])])
		for i in vals.size():
			cols[i].append(vals[i])
		gs.end_session()
	var names := ["first friend", "first style", "first fair win", "sect joined", "first report", "first lecture"]
	var parts: PackedStringArray = []
	for i in cols.size():
		var got: Array = cols[i].filter(func(v: int) -> bool: return v >= 0)
		got.sort()
		parts.append("%s %s (%d/%d)" % [names[i], str(got[got.size() / 2]) if not got.is_empty() else "never", got.size(), seeds])
	print("  Medians: " + "; ".join(parts))
	var rows: Array = []
	for k: String in FirstHour.hints_log["unmatched"]:
		rows.append([k, int(FirstHour.hints_log["unmatched"][k])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	print("  Most-shown hints the player could not act on (all seeds):")
	for i in mini(3, rows.size()):
		print("    %4d x %s" % [rows[i][1], rows[i][0]])
	quit(0)
