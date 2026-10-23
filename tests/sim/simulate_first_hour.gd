extends SceneTree
## First-hour sim (QA-016): scripted newcomers in Qingshi Village (tests/sim/first_hour.gd).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_first_hour.gd -- [seeds] [months]  [--curious] [--trace] [--zero] [--forced]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const FORCED_ODDS := 0.2


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])




func _mask_digits(text: String) -> String:
	var out := ""
	for ch in text:
		out += "#" if ch >= "0" and ch <= "9" else ch
	return out


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var curious := args.has("--curious")
	var zero := args.has("--zero")  # QA-126: count fights rated 0%, by what started them
	var forced := args.has("--forced")  # QA-139: tally every fight rated under 20%, by source, with its outcome
	var long_hints := args.has("--long-hints")  # QA-143: tally hint lines longer than the HUD cap
	var long_rows := {}
	var forced_rows: Array = []
	var zero_by := {}
	var fights_seen := {"n": 0}
	FirstHour.attempt_trials = not args.has("--no-trial")  # QA-136
	FirstHour.heal_injuries = curious and not args.has("--no-heal")  # QA-128
	FirstHour.heal_log = {"healed": 0, "stones": 0}
	FirstHour.min_mission_odds = 0.0 if args.has("--blind-missions") else 0.4  # QA-141
	FirstHour.chase_best_mission = not args.has("--one-mission")  # QA-134
	FirstHour.shop_armor = curious and not args.has("--no-armor")  # QA-140
	FirstHour.armor_log = {"day": -1, "sold": 0, "stones_from_sales": 0, "trips": 0}
	FirstHour.buy_qi = curious and args.has("--buy-qi")  # QA-144
	FirstHour.qi_log = {"bought": 0, "stones": 0, "used": 0, "qi": 0}
	FirstHour.spend_contribution = curious and args.has("--spend-contribution")  # QA-148
	FirstHour.contribution_log = {"pill_days": [], "pill": 0, "body": 0, "qi_items": 0, "qi_cost": 0, "qi_used": 0, "qi": 0}
	FirstHour.spar_hint = curious and not args.has("--no-spar-hint")  # QA-138
	FirstHour.spar_log = {"bouts": 0, "refused": []}
	FirstHour.bounty_log = {"offered": {}, "taken": {}}
	var contrib6: Array = []  # QA-146
	var contrib12: Array = []
	var stage12: Array = []
	var pill_stones: Array = []
	var trace := args.has("--trace")  # QA-065: print each month's state and every fight
	var only_seed := 0  # --seed=N runs just that seed
	var nums: Array[int] = []
	for a in args:
		if a.begins_with("--seed="):
			only_seed = int(a.substr(7))
		elif a != "--curious" and a != "--trace" and a != "--zero" and a != "--forced" and a != "--no-trial" and a != "--no-heal" and a != "--no-spar-hint" and a != "--blind-missions" and a != "--one-mission" and a != "--long-hints" and a != "--buy-qi" and a != "--spend-contribution" and a != "--no-armor":
			nums.append(int(a))
	var seeds := nums[0] if nums.size() > 0 else 30
	var months := nums[1] if nums.size() > 1 else 12
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var layers := {1: [], 3: [], 9: []}
	var sects: Array = []
	var rank_days: Array = []  # QA-136
	var final_stones: Array = []
	var iron_levels := {3: [], 6: [], 12: []}  # QA-138: Iron Fist level after months 3, 6, 12
	var wolf_days: Array = []
	var armor_days: Array = []  # QA-140
	var trials_won := 0
	var trials_lost := 0
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
		var on_zero := func(enemy: Dictionary) -> void:
			fights_seen["n"] += 1
			if Combat.win_chance(gs.player, gs.data, enemy) >= 0.005:
				return
			var source := "other"
			for frame: Dictionary in get_stack():
				var fn := String(frame["function"])
				if fn not in ["<anonymous lambda>", "fight_enemy", "fight"]:
					source = fn
					break
			zero_by[source] = int(zero_by.get(source, 0)) + 1
		var on_forced_start := func(enemy: Dictionary) -> void:
			var odds: float = Combat.win_chance(gs.player, gs.data, enemy)
			if odds >= FORCED_ODDS or enemy.get("spar", false):
				return
			var source := "other"
			for frame: Dictionary in get_stack():
				var fn := String(frame["function"])
				if fn not in ["<anonymous lambda>", "fight_enemy", "fight"]:
					source = fn
					break
			forced_rows.append({"seed": s, "id": String(enemy.get("id", "?")), "source": source, "layer": gs.player.stage + 1, "odds": odds, "hurt": gs.player.injuries.size(), "outcome": ""})
		var on_forced_end := func(_n: String, victory: bool, _l: PackedStringArray) -> void:
			if forced_rows.is_empty() or forced_rows[forced_rows.size() - 1]["outcome"] != "":
				return
			var row: Dictionary = forced_rows[forced_rows.size() - 1]
			row["outcome"] = "won" if victory else "lost"
			row["new_injury"] = gs.player.injuries.size() > int(row["hurt"])
		if forced:
			root.get_node("EventBus").combat_started.connect(on_forced_start)
			root.get_node("EventBus").combat_finished.connect(on_forced_end)
		if zero:
			root.get_node("EventBus").combat_started.connect(on_zero)
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
		var trace_hook := hook
		hook = func(month: int) -> void:
			if trace_hook.is_valid():
				trace_hook.call(month)
			if long_hints:
				var density: float = gs.hint_density()
				for h: String in Guidance.hints(gs.player, gs.data, density, 5, gs.npcs, gs.world_flags, gs.current_region, clock.total_days, gs.npc_favor):
					if h.length() > Guidance.HEADLINE_CHARS:
						var key := _mask_digits(h.substr(0, 30))
						var row: Dictionary = long_rows.get(key, {"count": 0, "max": 0, "example": ""})
						row["count"] += 1
						row["max"] = maxi(int(row["max"]), h.length())
						if row["example"] == "":
							row["example"] = h
						long_rows[key] = row
			if month == 2 or month == 5 or month == 11:
				iron_levels[month + 1].append(Techniques.level(gs.player, "iron_fist"))  # QA-138
		var r: Dictionary = FirstHour.play(gs, clock, s, months, curious, hook)
		var contribs: Array = r["contribution"]
		if contribs.size() >= 6:
			contrib6.append(contribs[5])
		if contribs.size() >= 12:
			contrib12.append(contribs[11])
		if r["realms"].size() >= 12:
			stage12.append(r["realms"][11])
		if r["bottleneck_stones"] >= 0:
			pill_stones.append(r["bottleneck_stones"])
		if FirstHour.armor_log["day"] >= 0:
			armor_days.append(FirstHour.armor_log["day"])
		if FirstHour.wolf_win_day >= 0:
			wolf_days.append(FirstHour.wolf_win_day)
		if forced:
			root.get_node("EventBus").combat_started.disconnect(on_forced_start)
			root.get_node("EventBus").combat_finished.disconnect(on_forced_end)
		if zero:
			root.get_node("EventBus").combat_started.disconnect(on_zero)
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
		if r["rank_day"] >= 0:
			rank_days.append(r["rank_day"])
		if not r["stones"].is_empty():
			final_stones.append(r["stones"][r["stones"].size() - 1])
		trials_won += int(r["trials_won"])
		trials_lost += int(r["trials_lost"])
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
		print("Sect trials: Inner Disciple median day %.0f (%d/%d seeds); trials won %d, lost %d; stones at the last month: median %.0f" % [_median(rank_days), rank_days.size(), seeds, trials_won, trials_lost, _median(final_stones)])
		var sum := 0
		for k: int in kinds_all:
			sum += k
		print("Distinct action kinds per month: %.1f; months after the first with no log lines: %d" % [float(sum) / maxi(1, kinds_all.size()), zero_months])
	if curious:
		print("Injury treatments (QA-128): %d, clinic stones %d%s" % [FirstHour.heal_log["healed"], FirstHour.heal_log["stones"], "" if FirstHour.heal_injuries else " (--no-heal)"])
	if curious:
		print("Iron Fist level median (QA-138): m03 %.0f, m06 %.0f, m12 %.0f; first Mist Wolf win: median day %.0f (%d/%d seeds)" % [_median(iron_levels[3]), _median(iron_levels[6]), _median(iron_levels[12]), _median(wolf_days), wolf_days.size(), seeds])
		print("Spar-hint bouts (QA-138): %d, refusals: %s%s" % [FirstHour.spar_log["bouts"], str(FirstHour.spar_log["refused"]), "" if FirstHour.spar_hint else " (--no-spar-hint)"])
	if curious:
		print("Armor shopping (QA-140): armor worn by day %.0f median (%d/%d seeds); %d loot sales for %d stones, %d trips to a smithy%s" % [_median(armor_days), armor_days.size(), seeds, FirstHour.armor_log["sold"], FirstHour.armor_log["stones_from_sales"], FirstHour.armor_log["trips"], "" if FirstHour.shop_armor else " (--no-armor)"])
	if FirstHour.buy_qi:
		print("Qi pills (QA-144): bought %d for %d stones, used %d, qi %d" % [FirstHour.qi_log["bought"], FirstHour.qi_log["stones"], FirstHour.qi_log["used"], FirstHour.qi_log["qi"]])
	if FirstHour.spend_contribution:
		var cl: Dictionary = FirstHour.contribution_log
		print("Contribution spent (QA-148): pill %d seeds (median day %.0f), body art %d contribution, qi pills %d for %d contribution, used %d, qi %d" % [cl["pill_days"].size(), _median(cl["pill_days"]), cl["body"], cl["qi_items"], cl["qi_cost"], cl["qi_used"], cl["qi"]])
	print("Road encounters (QA-118): %d/%d seeds met one; %s" % [road_seeds, seeds, str(road_seen)])
	if zero:
		print("Fights rated 0%%: %d of %d, by source: %s" % [zero_by.values().reduce(func(a: int, b: int) -> int: return a + b, 0), fights_seen["n"], str(zero_by)])
	if forced:
		print("Fights rated under %.0f%% (QA-139): %d" % [100.0 * FORCED_ODDS, forced_rows.size()])
		print("  seed  enemy  source  layer  odds  outcome  injured")
		for row: Dictionary in forced_rows:
			print("  %4d  %s  %s  QR%d  %.0f%%  %s  %s" % [row["seed"], row["id"], row["source"], row["layer"], 100.0 * float(row["odds"]), row["outcome"], "yes" if row.get("new_injury", false) else "no"])
	if long_hints:
		print("Hint lines over %d characters (QA-143), by first 30 characters (digits masked):" % Guidance.HEADLINE_CHARS)
		var keys := long_rows.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(long_rows[a]["count"]) > int(long_rows[b]["count"]))
		for key: String in keys:
			var row: Dictionary = long_rows[key]
			print("  x%d max %d | %s | cut-off: %s" % [row["count"], row["max"], key, String(row["example"]).substr(Guidance.HEADLINE_CHARS, 80)])
	var stage_counts := {}
	for full: String in stage12:
		var label := full
		if full.begins_with("Qi Refining, ") and full.length() > 16:
			label = "QR" + full.substr(13, 1)
		stage_counts[label] = int(stage_counts.get(label, 0)) + 1
	print("Sect contribution (QA-146): m06 median %.0f, m12 median %.0f; stage at m12: %s" % [_median(contrib6), _median(contrib12), str(stage_counts)])
	print("Stones at the QR9 bottleneck (QA-146): median %.0f (%d/%d seeds reached it)" % [_median(pill_stones), pill_stones.size(), seeds])
	print("Bounties (QA-146), offered by region (ids once per seed): %s; taken (times): %s" % [str(FirstHour.bounty_log["offered"]), str(FirstHour.bounty_log["taken"])])
	print("Lines by category: %s" % str(by_cat))
	quit()
