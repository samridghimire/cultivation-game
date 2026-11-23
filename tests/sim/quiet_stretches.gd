extends SceneTree
## QA-086: is the first year ever dull? Plays seeds 1-N for D days with the default and the curious
## first-hour policy and snapshots the player's state every time the clock moves. A day is "new" when
## something grew: realm/stage, technique levels, life stats (not the ones that grow with every
## meditation: days_in_seclusion, qi_gathered, stones_earned), distinct item ids held, milestones,
## encounter ids met, NPCs with favor > 0, regions visited, goals done on the active goal ladder.
## GUIDE-290: a favor tier crossing, a friend scene and a sect lecture also count as "something new" (each opens a card the player sees).
## A quiet stretch is the run of days between two new days. Time only passes in jumps (a month of
## meditation is one jump), so a jump with no change counts all its days as quiet.
## Prints per policy: median and max stretch, new-day counts per month (median over seeds) and the
## three longest stretches with the actions of the months they sit in.
## SIM-022: --breakdown also prints, per seed and as medians, the days and qi per activity (from the GameState action on
## the call stack) from day 0 to Foundation (or the end of the run) and the days stuck at the Qi Refining peak.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/quiet_stretches.gd -- [seeds] [days] [--profile] [--breakdown]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const SKIPPED_STATS: Array[String] = ["days_in_seclusion", "qi_gathered", "stones_earned"]
const BREAKDOWN_KINDS: Array[String] = ["cultivate", "travel", "fights", "chores/work", "lend/social", "crafting", "injured/resting", "practise", "breakthrough", "events/waiting"]
var _breakdown := false
var _breakdown_rows: Array[Dictionary] = []


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 and not args[0].begins_with("--") else 10
	var days := int(args[1]) if args.size() > 1 and not args[1].begins_with("--") else 365
	for a in args:
		if a.begins_with("--days="):  # SIM-019: --days=N (default 365)
			days = int(a.substr(7))
		FirstHour.parse_start_arg(a)  # SIM-015: --start=<region_id> / --join=<sect_id>
	var hints_only := args.has("--hints-only")
	_breakdown = args.has("--breakdown")
	FirstHour.record_weeks = args.has("--weeks")  # GUIDE-280: print the hint lines and action of each week of the longest stretch
	FirstHour.sect_report = true
	FirstHour.trial_log = args.has("--trial-log")  # SIM-030: print each sect trial attempt
	for policy in ["default", "curious", "hints"]:
		if hints_only and policy != "hints":
			continue
		FirstHour.hints_policy = policy == "hints"
		FirstHour.hints_log = {"acted": {}, "idle_weeks": 0, "weeks": 0, "unmatched": {}, "idle_lists": {}}
		FirstHour.step_usec = {}
		var started := Time.get_ticks_usec()
		Combat._sim_count = 0
		_policy(seeds, days, policy == "curious")
		if args.has("--profile"):  # PERF-027: where the wall time goes (hints policy: Next-steps sources, ms per seed)
			var parts := PackedStringArray()
			for k: String in FirstHour.step_usec:
				parts.append("%s %d" % [k, int(FirstHour.step_usec[k]) / 1000 / maxi(seeds, 1)])
			print("PROFILE %s: %d ms per seed in all; %d full win-chance ratings per seed; Next-steps sources (ms per seed): %s" % [policy, (Time.get_ticks_usec() - started) / 1000 / maxi(seeds, 1), Combat._sim_count / maxi(seeds, 1), ", ".join(parts)])
		if policy == "hints":
			_print_hints_log()
			if _breakdown:
				_print_breakdown()
	quit(0)


## SIM-010: what the hints player did, and the Next-steps lines it could not act on most often.
func _print_hints_log() -> void:
	var log: Dictionary = FirstHour.hints_log
	print("Hints player: %d weeks, %d meditated with nothing to act on (%d of them preparing for a beast); acted: %s" % [log["weeks"], log["idle_weeks"], int(log.get("prepare_weeks", 0)), str(log["acted"])])
	var rows: Array = []
	for k: String in log["unmatched"]:
		rows.append([k, int(log["unmatched"][k])])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	for i in mini(5, rows.size()):
		print("  unactionable x%d: %s" % [rows[i][1], rows[i][0]])
	var acted_rows: Array = []
	for k: String in log.get("acted_lines", {}):
		acted_rows.append([k, int(log["acted_lines"][k])])
	acted_rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	for i in mini(5, acted_rows.size()):
		print("  acted x%d: %s" % [acted_rows[i][1], acted_rows[i][0]])
	if OS.get_cmdline_user_args().has("--idle-dump"):
		var idle_rows: Array = []
		for k: String in log.get("idle_lists", {}):
			idle_rows.append([k, int(log["idle_lists"][k])])
		idle_rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
		for i in mini(15, idle_rows.size()):
			print("  idle x%d: %s" % [idle_rows[i][1], idle_rows[i][0]])
	print("")


## SIM-022: the spec's activity groups from the GameState function that spent the days.
func _bucket(kind: String, _gs: Node) -> String:
	var fn := kind.trim_prefix("other:")
	if kind == "meditation":
		return "cultivate"
	if kind == "travel":
		return "travel"
	if kind == "fights" or fn == "face_threat" or fn == "_die_violently":
		return "fights"
	if fn.contains("clinic") or fn.contains("rest") or fn.contains("heal") or fn.contains("treat") or fn.contains("recover"):
		return "injured/resting"
	if fn.contains("practice") or fn.contains("practise"):
		return "practise"
	if fn.contains("breakthrough"):
		return "breakthrough"
	if fn.contains("craft") or fn.contains("brew") or fn.contains("forge") or fn.contains("cook") or fn.contains("refine") or fn.contains("inscribe"):
		return "crafting"
	if fn.contains("lend") or fn.contains("gift") or fn.contains("dialogue") or fn.contains("lesson") or kind == "lectures":
		return "lend/social"
	if kind == "work" or kind == "missions" or fn.contains("chore") or fn.contains("sell") or fn.contains("buy"):
		return "chores/work"
	return "events/waiting"


func _print_breakdown() -> void:
	print("Time breakdown (SIM-022): hints player, day 0 to Foundation or end of run; days / qi gained per activity")
	var days_by: Dictionary = {}
	var qi_by: Dictionary = {}
	var peaks: Array = []
	var misc := {}
	for r: Dictionary in _breakdown_rows:
		var parts: Array[String] = []
		for k in BREAKDOWN_KINDS:
			parts.append("%s %d/%d" % [k, int(r["days"].get(k, 0)), roundi(float(r["qi"].get(k, 0.0)))])
			days_by[k] = days_by.get(k, []) + [int(r["days"].get(k, 0))]
			qi_by[k] = qi_by.get(k, []) + [roundi(float(r["qi"].get(k, 0.0)))]
		peaks.append(int(r["peak_days"]))
		if OS.get_cmdline_user_args().has("--breakdown-raw"):
			print("    raw: %s" % str(r["raw"]))
		print("  seed %2d: %s | days at QR peak %d" % [r["seed"], ", ".join(parts), r["peak_days"]])
	var med: Array[String] = []
	for k in BREAKDOWN_KINDS:
		med.append("%s %.0f/%.0f" % [k, _median(days_by.get(k, [])), _median(qi_by.get(k, []))])
	print("  medians (days/qi): %s; days at QR peak %.0f" % [", ".join(med), _median(peaks)])
	print("")
	_breakdown_rows.clear()


static func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var v := values.duplicate()
	v.sort()
	return float(v[v.size() / 2])


## Numeric view of the player; every entry only ever grows in a healthy life.
static func snapshot(gs: Node) -> Dictionary:
	var c: CharacterData = gs.player
	var s := {"stage": c.realm_index * 100 + c.stage, "milestones": c.milestones.size(), "encounters_met": c.encounter_counts.size(), "regions": c.visited_regions.size(), "items": c.inventory.size()}
	var levels := 0
	for t: String in c.techniques:
		levels += int(c.techniques[t].get("level", 1))
	s["techniques"] = c.techniques.size() * 100 + levels
	for k: String in c.life_stats:
		if not SKIPPED_STATS.has(k):
			s["stat_" + k] = int(c.life_stats[k])
	var friends := 0
	for npc_id: String in gs.npc_favor:
		if int(gs.npc_favor[npc_id]) > 0:
			friends += 1
	s["friends"] = friends
	# GUIDE-290: a favor tier crossing, a friend scene and a sect lecture each open a card the player sees.
	var tiers := 0
	for npc_id: String in gs.npc_favor:
		tiers += Folk.tier_index(gs.data, int(gs.npc_favor[npc_id]))
	s["favor_tiers"] = tiers
	s["friend_scenes"] = c.scenes_seen.size()
	s["lecture_month"] = int(c.sect.get("lecture_month", -1)) + 1
	var done := 0
	for g: Dictionary in Guidance.active_goal_ladder(c, gs.data, gs.world_flags):
		if g.get("done", false):
			done += 1
	s["goals"] = done
	return s


static func grew(before: Dictionary, now: Dictionary) -> bool:
	for k: String in now:
		if int(now[k]) > int(before.get(k, 0)):
			return true
	return false


func _policy(seeds: int, days: int, curious: bool) -> void:
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var months := int(ceil(days / 30.0))
	var all_stretches: Array = []
	var per_month: Array = []
	for i in months:
		per_month.append([])
	var worst: Array = []
	var realms: Array = []
	var medians: Array = []
	var maxes: Array = []
	print("Quiet stretches, %s policy, %d seeds, %d days" % ["hints" if FirstHour.hints_policy else ("curious" if curious else "default"), seeds, days])
	for s in range(1, seeds + 1):
		var log := {"checkpoints": {}, "day0": -1, "last_new": 0, "last": {}, "stretches": [], "new_days": []}
		var on_days := func(n: int) -> void:
			if gs.player == null or not gs.player.alive:
				return
			var today: int = clock.total_days
			var now := snapshot(gs)
			if log["day0"] < 0:
				log["day0"] = today - n
				log["last_new"] = 0
				log["last"] = now
				return
			var rel: int = today - int(log["day0"])
			for cp in [365, 730, 1095]:
				if rel >= cp and not (log["checkpoints"] as Dictionary).has(cp):
					log["checkpoints"][cp] = "%d.%d" % [gs.player.realm_index, gs.player.stage]
			if rel > days:
				return
			if grew(log["last"], now):
				log["stretches"].append({"start": log["last_new"], "end": rel})
				log["new_days"].append(rel)
				log["last_new"] = rel
			log["last"] = now
		var row := {"seed": s, "days": {}, "qi": {}, "peak_days": 0, "done": false, "raw": {}}
		var last_qi := [gs.player.qi if gs.player != null else 0.0]
		var on_breakdown := func(n: int) -> void:
			if _breakdown and gs.player != null and not bool(row["done"]):
				var raw := String(FirstHour._activity_of(get_stack()))
				var kind := _bucket(raw, gs)
				row["raw"][raw] = int(row["raw"].get(raw, 0)) + n
				row["days"][kind] = int(row["days"].get(kind, 0)) + n
				row["qi"][kind] = float(row["qi"].get(kind, 0.0)) + maxf(0.0, gs.player.qi - float(last_qi[0]))
				if gs.player.realm_index == 1 and Cultivation.is_at_bottleneck(gs.player, gs.data):
					row["peak_days"] += n
				last_qi[0] = gs.player.qi
				if gs.player.realm_index >= 2 or (int(log["day0"]) >= 0 and int(clock.total_days) - int(log["day0"]) >= days):
					row["done"] = true
		clock.days_advanced.connect(on_days)
		clock.days_advanced.connect(on_breakdown)
		var out: Dictionary = FirstHour.play(gs, clock, s, months, curious)
		clock.days_advanced.disconnect(on_days)
		clock.days_advanced.disconnect(on_breakdown)
		_breakdown_rows.append(row)
		if FirstHour.record_weeks and FirstHour.hints_policy:
			_print_longest_weeks(log, s)
		FirstHour.week_trace.clear()
		var end_day: int = mini(days, clock.total_days - int(log["day0"])) if log["day0"] >= 0 else 0
		if end_day > int(log["last_new"]):
			log["stretches"].append({"start": log["last_new"], "end": end_day})
		var lengths: Array = []
		for st: Dictionary in log["stretches"]:
			var length: int = st["end"] - st["start"]
			lengths.append(length)
			all_stretches.append(length)
			st["seed"] = s
			st["length"] = length
			st["kinds"] = _kinds_between(out, int(st["start"]), int(st["end"]))
			worst.append(st)
		var counts: Array = []
		counts.resize(months)
		counts.fill(0)
		for d: int in log["new_days"]:
			var m := clampi((d - 1) / 30, 0, months - 1)
			counts[m] += 1
		for m in months:
			per_month[m].append(counts[m])
		medians.append(_median(lengths))
		maxes.append(lengths.max() if not lengths.is_empty() else 0)
		print("  seed %2d: %3d new days, longest stretch %3d days" % [s, log["new_days"].size(), int(maxes[-1])])
		var realm_now: String = "%d.%d" % [gs.player.realm_index, gs.player.stage] if gs.player != null else "?"
		realms.append(realm_now)
		if days > 365:
			print("  seed %2d realm.stage at day: %s" % [s, str(log["checkpoints"])])
		gs.end_session()
	if FirstHour.hints_policy and not FirstHour.sect_log.is_empty():
		var ms := 0
		var sk := 0
		for e: Dictionary in FirstHour.sect_log:
			ms += int(e.get("months", 0))
			sk += int(e.get("skipped", 0))
		print("SIM-015 sect: %d sect months over %d seeds, %d stipends skipped for missed duty (duty met %d months); realms at end: %s" % [ms, seeds, sk, ms - sk, str(realms)])
	elif FirstHour.hints_policy:
		print("SIM-015 realms at end: %s" % str(realms))
	print("Stretch (days between new things): median %.0f, max %d; median of per-seed medians %.0f, of per-seed maxes %.0f" % [_median(all_stretches), all_stretches.max() if not all_stretches.is_empty() else 0, _median(medians), _median(maxes)])
	var line := PackedStringArray()
	for m in months:
		line.append(str(int(_median(per_month[m]))))
	print("New days per month (median over seeds): %s" % " ".join(line))
	worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["length"] > b["length"] or (a["length"] == b["length"] and a["seed"] < b["seed"]))
	for i in mini(3, worst.size()):
		var w: Dictionary = worst[i]
		print("  longest %d: seed %d, days %d-%d (%d days), months %s, actions: %s" % [i + 1, w["seed"], w["start"], w["end"], w["length"], str(w["months"] if w.has("months") else _month_range(w)), w["kinds"]])
	print("")


## GUIDE-280: the weeks of the seed's longest quiet stretch: the day, the action the hints player took and the top hint lines.
func _print_longest_weeks(log: Dictionary, seed_n: int) -> void:
	var best := {"start": 0, "end": 0}
	for st: Dictionary in log["stretches"]:
		if int(st["end"]) - int(st["start"]) > int(best["end"]) - int(best["start"]):
			best = st
	print("  seed %d longest stretch days %d-%d, week by week (action | line acted on):" % [seed_n, best["start"], best["end"]])
	var first_week := true
	for w: Dictionary in FirstHour.week_trace:
		var rel: int = int(w["day"]) - int(log["day0"])
		if rel < int(best["start"]) - 6 or rel > int(best["end"]):
			continue
		print("    day %4d | %-9s | %s" % [rel, w["acted"], w["line"]])
		if first_week:
			for l: String in w["top"]:
				print("        shown: %s" % l)
			first_week = false


static func _month_range(st: Dictionary) -> String:
	return "%d-%d" % [int(st["start"]) / 30 + 1, maxi(int(st["start"]), int(st["end"]) - 1) / 30 + 1]


## Actions of the months a stretch touches: every month meditates and explores; the curious policy adds more.
static func _kinds_between(out: Dictionary, start_day: int, end_day: int) -> String:
	var seen := {"meditate": true, "explore": true}
	var first := start_day / 30
	var last := maxi(start_day, end_day - 1) / 30
	for m in range(first, last + 1):
		if m < out["kind_sets"].size():
			for k: String in out["kind_sets"][m]:
				seen[k] = true
	return ",".join(seen.keys())
