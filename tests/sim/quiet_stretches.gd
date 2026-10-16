extends SceneTree
## QA-086: is the first year ever dull? Plays seeds 1-N for D days with the default and the curious
## first-hour policy and snapshots the player's state every time the clock moves. A day is "new" when
## something grew: realm/stage, technique levels, life stats (not the ones that grow with every
## meditation: days_in_seclusion, qi_gathered, stones_earned), distinct item ids held, milestones,
## encounter ids met, NPCs with favor > 0, regions visited, goals done on the active goal ladder.
## A quiet stretch is the run of days between two new days. Time only passes in jumps (a month of
## meditation is one jump), so a jump with no change counts all its days as quiet.
## Prints per policy: median and max stretch, new-day counts per month (median over seeds) and the
## three longest stretches with the actions of the months they sit in.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/quiet_stretches.gd -- [seeds] [days]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const SKIPPED_STATS: Array[String] = ["days_in_seclusion", "qi_gathered", "stones_earned"]


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var days := int(args[1]) if args.size() > 1 else 365
	for curious in [false, true]:
		_policy(seeds, days, curious)
	quit(0)


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
	var medians: Array = []
	var maxes: Array = []
	print("Quiet stretches, %s policy, %d seeds, %d days" % ["curious" if curious else "default", seeds, days])
	for s in range(1, seeds + 1):
		var log := {"day0": -1, "last_new": 0, "last": {}, "stretches": [], "new_days": []}
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
			if rel > days:
				return
			if grew(log["last"], now):
				log["stretches"].append({"start": log["last_new"], "end": rel})
				log["new_days"].append(rel)
				log["last_new"] = rel
			log["last"] = now
		clock.days_advanced.connect(on_days)
		var out: Dictionary = FirstHour.play(gs, clock, s, months, curious)
		clock.days_advanced.disconnect(on_days)
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
		gs.end_session()
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
