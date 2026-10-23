extends SceneTree
## First-hour sim (QA-016): scripted newcomers in Qingshi Village (tests/sim/first_hour.gd).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_first_hour.gd -- [seeds] [months]  [--curious] [--trace] [--zero] [--forced] [--injury-origins] [--odds-bands] [--qi-pill-cap=N]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const FORCED_ODDS := 0.2
const BAND_LABELS := ["<40", "40-70", "70-95", ">=95"]


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])




func _odds_band(odds: float) -> int:
	if odds < 0.4:
		return 0
	if odds < 0.7:
		return 1
	return 2 if odds < 0.95 else 3


## QA-151: with --far-qi, real fights before vs after the move by rated odds, with wins, injuries and artifact lives spent.
func _print_move_bands(rows: Array) -> void:
	print("Fights before/after the far-qi move (QA-151): when  band  fights  won  injured  lives spent")
	for post in [false, true]:
		for band in 4:
			var n := 0
			var wins := 0
			var hurt := 0
			var lives := 0
			for row: Dictionary in rows:
				if bool(row["post"]) == post and _odds_band(float(row["odds"])) == band:
					n += 1
					wins += 1 if row["won"] else 0
					hurt += 1 if row["injured"] else 0
					lives += 1 if row["life"] else 0
			print("  %s  %s  %d  %d  %d  %d" % ["after" if post else "before", BAND_LABELS[band], n, wins, hurt, lives])


## QA-147: fights by month and rated-odds band, the first month where >= 80% are >= 95%, and the Misty Forest foes
## (Exploration.eligible_fights) rated at months 6 and 12.
func _print_odds_bands(rows: Array, foes: Dictionary, months: int, seeds: int) -> void:
	print("Fight odds by month (QA-147), %d fights over %d seeds; bands %s:" % [rows.size(), seeds, str(BAND_LABELS)])
	print("  month  fights  <40  40-70  70-95  >=95  >=95%  median QR layer")
	var first_easy := -1
	var last_hard := -1
	for m in range(months):
		var counts := [0, 0, 0, 0]
		var stages: Array = []
		for row: Dictionary in rows:
			if int(row["month"]) == m:
				counts[_odds_band(float(row["odds"]))] += 1
				stages.append(int(row["stage"]))
		var n: int = counts[0] + counts[1] + counts[2] + counts[3]
		var share := float(counts[3]) / n if n > 0 else 0.0
		if first_easy < 0 and n >= 5 and share >= 0.8:
			first_easy = m + 1
		if n >= 5 and share < 0.8:
			last_hard = m + 1
		print("  %5d  %6d  %3d  %5d  %5d  %4d  %4.0f%%  %s" % [m + 1, n, counts[0], counts[1], counts[2], counts[3], 100.0 * share, "%.0f" % _median(stages) if not stages.is_empty() else "-"])
	print("First month with >= 80%% of fights rated >= 95%% (at least 5 fights): %s" % ["m%d" % first_easy if first_easy > 0 else "none"])
	print("Last month with at least 5 fights where under 80%% were rated >= 95%%: %s" % ["m%d" % last_hard if last_hard > 0 else "none"])
	print("Misty Forest foes (eligible fights), rated for each seed's player at m6 / m12: foe  median odds  min odds  seeds under 70%  (unhurt median)")
	for key: String in foes:
		var vals: Array = foes[key]
		var odds: Array = []
		var unhurt: Array = []
		var under := 0
		for v: Array in vals:
			odds.append(v[0])
			if v[1] >= 0.0:
				unhurt.append(v[1])
			if v[0] < 0.7:
				under += 1
		print("  %s  %.0f%%  %.0f%%  %d/%d  %s" % [key, 100.0 * _median(odds.duplicate()), 100.0 * float(odds.min()), under, odds.size(), "%.0f%%" % (100.0 * _median(unhurt)) if not unhurt.is_empty() else "-"])


func _mask_digits(text: String) -> String:
	var out := ""
	for ch in text:
		out += "#" if ch >= "0" and ch <= "9" else ch
	return out


## QA-149: injuries that began in the first 365 days, with their source and what the clinic would cost against the
## stones held, the breakthrough attempts, and a summary of the early (first 120 days) injuries.
func _print_injury_origins(rows: Array, slow_days: Array, breaks: Array, seeds: int) -> void:
	print("Breakthrough attempts in the first 365 days (QA-149):")
	print("  seed  day  from  chance  pill  success  injury")
	for b: Dictionary in breaks:
		print("  %4d  %3d  r%d  %.0f%%  %s  %s  %s" % [b["seed"], b["day"], b["from_realm"], 100.0 * float(b["chance"]), "yes" if b["pill"] else "no", "yes" if b["success"] else "no", "yes" if b["injury"] else "no"])
	print("Injuries begun in the first 365 days (QA-149):")
	print("  seed  day  injury  source  stones  clinic")
	var early_seeds := {}
	var by_source := {}
	var afford := 0
	var early := 0
	for row: Dictionary in rows:
		if int(row["day"]) > 365:
			continue
		print("  %4d  %3d  %s  %s  %d  %d" % [row["seed"], row["day"], row["id"], row["source"], row["stones"], row["cost"]])
		if int(row["day"]) <= 120:
			early += 1
			early_seeds[row["seed"]] = true
			by_source[row["source"]] = int(by_source.get(row["source"], 0)) + 1
			if int(row["stones"]) >= int(row["cost"]):
				afford += 1
	print("Slowed days per seed (months with a cultivation_mult < 1 injury at month end): %s; median %.0f" % [str(slow_days), _median(slow_days)])
	print("Seeds with an injury in the first 120 days: %d/%d; %d injuries by source %s; clinic affordable the day it began: %d/%d" % [early_seeds.size(), seeds, early, str(by_source), afford, early])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var curious := args.has("--curious")
	var zero := args.has("--zero")  # QA-126: count fights rated 0%, by what started them
	var forced := args.has("--forced")  # QA-139: tally every fight rated under 20%, by source, with its outcome
	var long_hints := args.has("--long-hints")  # QA-143: tally hint lines longer than the HUD cap
	var odds_bands := args.has("--odds-bands")  # QA-147: fights by month and rated-odds band
	var move_rows: Array = []
	var band_rows: Array = []
	var band_foes := {}
	var injury_origins := args.has("--injury-origins")  # QA-149: where and when injuries begin in the first year
	var origin_rows: Array = []  # {seed, day, id, source, stones, cost}
	var slow_days: Array = []  # per seed: days (month-granular) cultivating under a cultivation_mult < 1 injury
	var break_rows: Array = []  # {seed, day, from, chance, success, injury}
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
	FirstHour.qi_pill_cap = -1  # QA-150
	FirstHour.contribution_log = {"pill_days": [], "pill": 0, "body": 0, "qi_items": 0, "qi_cost": 0, "qi_used": 0, "qi": 0}
	FirstHour.far_qi = args.has("--far-qi")  # QA-145
	FirstHour.far_qi_log = {"moved": 0, "month": [], "road_days": []}
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
		elif a.begins_with("--qi-pill-cap="):
			FirstHour.qi_pill_cap = int(a.substr(14))  # QA-150
		elif a != "--curious" and a != "--trace" and a != "--zero" and a != "--forced" and a != "--no-trial" and a != "--no-heal" and a != "--no-spar-hint" and a != "--blind-missions" and a != "--one-mission" and a != "--long-hints" and a != "--buy-qi" and a != "--spend-contribution" and a != "--no-armor" and a != "--far-qi" and a != "--injury-origins" and a != "--odds-bands":
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
		var seen_injuries := {}
		var slowed := {"days": 0}
		var on_message := func(_text: String, _category: String) -> void:
			var p: CharacterData = gs.player
			for id: String in p.injuries:
				if seen_injuries.has(id):
					continue
				seen_injuries[id] = true
				var source := "other"
				for frame: Dictionary in get_stack():
					var fn := String(frame["function"])
					if fn not in ["<anonymous lambda>", "post", "_post"] and not fn.begins_with("_on_"):
						source = fn
						break
				origin_rows.append({"seed": s, "day": clock.total_days, "id": id, "source": source, "stones": p.item_count("spirit_stone"), "cost": Medicine.clinic_cost(p, gs.data, id)})
			for id: String in seen_injuries.keys():
				if not p.injuries.has(id):
					seen_injuries.erase(id)
		if injury_origins:
			root.get_node("EventBus").message_posted.connect(on_message)
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
		var on_band_start := func(enemy: Dictionary) -> void:
			band_rows.append({"month": (clock.total_days - 1) / Calendar.DAYS_PER_MONTH, "odds": Combat.win_chance(gs.player, gs.data, enemy), "stage": gs.player.stage + 1})
		var on_move_start := func(enemy: Dictionary) -> void:
			if enemy.get("spar", false):
				return
			move_rows.append({"post": FirstHour.far_qi_day >= 0, "odds": Combat.win_chance(gs.player, gs.data, enemy), "hurt": gs.player.injuries.size(), "lives": gs.player.artifact_lives, "won": true, "injured": false, "life": false})
		var on_move_end := func(_n: String, victory: bool, _l: PackedStringArray) -> void:
			if move_rows.is_empty():
				return
			var row: Dictionary = move_rows[move_rows.size() - 1]
			row["won"] = victory
			row["injured"] = gs.player.injuries.size() > int(row["hurt"])
			row["life"] = gs.player.artifact_lives < int(row["lives"])
		if FirstHour.far_qi and odds_bands:
			root.get_node("EventBus").combat_started.connect(on_move_start)
			root.get_node("EventBus").combat_finished.connect(on_move_end)
		if odds_bands:
			root.get_node("EventBus").combat_started.connect(on_band_start)
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
			if injury_origins and Injuries.cultivation_multiplier(gs.player, gs.data) < 1.0 and clock.total_days <= 365 + Calendar.DAYS_PER_MONTH:
				slowed["days"] += Calendar.DAYS_PER_MONTH
			if odds_bands and (month == 5 or month == 11):
				for foe_id: String in Exploration.eligible_fights(gs.player, gs.data, ["forest", "wild"], gs.world_flags, "spring", "misty_forest"):
					var foe: Dictionary = gs.data.enemies[foe_id]
					var key := "%s (m%d)" % [foe_id, month + 1]
					if not band_foes.has(key):
						band_foes[key] = []
					band_foes[key].append([Combat.win_chance(gs.player, gs.data, foe), Guidance.odds_unhurt(gs.player, gs.data, foe)])
			if month == 2 or month == 5 or month == 11:
				iron_levels[month + 1].append(Techniques.level(gs.player, "iron_fist"))  # QA-138
		var r: Dictionary = FirstHour.play(gs, clock, s, months, curious, hook)
		if injury_origins:
			root.get_node("EventBus").message_posted.disconnect(on_message)
			slow_days.append(slowed["days"])
			for b: Dictionary in r["breaks"]:
				if int(b["day"]) <= 365:
					b["seed"] = s
					break_rows.append(b)
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
		if FirstHour.far_qi and odds_bands:
			root.get_node("EventBus").combat_started.disconnect(on_move_start)
			root.get_node("EventBus").combat_finished.disconnect(on_move_end)
		if odds_bands:
			root.get_node("EventBus").combat_started.disconnect(on_band_start)
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
	if FirstHour.far_qi:
		var fl: Dictionary = FirstHour.far_qi_log
		print("Far qi (QA-145): moved in %d/%d seeds, median month %.0f, days on the road %.0f" % [fl["moved"], seeds, _median(fl["month"]), _median(fl["road_days"])])
	print("Road encounters (QA-118): %d/%d seeds met one; %s" % [road_seeds, seeds, str(road_seen)])
	if zero:
		print("Fights rated 0%%: %d of %d, by source: %s" % [zero_by.values().reduce(func(a: int, b: int) -> int: return a + b, 0), fights_seen["n"], str(zero_by)])
	if forced:
		print("Fights rated under %.0f%% (QA-139): %d" % [100.0 * FORCED_ODDS, forced_rows.size()])
		print("  seed  enemy  source  layer  odds  outcome  injured")
		for row: Dictionary in forced_rows:
			print("  %4d  %s  %s  QR%d  %.0f%%  %s  %s" % [row["seed"], row["id"], row["source"], row["layer"], 100.0 * float(row["odds"]), row["outcome"], "yes" if row.get("new_injury", false) else "no"])
	if odds_bands:
		_print_odds_bands(band_rows, band_foes, months, seeds)
		if FirstHour.far_qi:
			_print_move_bands(move_rows)
	if injury_origins:
		_print_injury_origins(origin_rows, slow_days, break_rows, seeds)
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
