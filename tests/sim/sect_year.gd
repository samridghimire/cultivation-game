extends SceneTree
## SIM-028: a sect year in numbers. For each joinable start-region sect a fresh character joins on day 0 at the sect's home and
## the hints player (tests/sim/first_hour.gd, sect_report on) plays a year. Per sect and seed it prints the day the character
## reported at the hall, lectures attended, missions done, contribution earned, rank at day 120 and day 365 of the run, the months the
## monthly duty was met or short, and the stipend stones paid. A summary line per sect flags a first promotion later than
## day 120 or more than 3 duty-short months. Measures only; it changes no data.
## Days are counted from the day the character joined (a mortal cannot join before the first breakthrough, so "day 0" is that day); "reported" is days after joining.
## SIM-029: also prints, per seed, the day (after joining, checked at each month end) each SECT-035 goal row (report, lecture, mission, rank 1)
## was first seen done, or "never" with the hints player's top hint line at the end of the run.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/sect_year.gd -- [seeds] [days] [--sects=a,b,c]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const DEFAULT_SECTS: Array[String] = ["azure_cloud_sect", "blood_lotus_sect", "myriad_treasure_pavilion"]


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 and not args[0].begins_with("--") else 3
	var days := int(args[1]) if args.size() > 1 and not args[1].begins_with("--") else 365
	var sects: Array[String] = DEFAULT_SECTS.duplicate()
	for a in args:
		if a.begins_with("--sects="):
			sects.assign(a.substr(8).split(","))
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var bus: Node = root.get_node("EventBus")
	FirstHour.hints_policy = true
	FirstHour.sect_report = true
	var months := int(ceil(days / 30.0))
	for sect_id in sects:
		var def: SectDef = gs.data.sects.get(sect_id)
		if def == null:
			print("unknown sect %s" % sect_id)
			continue
		FirstHour.start_region = def.home_region
		FirstHour.join_sect_id = sect_id
		print("Sect year: %s (home %s), hints player, %d days" % [sect_id, def.home_region, days])
		print("  %-4s %8s %9s %9s %12s %9s %9s %11s %9s %7s" % ["seed", "reported", "lectures", "missions", "contribution", "rank@120", "rank@365", "duty met/short", "stipend", "joined"])
		var first_promo: Array = []
		var short_months: Array = []
		for s in range(1, seeds + 1):
			FirstHour.sect_log.clear()
			var rec := {"start": -1, "reported": -1, "promos": [], "stipend": 0}
			var on_report := func(_id: String, _items: Dictionary) -> void:
				if rec["reported"] < 0:
					rec["reported"] = clock.total_days
			var on_promo := func(_id: String, rank: int) -> void:
				rec["promos"].append([clock.total_days, rank])
			var on_msg := func(text: String, _category: String) -> void:
				if text.begins_with("Your sect pays your monthly stipend"):
					var m := RegEx.create_from_string("(\\d+) [Ss]pirit [Ss]tone").search(text)
					if m != null:
						rec["stipend"] += int(m.get_string(1))
			bus.sect_reported.connect(on_report)
			bus.sect_promoted.connect(on_promo)
			bus.message_posted.connect(on_msg)
			var rows: Dictionary = {}  # SIM-029: goal row index -> absolute day first seen done
			var day0: int = 0  # a new session restarts the clock at day 0
			var hook := func(_month: int) -> void:
				var pc: CharacterData = gs.player
				if pc == null or pc.is_rogue():
					return
				var gl: Array[Dictionary] = Guidance.sect_goals(pc, gs.data, gs.world_flags, clock.total_days)
				for i in gl.size():
					if bool(gl[i]["done"]) and not rows.has(i):
						rows[i] = clock.total_days
			var out: Dictionary = FirstHour.play(gs, clock, s, months, false, hook)
			var joined: int = int(out["sect_day"]) - day0 if int(out["sect_day"]) >= 0 else -1
			var unreported: bool = gs.player != null and Sects.needs_report(gs.player)
			bus.sect_reported.disconnect(on_report)
			bus.sect_promoted.disconnect(on_promo)
			bus.message_posted.disconnect(on_msg)
			var e: Dictionary = FirstHour.sect_log[-1] if not FirstHour.sect_log.is_empty() else {}
			var contribution := int(gs.player.sect.get("contribution", 0)) if gs.player != null and not gs.player.is_rogue() else -1
			var r120 := 0
			var r365 := 0
			var promo_day := -1
			for p: Array in rec["promos"]:
				var rel: int = int(p[0]) - day0
				if promo_day < 0:
					promo_day = rel
				if rel <= 120:
					r120 = int(p[1])
				if rel <= 365:
					r365 = int(p[1])
			var met: int = int(e.get("months", 0)) - int(e.get("skipped", 0))
			var short: int = int(e.get("skipped", 0))
			first_promo.append(promo_day)
			short_months.append(short)
			var rep_day: int = maxi(0, int(rec["reported"]) - maxi(joined, 0)) if int(rec["reported"]) >= 0 else -1  # SECT-039: a start-day join reports before the first month-loop day
			print("  %-4d %8s %9d %9d %12d %9d %9d %11s %9d %7s" % [s, str(rep_day) if rep_day >= 0 else "never", int(e.get("lectures", 0)), int(e.get("missions", 0)), contribution, r120, r365, "%d/%d" % [met, short], int(rec["stipend"]), str(joined) + ("*" if unreported else "")])
			var top_hint := ""
			if gs.player != null and not gs.player.is_rogue():
				var hs: PackedStringArray = Guidance.hints(gs.player, gs.data, gs.hint_density(), 1, gs.npcs, gs.world_flags, gs.current_region, clock.total_days, gs.npc_favor)
				top_hint = hs[0] if hs.size() > 0 else ""
			var parts: Array[String] = []
			var labels: Array[String] = ["report", "lecture", "mission", "rank 1"]
			var glist: Array[Dictionary] = Guidance.sect_goals(gs.player, gs.data, gs.world_flags, clock.total_days) if gs.player != null else []
			for i in glist.size():
				parts.append("%s %s" % [labels[i] if i < labels.size() else str(i), str(int(rows[i]) - maxi(joined, 0)) if rows.has(i) else "never"])
			print("       goal rows (day after joining, month-end check): %s%s" % [", ".join(parts), ("  | top hint: " + top_hint) if top_hint != "" else ""])
			gs.end_session()
		var late := 0
		var many_short := 0
		for i in first_promo.size():
			if int(first_promo[i]) < 0 or int(first_promo[i]) > 120:
				late += 1
			if int(short_months[i]) > 3:
				many_short += 1
		print("  first promotion after day 120 (or never): %d/%d seeds; duty short > 3 months: %d/%d seeds; first promotion days: %s" % [late, seeds, many_short, seeds, str(first_promo)])
		print("")
	quit(0)
