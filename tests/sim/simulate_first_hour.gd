extends SceneTree
## First-hour sim (QA-016): scripted newcomers in Qingshi Village (tests/sim/first_hour.gd).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_first_hour.gd -- [seeds] [months]  [--curious] [--trace] [--zero] [--forced] [--injury-origins] [--odds-bands] [--qi-pill-cap=N] [--deaths] [--recharge] [--hint-missions] [--rating-check] [--firsts]

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


## QA-153: per rated-odds band the fights, mean rating and actual win share; then 40 vs 2000 samples (seed 7) on up to 40 matchups.
func _print_rating_check(rows: Array, data: GameData) -> void:
	var edges := [0.4, 0.7, 0.85, 0.95]
	var labels := ["<40", "40-70", "70-85", "85-95", ">=95"]
	print("Rated odds vs outcome (QA-153), %d non-spar fights:" % rows.size())
	print("  band  fights  mean rating  actual win share  gap (points)  mean injuries")
	for b in range(5):
		var n := 0
		var rated := 0.0
		var wins := 0
		var hurt := 0.0
		for r: Dictionary in rows:
			var o: float = r["odds"]
			var band := 0
			while band < 4 and o >= edges[band]:
				band += 1
			if band != b:
				continue
			n += 1
			rated += o
			wins += 1 if r["won"] else 0
			hurt += float(r["injuries"])
		if n == 0:
			print("  %s  0" % labels[b])
		else:
			print("  %s  %d  %.1f%%  %.1f%%  %+.1f  %.1f" % [labels[b], n, 100.0 * rated / n, 100.0 * wins / n, 100.0 * (float(wins) / n - rated / n), hurt / n])
	var picks: Array = []
	var step := maxi(1, rows.size() / 40)
	for i in range(0, rows.size(), step):
		picks.append(rows[i])
		if picks.size() >= 40:
			break
	var errs: Array = []
	var worst: Array = []
	for r: Dictionary in picks:
		var c := CharacterData.from_dict(r["player"])
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var wins := 0
		for i in 2000:
			if Combat.resolve(c, data, r["enemy"], rng)["victory"]:
				wins += 1
		var truth := wins / 2000.0
		errs.append(absf(float(r["odds"]) - truth))
		worst.append([absf(float(r["odds"]) - truth), String(r["enemy"].get("id", "?")), float(r["odds"]), truth])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var mean_err := 0.0
	for e: float in errs:
		mean_err += e
	print("Matchups checked: %d. Mean |rated(40) - 2000 samples|: %.1f points" % [picks.size(), 100.0 * mean_err / maxf(1.0, picks.size())])
	print("Worst 5: foe  rated(40)  2000 samples")
	for i in range(mini(5, worst.size())):
		print("  %s  %.0f%%  %.0f%%" % [worst[i][1], 100.0 * worst[i][2], 100.0 * worst[i][3]])


## QA-152: per seed lives spent and final-death day; per lethal loss the foe, source and rated odds at its start.
func _print_deaths(rows: Array, lethal: Array, seeds: int) -> void:
	print("Deaths (QA-152): seed  lives spent  final death day")
	var final := 0
	var spent: Array = []
	for row: Dictionary in rows:
		print("  %4d  %d  %s" % [row["seed"], row["spent"], str(row["final"]) if row["final"] >= 0 else "-"])
		spent.append(row["spent"])
		final += 1 if row["final"] >= 0 else 0
	print("Seeds with a final death: %d/%d; median lives spent %.0f" % [final, seeds, _median(spent)])
	var blank: Array = rows.map(func(r: Dictionary) -> int: return int(r.get("no_hint", 0)))
	print("Months the mission hint named nothing (QA-154), per seed median %.0f, total %d" % [_median(blank), blank.reduce(func(a: int, b: int) -> int: return a + b, 0)])
	var by_source := {}
	var by_foe := {}
	var odds: Array = []
	print("Lethal losses: seed  day  foe  source  rated odds  final")
	for l: Dictionary in lethal:
		print("  %4d  %3d  %s  %s  %.0f%%  %s" % [l["seed"], l["day"], l["foe"], l["source"], 100.0 * float(l["odds"]), "yes" if l["final"] else "no"])
		by_source[l["source"]] = int(by_source.get(l["source"], 0)) + 1
		by_foe[l["foe"]] = int(by_foe.get(l["foe"], 0)) + 1
		odds.append(l["odds"])
	print("Lethal losses: %d; by source %s; by foe %s; median rated odds %s" % [lethal.size(), str(by_source), str(by_foe), "%.0f%%" % (100.0 * _median(odds)) if not odds.is_empty() else "-"])


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
	if args.has("--firsts"):
		_run_firsts(args)
		return
	if args.has("--friends"):
		_run_friends(args)
		return
	var curious := args.has("--curious")
	FirstHour.hints_policy = args.has("--hints")  # SIM-010: the player who reads the Next-steps lines (not --curious)
	var zero := args.has("--zero")  # QA-126: count fights rated 0%, by what started them
	var forced := args.has("--forced")  # QA-139: tally every fight rated under 20%, by source, with its outcome
	var long_hints := args.has("--long-hints")  # QA-143: tally hint lines longer than the HUD cap
	var odds_bands := args.has("--odds-bands")  # QA-147: fights by month and rated-odds band
	var move_rows: Array = []
	var deaths := args.has("--deaths")  # QA-152
	var rating_check := args.has("--rating-check")  # QA-153: rated odds vs actual wins, and 40 vs 2000 samples
	var rating_rows: Array = []  # {odds, hp_frac, won, player, enemy}
	var death_rows: Array = []
	var lethal_rows: Array = []
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
	FirstHour.qi_trips = 0  # QA-164
	FirstHour.qi_buys = []  # QA-234
	FirstHour.qi_trip_log = []
	FirstHour.qi_hint_far = {}
	FirstHour.spend_contribution = curious and args.has("--spend-contribution")  # QA-148
	FirstHour.qi_pill_cap = -1  # QA-150
	FirstHour.contribution_log = {"pill_days": [], "pill": 0, "body": 0, "qi_items": 0, "qi_cost": 0, "qi_used": 0, "qi": 0}
	FirstHour.far_qi = args.has("--far-qi")  # QA-145
	FirstHour.stay_rogue = args.has("--rogue")  # QA-158
	FirstHour.start_region = ""  # SIM-012
	FirstHour.join_sect_id = ""
	FirstHour.recharge_first = args.has("--recharge")  # QA-152
	FirstHour.hint_missions = args.has("--hint-missions")
	FirstHour.sect_method = curious and args.has("--sect-method")  # QA-156
	FirstHour.sect_method_log = {"day": [], "tech": []}
	FirstHour.far_qi_log = {"moved": 0, "month": [], "road_days": []}
	FirstHour.spar_hint = curious and not args.has("--no-spar-hint")  # QA-138
	FirstHour.spar_log = {"bouts": 0, "refused": []}
	FirstHour.chat_teacher = curious and args.has("--chat-teacher")  # QA-220
	var teacher_runs: Array = []
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
		elif FirstHour.parse_start_arg(a):
			pass
		elif a.begins_with("--qi-pill-cap="):
			FirstHour.qi_pill_cap = int(a.substr(14))  # QA-150
		elif a != "--curious" and a != "--trace" and a != "--zero" and a != "--forced" and a != "--no-trial" and a != "--no-heal" and a != "--no-spar-hint" and a != "--chat-teacher" and a != "--blind-missions" and a != "--one-mission" and a != "--long-hints" and a != "--buy-qi" and a != "--spend-contribution" and a != "--no-armor" and a != "--far-qi" and a != "--injury-origins" and a != "--odds-bands" and a != "--deaths" and a != "--recharge" and a != "--hint-missions" and a != "--sect-method" and a != "--rogue" and a != "--rating-check":
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
		var on_rating_start := func(enemy: Dictionary) -> void:
			if enemy.get("spar", false):
				rating_rows.append({})
				return
			rating_rows.append({"odds": Combat.win_chance(gs.player, gs.data, enemy), "injuries": gs.player.injuries.size(), "won": false, "player": gs.player.to_dict(), "enemy": enemy.duplicate(true)})
		var on_rating_end := func(_n: String, victory: bool, _l: PackedStringArray) -> void:
			if not rating_rows.is_empty() and not rating_rows[rating_rows.size() - 1].is_empty():
				rating_rows[rating_rows.size() - 1]["won"] = victory
		var seed_lethal: Array = []
		var on_death_start := func(enemy: Dictionary) -> void:
			if enemy.get("spar", false):
				seed_lethal.append({})
				return
			var source := FirstHour.fight_origin
			if source == "other":
				for frame: Dictionary in get_stack():
					var fn := String(frame["function"])
					if fn not in ["<anonymous lambda>", "fight_enemy", "fight", "_start_combat", "start_combat"]:
						source = fn
						break
			seed_lethal.append({"seed": s, "day": clock.total_days, "foe": String(enemy.get("id", enemy.get("name", "?"))), "source": source, "odds": Combat.win_chance(gs.player, gs.data, enemy), "final": false})
		var on_respawn := func(_anchor: String, _lives: int) -> void:
			if not seed_lethal.is_empty() and not seed_lethal[seed_lethal.size() - 1].is_empty():
				lethal_rows.append(seed_lethal[seed_lethal.size() - 1])
		if deaths:
			root.get_node("EventBus").combat_started.connect(on_death_start)
			root.get_node("EventBus").player_respawned.connect(on_respawn)
		if FirstHour.far_qi and odds_bands:
			root.get_node("EventBus").combat_started.connect(on_move_start)
			root.get_node("EventBus").combat_finished.connect(on_move_end)
		if rating_check:
			root.get_node("EventBus").combat_started.connect(on_rating_start)
			root.get_node("EventBus").combat_finished.connect(on_rating_end)
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
		teacher_runs.append({"teacher": r.get("teacher", {}).duplicate()})
		if injury_origins:
			root.get_node("EventBus").message_posted.disconnect(on_message)
			slow_days.append(slowed["days"])
			for b: Dictionary in r["breaks"]:
				if int(b["day"]) <= 365:
					b["seed"] = s
					break_rows.append(b)
		if deaths:
			root.get_node("EventBus").combat_started.disconnect(on_death_start)
			root.get_node("EventBus").player_respawned.disconnect(on_respawn)
			var final_day := -1
			if not gs.player.alive:
				final_day = clock.total_days
				if not seed_lethal.is_empty() and not seed_lethal[seed_lethal.size() - 1].is_empty():
					var last: Dictionary = seed_lethal[seed_lethal.size() - 1]
					last["final"] = true
					lethal_rows.append(last)
			death_rows.append({"seed": s, "spent": LifeStats.get_stat(gs.player, "respawns"), "final": final_day, "no_hint": int(r.get("no_hint_months", 0))})
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
		if rating_check:
			root.get_node("EventBus").combat_started.disconnect(on_rating_start)
			root.get_node("EventBus").combat_finished.disconnect(on_rating_end)
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
	if FirstHour.chat_teacher:
		print("Chat teacher (QA-220): %s" % FirstHour.teacher_summary(teacher_runs))
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
	if FirstHour.sect_method:
		print("Sect method (QA-156): claimed in %d/%d seeds, days %s, techniques %s" % [FirstHour.sect_method_log["day"].size(), seeds, str(FirstHour.sect_method_log["day"]), str(FirstHour.sect_method_log["tech"])])
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
	if deaths:
		_print_deaths(death_rows, lethal_rows, seeds)
	if rating_check:
		_print_rating_check(rating_rows.filter(func(r: Dictionary) -> bool: return not r.is_empty()), root.get_node("GameState").data)
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


const FIRSTS: Array[String] = ["talk to Elder Mo", "first chore paid", "first fight won", "first technique", "first Acquaintance", "first Friend", "first stage up", "sect joined", "first lecture", "first congratulation", "first shared meditation", "first full season set", "first season task", "first trip home", "first practice level", "first spar"]
const DEAD_DAYS := 14


## GUIDE-296: whether any single task of this season's set is complete.
func _any_season_task_done(gs: Node, c: CharacterData) -> bool:
	var today: int = gs.get_node("/root/GameClock").total_days
	for row: Dictionary in SeasonTasks.list(c, gs.data, today):
		if bool(row["done"]):
			return true
	return bool(c.season_tasks.get("done", false)) or not c.seasons_completed.is_empty()


## SIM-040: whether any known technique has been practised past its first level.
func _practice_level_up(c: CharacterData) -> bool:
	for id: String in c.techniques:
		var v: Variant = c.techniques[id]
		if v is Dictionary and int((v as Dictionary).get("level", 1)) > 1:
			return true
	return false


## SIM-037: which of the FIRSTS hold now (name -> true).
func _firsts_now(gs: Node, c: CharacterData, start_stage: int, flags: Dictionary) -> Dictionary:
	var best_tier := -1
	for id: String in gs.npc_favor:
		best_tier = maxi(best_tier, Folk.tier_index(gs.data, int(gs.npc_favor[id])))
	var shared := false
	for k: String in gs.world_flags:
		if k.begins_with("friend_med_"):
			shared = true
	return {
		FIRSTS[0]: gs.npc_favor.get("elder_mo", 0) > 0 or bool(gs.world_flags.get(Guidance.ELDER_MO_FLAG, false)),
		FIRSTS[1]: LifeStats.get_stat(c, "deeds_done") >= 1,
		FIRSTS[2]: LifeStats.get_stat(c, "fights_won") >= 1,
		FIRSTS[3]: not c.techniques.is_empty(),
		FIRSTS[4]: best_tier >= 0,
		FIRSTS[5]: best_tier >= 1,
		FIRSTS[6]: c.realm_index * 100 + c.stage > start_stage,
		FIRSTS[7]: not c.is_rogue(),
		FIRSTS[8]: LifeStats.get_stat(c, "lectures_attended") >= 1,
		FIRSTS[9]: bool(flags.get("congrat", false)),
		FIRSTS[10]: shared,
		FIRSTS[11]: bool(flags.get("season", false)),
		FIRSTS[12]: _any_season_task_done(gs, c),
		FIRSTS[13]: int(FirstHour.home_trips["first"]) >= 0,
		FIRSTS[14]: _practice_level_up(c),
		FIRSTS[15]: Guidance._has_sparred(c),
	}


## SIM-037: --firsts [seeds] [months]: the day of each first per seed (hints policy, Qingshi start), then dead stretches.
## GUIDE-294: --friends [seeds] [months]: per seed the day of the first congratulation and the number of shared meditations (hints policy).
func _run_friends(args: Array) -> void:
	var nums: Array[int] = []
	for a in args:
		if not a.begins_with("--"):
			nums.append(int(a))
	var seeds := nums[0] if nums.size() > 0 else 6
	var months := nums[1] if nums.size() > 1 else 12
	FirstHour.hints_policy = true
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var meditating := 0
	for s in range(1, seeds + 1):
		FirstHour.friend_tally = {"first_congrat": -1, "meds": 0}
		FirstHour.play(gs, clock, s, months, false)
		var t: Dictionary = FirstHour.friend_tally
		print("seed %d: first congratulation day %s, shared meditations %d" % [s, str(t["first_congrat"]) if int(t["first_congrat"]) >= 0 else "never", int(t["meds"])])
		if int(t["meds"]) > 0:
			meditating += 1
	print("seeds that meditated beside a friend: %d/%d" % [meditating, seeds])
	quit()


func _run_firsts(args: Array) -> void:
	var nums: Array[int] = []
	for a in args:
		if not a.begins_with("--"):
			nums.append(int(a))
	var seeds := nums[0] if nums.size() > 0 else 6
	var months := nums[1] if nums.size() > 1 else 6
	FirstHour.hints_policy = true
	FirstHour.start_region = ""
	FirstHour.sect_report = true
	FirstHour.record_weeks = args.has("--firsts-trace")  # GUIDE-296: print each week's top lines and action (seed 1 only)
	FirstHour.hint_rank = args.has("--hint-rank")  # GUIDE-307
	FirstHour.weekly_extras = true  # GUIDE-295: a player who reads the style / lecture line acts on it in a free part of the week
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var bus: Node = root.get_node("EventBus")
	var trace_favor := args.has("--firsts-trace")
	var table: Dictionary = {}  # first -> [day per seed or -1]
	for f in FIRSTS:
		table[f] = []
	var stretch_rows: Array = []  # {seed, start, end, kinds}
	var sorted_all: Array = []
	for s in range(1, seeds + 1):
		var st := {"day0": -1, "start_stage": -1, "found": {}, "events": [0], "last": {}, "acts": []}
		var flags := {}
		FirstHour.home_trips = {"first": -1, "count": 0}
		var on_congrat := func(_id: String, _n: String, _t: String) -> void: flags["congrat"] = true
		var on_season := func(_s: String, _r: String) -> void: flags["season"] = true
		bus.friend_congratulated.connect(on_congrat)
		bus.season_tasks_done.connect(on_season)
		var on_days := func(n: int) -> void:
			var c: CharacterData = gs.player
			if c == null:
				return
			if int(st["day0"]) < 0:
				st["day0"] = clock.total_days - n
				st["start_stage"] = c.realm_index * 100 + c.stage
			var rel: int = clock.total_days - int(st["day0"])
			st["acts"].append([rel - n, rel, FirstHour._activity_of(get_stack())])
			var now := _firsts_now(gs, c, int(st["start_stage"]), flags)
			var new_event := false
			if trace_favor:
				# FOLK-057: favor with every named NPC the day the sect is joined and on day 120, plus the make-a-friend line then.
				for snap: Array in [[FIRSTS[7], "join"], ["", "day120"]]:
					var key: String = snap[1]
					var due: bool = (now[FIRSTS[7]] and not st["found"].has(FIRSTS[7])) if key == "join" else (rel >= 120 and not st.has("snap_120"))
					if due:
						if key == "day120":
							st["snap_120"] = true
						var fav := {}
						for nid: String in gs.npc_favor:
							if int(gs.npc_favor[nid]) > 0:
								fav[nid] = int(gs.npc_favor[nid])
						print("favor seed %d %s day %d in %s: %s | hint: %s" % [s, key, rel, gs.current_region, str(fav), Guidance.make_friend_hint(c, gs.data, gs.npcs, gs.world_flags, gs.current_region, clock.total_days, gs.npc_favor)])
			if trace_favor:
				# SIM-045: the friend with the highest favor at days 120/180/240/300, with the meditation block and the hint.
				for mark: int in [120, 180, 240, 300]:
					if rel >= mark and not st.has("med_%d" % mark):
						st["med_%d" % mark] = true
						var best_id := ""
						for nid: String in gs.npc_favor:
							if gs.npcs.has(nid) and (best_id == "" or int(gs.npc_favor[nid]) > int(gs.npc_favor[best_id])):
								best_id = nid
						if best_id != "":
							var bn: CharacterData = gs.npcs[best_id]
							var hint: String = Guidance.friend_meditation_hint(c, gs.data, gs.npcs, gs.npc_favor, gs.world_flags, gs.current_region, clock.total_days)
							print("meditation seed %d day %d: %s in %s realm %d favor %d block '%s' | player in %s | hint: %s" % [s, rel, best_id, Npcs.region_of(bn, gs.data), bn.realm_index, int(gs.npc_favor[best_id]), Folk.meditation_block(c, gs.data, bn, int(gs.npc_favor[best_id]), gs.world_flags, Npcs.region_of(bn, gs.data), clock.total_days), gs.current_region, hint])
			for f: String in now:
				if now[f] and not st["found"].has(f):
					st["found"][f] = rel
					new_event = true
			var stage_now: int = c.realm_index * 100 + c.stage
			if stage_now > int(st["last"].get("stage", st["start_stage"])):
				new_event = true
			st["last"]["stage"] = stage_now
			if new_event:
				st["events"].append(rel)
		gs.get_node("/root/GameClock").days_advanced.connect(on_days)
		var out: Dictionary = FirstHour.play(gs, clock, s, months, false)
		gs.get_node("/root/GameClock").days_advanced.disconnect(on_days)
		if FirstHour.record_weeks:
			for w: Dictionary in FirstHour.week_trace.slice(0, 60):
				print("day %3d | %-10s | %s || %s" % [w["day"], w["acted"], str(w["line"]).substr(0, 40), " | ".join(w["top"]).substr(0, 260)])
		bus.friend_congratulated.disconnect(on_congrat)
		bus.season_tasks_done.disconnect(on_season)
		var end_day: int = clock.total_days - int(st["day0"])
		var events: Array = st["events"]
		events.append(end_day)
		for i in range(1, events.size()):
			var a: int = events[i - 1]
			var b: int = events[i]
			if b - a >= DEAD_DAYS:
				var kinds := {}
				for act: Array in st["acts"]:
					if int(act[1]) > a and int(act[0]) < b:
						kinds[act[2]] = int(kinds.get(act[2], 0)) + int(mini(int(act[1]), b) - maxi(int(act[0]), a))
				var ranked: Array = kinds.keys()
				ranked.sort_custom(func(x: String, y: String) -> bool: return kinds[x] > kinds[y])
				var top: Array = []
				for k in ranked.slice(0, 3):
					top.append("%s %dd" % [k, kinds[k]])
				stretch_rows.append({"seed": s, "start": a, "end": b, "len": b - a, "top": ", ".join(top)})
		for f in FIRSTS:
			table[f].append(int(st["found"].get(f, -1)))
		gs.end_session()
	var lines: Array[String] = []
	lines.append("# SIM-037: the first season as a list of firsts")
	lines.append("")
	lines.append("Hints policy, Qingshi start, %d seeds, %d months. Days are counted from day 0; `never` means the sim did not reach it." % [seeds, months])
	lines.append("")
	var head := "| first |"
	var rule := "|---|"
	for s in range(1, seeds + 1):
		head += " seed %d |" % s
		rule += "---|"
	lines.append(head + " median |")
	lines.append(rule + "---|")
	for f in FIRSTS:
		var row := "| %s |" % f
		var reached: Array = []
		for d: int in table[f]:
			row += " %s |" % (str(d) if d >= 0 else "never")
			if d >= 0:
				reached.append(d)
		var med := "never" if reached.size() * 2 < seeds else "%.0f" % _median(reached.duplicate())
		lines.append(row + " %s |" % med)
	lines.append("")
	lines.append("## Dead stretches (%d+ days with no first and no stage change)" % DEAD_DAYS)
	lines.append("")
	stretch_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["len"] > b["len"])
	lines.append("| seed | days | length | top action kinds |")
	lines.append("|---|---|---|---|")
	for r: Dictionary in stretch_rows:
		lines.append("| %d | %d-%d | %d | %s |" % [r["seed"], r["start"], r["end"], r["len"], r["top"]])
	if stretch_rows.is_empty():
		lines.append("| - | - | - | none |")
	lines.append("")
	lines.append("%s" % "\n".join(_firsts_summary(stretch_rows, seeds)))
	if FirstHour.hint_rank:
		lines.append("")
		lines.append("| line | days shown | rank 1 | rank 2 | rank 3+ | rank 1-2 |")
		lines.append("|---|---|---|---|---|---|")
		for prefix: String in FirstHour.HINT_RANK_PREFIXES:
			var row: Array = FirstHour.hint_rank_log.get(prefix, [0, 0, 0, 0])
			lines.append("| %s | %d | %d | %d | %d | %d%% |" % [prefix, row[0], row[1], row[2], row[3], 100 * (int(row[1]) + int(row[2])) / maxi(1, int(row[0]))])
	var text := "\n".join(lines) + "\n"
	print(text)
	var f := FileAccess.open("res://docs/specs/SIM-037-result.md", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
	quit()


## Names the two longest median dead stretches: stretches are grouped by (rounded start day / 30) bucket across seeds.
func _firsts_summary(rows: Array, seeds: int) -> Array[String]:
	var buckets := {}
	for r: Dictionary in rows:
		var key: int = int(r["start"]) / 30
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(r)
	var ranked: Array = buckets.keys()
	ranked.sort_custom(func(a: int, b: int) -> bool:
		var la: Array = buckets[a].map(func(r: Dictionary) -> int: return r["len"])
		var lb: Array = buckets[b].map(func(r: Dictionary) -> int: return r["len"])
		return _median(la.duplicate()) * la.size() > _median(lb.duplicate()) * lb.size())
	var out: Array[String] = []
	out.append("Summary: the two stretches that recur most across %d seeds (by median length, seeds hit):" % seeds)
	for k in ranked.slice(0, 2):
		var group: Array = buckets[k]
		var lens: Array = group.map(func(r: Dictionary) -> int: return r["len"])
		var acts := {}
		for r: Dictionary in group:
			acts[r["top"]] = true
		out.append("- starting around day %d-%d: median %.0f days in %d seeds; the sim was doing: %s." % [k * 30, k * 30 + 29, _median(lens.duplicate()), group.size(), " / ".join(acts.keys().slice(0, 2))])
	return out
