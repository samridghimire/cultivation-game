extends SceneTree
## First-hour sim (QA-016): scripted newcomers in Qingshi Village (tests/sim/first_hour.gd).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_first_hour.gd -- [seeds] [months]

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
	var curious := args.has("--curious")
	var trace := args.has("--trace")  # QA-065: print each month's state and every fight
	var only_seed := 0  # --seed=N runs just that seed
	var nums: Array[int] = []
	for a in args:
		if a.begins_with("--seed="):
			only_seed = int(a.substr(7))
		elif a != "--curious" and a != "--trace":
			nums.append(int(a))
	var seeds := nums[0] if nums.size() > 0 else 30
	var months := nums[1] if nums.size() > 1 else 12
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var layers := {1: [], 3: [], 9: []}
	var sects: Array = []
	var injuries: Array = []
	var lines: Array = []
	var won: Array = []
	var lost: Array = []
	var fled: Array = []
	var first_wins: Array = []
	var first_styles: Array = []
	var no_win := 0
	var win_enemies := {}
	var by_cat := {}
	var kinds_all: Array = []
	var road_seen := {}
	var road_seeds := 0
	var zero_months := 0
	print("First-hour sim%s: %d seeds, %d months" % [" (curious player)" if curious else "", seeds, months])
	print("  seed  QR1  QR3  QR9  sect  injuries  won  lost  fled  lines/month")
	for s in range(maxi(1, only_seed), (only_seed if only_seed > 0 else seeds) + 1):
		var hook := Callable()
		var fight_notes: Array = []
		var on_start := func(enemy: Dictionary) -> void:
			fight_notes.append("%s%s (odds %.0f%%)" % [enemy.get("id", enemy.get("name", "?")), " [spar]" if enemy.get("spar", false) else "", 100.0 * Combat.win_chance(gs.player, gs.data, enemy)])
		var on_end := func(_n: String, victory: bool, _l: PackedStringArray) -> void:
			fight_notes[fight_notes.size() - 1] += " -> " + ("won" if victory else "lost")
		if trace:
			var bus: Node = root.get_node("EventBus")
			bus.combat_started.connect(on_start)
			bus.combat_finished.connect(on_end)
			hook = func(month: int) -> void:
				var p: CharacterData = gs.player
				var techs: Array = []
				for t: String in p.techniques:
					techs.append("%s:%s" % [t, str(p.techniques[t])])
				print("    m%02d day %d %s %s stones %d techs %s hint: %s | fights: %s" % [month + 1, clock.total_days, gs.current_region, Cultivation.realm_label(p, gs.data), p.item_count("spirit_stone"), str(techs), str(Guidance.hints(p, gs.data, 1.0, 5, gs.npcs, gs.world_flags, gs.current_region, clock.total_days, gs.npc_favor)), str(fight_notes)])
				fight_notes.clear()
		var r: Dictionary = FirstHour.play(gs, clock, s, months, curious, hook)
		if trace:
			var bus2: Node = root.get_node("EventBus")
			bus2.combat_started.disconnect(on_start)
			bus2.combat_finished.disconnect(on_end)
		var total := 0
		if not r["road"].is_empty():
			road_seeds += 1
		for rid: String in r["road"]:
			road_seen[rid] = int(road_seen.get(rid, 0)) + 1
		for k: int in r["kinds"]:
			kinds_all.append(k)
		for m in range(1, r["month_lines"].size()):
			if r["month_lines"][m].is_empty():
				zero_months += 1
		for counts: Dictionary in r["month_lines"]:
			for cat: String in counts:
				by_cat[cat] = int(by_cat.get(cat, 0)) + int(counts[cat])
				total += int(counts[cat])
		var per_month := float(total) / maxi(1, r["month_lines"].size())
		for layer: int in layers:
			if r["layer_day"].has(layer):
				layers[layer].append(r["layer_day"][layer])
		if r["sect_day"] >= 0:
			sects.append(r["sect_day"])
		injuries.append(r["injuries"])
		lines.append(per_month)
		won.append(r["fights_won"])
		lost.append(r["fights_lost"])
		fled.append(r["fights_fled"])
		print("  %4d  %3s  %3s  %3s  %4s  %8d  %3d  %4d  %4d  %.1f" % [s, r["layer_day"].get(1, "-"), r["layer_day"].get(3, "-"), r["layer_day"].get(9, "-"), r["sect_day"] if r["sect_day"] >= 0 else "-", r["injuries"], r["fights_won"], r["fights_lost"], r["fights_fled"], per_month])
		print("        first win day %s (%s), style bought day %s" % [r["first_win_day"] if r["first_win_day"] >= 0 else "-", r["first_win_enemy"] if r["first_win_enemy"] != "" else "-", r["first_style_day"] if r["first_style_day"] >= 0 else "-"])
		if r["first_win_day"] >= 0:
			first_wins.append(r["first_win_day"])
			win_enemies[r["first_win_enemy"]] = int(win_enemies.get(r["first_win_enemy"], 0)) + 1
		else:
			no_win += 1
		if r["first_style_day"] >= 0:
			first_styles.append(r["first_style_day"])
		gs.end_session()
	print("Medians (day): QR1 %.0f, QR3 %.0f, QR9 %.0f (%d/%d seeds reached it), sect %.0f; injuries %.0f; fights won %.0f, lost %.0f, fled %.0f; %.1f log lines/month" % [_median(layers[1]), _median(layers[3]), _median(layers[9]), layers[9].size(), seeds, _median(sects), _median(injuries), _median(won), _median(lost), _median(fled), _median(lines)])
	print("First win: median day %.0f, seeds with no win in %d months: %d; first-win foes: %s; median style day %.0f (%d seeds)" % [_median(first_wins), months, no_win, str(win_enemies), _median(first_styles), first_styles.size()])
	if curious:
		var sum := 0
		for k: int in kinds_all:
			sum += k
		print("Distinct action kinds per month: %.1f; months after the first with no log lines: %d" % [float(sum) / maxi(1, kinds_all.size()), zero_months])
	print("Road encounters (QA-118): %d/%d seeds met one; %s" % [road_seeds, seeds, str(road_seen)])
	print("Lines by category: %s" % str(by_cat))
	quit()
