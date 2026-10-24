extends SceneTree
## QA-041: three curious years. Runs the curious first-hour policy (tests/sim/first_hour.gd)
## for many months and prints, per 6-month block, distinct action kinds, new features first
## used, stones and realm, then flags dull blocks.
## QA-076: `--wait-for-pill=N` makes the player wait up to N days at the Foundation bottleneck, earning, to afford the pill.
## QA-096: `--trace=<seed>` runs only that seed and prints one line per month (realm, qi, breakthrough chance, stones, lives, injuries,
## log lines) plus the HUD hints and goals at the end; the default output is unchanged.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_curious_years.gd -- [seeds] [months] [--wait-for-pill=N] [--trace=<seed>]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const CombatBalance := preload("res://tests/sim/combat_balance.gd")
const BLOCK := 6
## Features the sim reports; the curious policy cannot use the ones never seen in `kind_sets`
## (crafting, profession work, secret realms, gifts, pointers, spars, lectures).
const FEATURES: Array[String] = ["mission", "deed", "talk", "commission", "breakthrough", "craft", "work", "secret_realm", "gift", "pointer", "spar", "lecture"]


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


## QA-052: every death (artifact respawn or final) with month, cause, last foe, its rated odds,
## lives left, stones held and the log lines just before it. Printed after the run.
var _deaths: Array[Dictionary] = []
var _last_fight := {}
var _prefight_odds := -1.0
var _prefight_origin := "other"


## QA-091: per-foe tally over all seeds, plus how each fight started (the log lines just before it).
var _foes := {}
var _lives_bought := {}


func _fight_origin() -> String:
	if FirstHour.fight_origin != "other":
		return FirstHour.fight_origin
	var bus: Node = root.get_node("EventBus")
	for i in range(bus.history.size() - 1, maxi(-1, bus.history.size() - 4), -1):
		if String(bus.history[i]["text"]).to_lower().contains("bounty"):
			return "bounty"
	return "other"


func _on_combat_started(enemy: Dictionary) -> void:
	var gs: Node = root.get_node("GameState")
	_prefight_origin = _fight_origin()
	_prefight_odds = Combat.win_chance(gs.player, gs.data, enemy)


func _on_combat_finished(enemy_name: String, victory: bool, _log: PackedStringArray) -> void:
	var gs: Node = root.get_node("GameState")
	var foe := {}
	for e: Dictionary in gs.data.enemies.values():
		if String(e.get("name", "")) == enemy_name:
			foe = e
			break
	# QA-055: the odds were rated before the fight (the outcome already changed the player).
	_last_fight = {"id": String(foe.get("id", enemy_name)), "odds": _prefight_odds, "won": victory}
	var t: Dictionary = _foes.get(_last_fight["id"], {"fights": 0, "wins": 0, "odds": 0.0, "deaths": 0, "mission": 0, "deed": 0, "bounty": 0, "other": 0})
	t["fights"] += 1
	t["wins"] += 1 if victory else 0
	t["odds"] += maxf(0.0, _prefight_odds)
	t[_prefight_origin] += 1
	_foes[_last_fight["id"]] = t


func _record_death(cause: String, final: bool) -> void:
	var gs: Node = root.get_node("GameState")
	var bus: Node = root.get_node("EventBus")
	var recent: Array[String] = []
	for i in range(maxi(0, bus.history.size() - 6), bus.history.size()):
		recent.append(String(bus.history[i]["text"]).left(90))
	_deaths.append({"seed": _seed, "month": root.get_node("GameClock").total_days / 30, "cause": cause.left(110), "final": final,
		"fight": _last_fight.duplicate(), "lives": gs.player.artifact_lives, "stones": gs.player.item_count("spirit_stone"),
		"region": gs.current_region, "recent": recent})
	if _last_fight.has("id") and _foes.has(_last_fight["id"]):
		_foes[_last_fight["id"]]["deaths"] += 1
	_last_fight = {}


var _seed := 0
## QA-114: the curious player's state the first month after the Foundation breakthrough, per seed.
var _fe_snaps := {}
## QA-121: the same player two months (~60 days) after the snapshot, and the month of the first snapshot.
var _fe_snaps60 := {}
var _fe_month := {}
var _wait_for_pill := 0
var _trace_seed := 0
var _arm_report := false


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])


func _run() -> void:
	var args: Array[String] = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--wait-for-pill="):
			_wait_for_pill = int(a.get_slice("=", 1))
		elif a == "--far-qi":
			FirstHour.far_qi = true  # QA-151
		elif a == "--sect-method":
			FirstHour.sect_method = true  # QA-156
		elif a == "--rogue":
			FirstHour.stay_rogue = true  # QA-158
		elif a == "--buy-qi":
			FirstHour.buy_qi = true  # QA-161
		elif a == "--body-art":
			FirstHour.body_art = true  # QA-155
		elif a == "--trial-report":
			FirstHour.trial_report = true  # QA-155
		elif a == "--arm-report":
			_arm_report = true  # QA-161
		elif a == "--defence":
			FirstHour.follow_defence = true
		elif a.begins_with("--trace="):
			_trace_seed = int(a.get_slice("=", 1))
		else:
			args.append(a)
	if _trace_seed > 0:
		_trace(args)
		return
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 36
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var blocks := months / BLOCK
	var kinds_by_block: Array = []
	var new_by_block: Array = []
	var stones_by_block: Array = []
	var first_month := {}
	var stretches: Array = []
	var died: Array[int] = []
	var runs: Array[Dictionary] = []
	for b in blocks:
		kinds_by_block.append([])
		new_by_block.append([])
		stones_by_block.append([])
	for f in FEATURES:
		first_month[f] = []
	var bus: Node = root.get_node("EventBus")
	bus.combat_finished.connect(_on_combat_finished)
	bus.combat_started.connect(_on_combat_started)
	bus.player_respawned.connect(func(_a: String, _l: int) -> void: _record_death(String(gs.pending_respawn.get("cause", "?")), false))
	bus.player_died.connect(func(cause: String) -> void: _record_death(cause, true))
	FirstHour.sect_method_log = {"day": [], "tech": []}
	print("Curious player, %d seeds, %d months" % [seeds, months])
	print("  seed  block  kinds  new  stones  realm")
	for s in range(1, seeds + 1):
		_seed = s
		var snap_hook := func(m: int) -> void:
			if gs.player.realm_index >= 2 and not _fe_snaps.has(s):
				_fe_snaps[s] = CharacterData.from_dict(gs.player.to_dict())
				_fe_month[s] = m
			elif _fe_month.has(s) and not _fe_snaps60.has(s) and m >= int(_fe_month[s]) + 2:
				_fe_snaps60[s] = CharacterData.from_dict(gs.player.to_dict())
		var r: Dictionary = FirstHour.play(gs, clock, s, months, true, snap_hook, false, _wait_for_pill)
		runs.append(r.duplicate())
		runs[-1].erase("player")
		var sets: Array = r["kind_sets"]
		if sets.size() < months:
			died.append(s)
		var seen := {}
		var last_new := -1
		var longest := 0
		var longest_start := 0
		for m in sets.size():
			var fresh := 0
			for k: String in sets[m]:
				if k != "explore" and not seen.has(k):
					seen[k] = m + 1
					fresh += 1
					if first_month.has(k):
						first_month[k].append(m + 1)
			if fresh > 0:
				last_new = m
			elif m - last_new > longest:
				longest = m - last_new
				longest_start = last_new + 1
			sets[m] = {"kinds": sets[m].size(), "new": fresh}
		stretches.append({"seed": s, "length": longest, "from": longest_start + 1, "realm": r["realms"][mini(longest_start, r["realms"].size() - 1)] if not r["realms"].is_empty() else "-", "stones": r["stones"][mini(longest_start, r["stones"].size() - 1)] if not r["stones"].is_empty() else 0})
		for b in mini(blocks, ceili(float(sets.size()) / BLOCK)):
			var ks := 0
			var nw := 0
			var n := 0
			for m in range(b * BLOCK, mini((b + 1) * BLOCK, sets.size())):
				ks += int(sets[m]["kinds"])
				nw += int(sets[m]["new"])
				n += 1
			var avg := float(ks) / maxi(1, n)
			var stones: int = r["stones"][mini((b + 1) * BLOCK, sets.size()) - 1]
			kinds_by_block[b].append(avg)
			new_by_block[b].append(nw)
			stones_by_block[b].append(stones)
			print("  %4d  %5d  %5.1f  %3d  %6d  %s" % [s, b + 1, avg, nw, stones, r["realms"][mini((b + 1) * BLOCK, sets.size()) - 1]])
		gs.end_session()
	print("Medians per %d-month block: distinct kinds / seeds with a new feature / stones" % BLOCK)
	for b in blocks:
		var with_new := 0
		for v: int in new_by_block[b]:
			if v > 0:
				with_new += 1
		var flag := ""
		if _median(kinds_by_block[b].duplicate()) <= 2.0:
			flag += " [kinds<=2]"
		if _median(new_by_block[b].duplicate()) == 0.0:
			flag += " [nothing new]"
		print("  months %2d-%2d: %.1f kinds, %d of %d seeds new feature, %.0f stones%s" % [b * BLOCK + 1, (b + 1) * BLOCK, _median(kinds_by_block[b].duplicate()), with_new, kinds_by_block[b].size(), _median(stones_by_block[b].duplicate()), flag])
	print("Seeds whose life ended before month %d: %s" % [months, str(died) if not died.is_empty() else "none"])
	var early := died.size()
	print("Guard (QA-054): at most 1 of 10 seeds may end early: %s" % ("ok" if early * 10 <= maxi(seeds, 10) else "FAILED (%d of %d)" % [early, seeds]))
	print("First month each feature was used (median over seeds that used it):")
	for f in FEATURES:
		var v: Array = first_month[f]
		print("  %-13s %s" % [f, ("month %.0f (%d of %d seeds)" % [_median(v.duplicate()), v.size(), seeds]) if not v.is_empty() else "never (policy does not use it)"])
	stretches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["length"] > b["length"])
	print("Longest 'nothing new' stretches:")
	for i in mini(3, stretches.size()):
		var st: Dictionary = stretches[i]
		print("  seed %d: %d months from month %d (%s, %d stones)" % [st["seed"], st["length"], st["from"], st["realm"], st["stones"]])
	print("Deaths (%d): seed, game month, final?, foe (rated odds), lives left, stones, region" % _deaths.size())
	for d in _deaths:
		var f: Dictionary = d["fight"]
		print("  seed %2d m%-3d %s %s (%s) lives=%d stones=%d %s" % [d["seed"], d["month"], "FINAL" if d["final"] else "respawn", f.get("id", "no fight (non-combat cause)"), "%.0f%%" % (100.0 * float(f["odds"])) if f.has("odds") and float(f["odds"]) >= 0 else "?", d["lives"], d["stones"], d["region"]])
		print("      cause: %s" % d["cause"])
		for line: String in d["recent"]:
			print("      | %s" % line)
	_print_foe_table()
	_print_lives(runs)
	_print_foundation_breakthrough(runs)
	_print_fe_gap()
	if FirstHour.follow_defence:
		_print_defence_log(seeds)
	_print_pacing_summary(runs, months)
	if _arm_report:
		_print_arm_report(runs, months)
	if FirstHour.body_art or FirstHour.trial_report:
		_print_body_art(seeds)
	if FirstHour.sect_method:
		print("Sect method (QA-156): claimed in %d/%d seeds, days %s, techniques %s" % [FirstHour.sect_method_log["day"].size(), seeds, str(FirstHour.sect_method_log["day"]), str(FirstHour.sect_method_log["tech"])])
	quit(1 if early * 10 > maxi(seeds, 10) else 0)


## QA-066: the first Foundation Establishment breakthrough (realm 1 -> 2), per seed, from the
## attempt log FirstHour.play keeps. "Stuck" is the days from the first monthly check that found
## the player at the bottleneck to the successful attempt (month-granular), -1 if never.
func _print_foundation_breakthrough(runs: Array[Dictionary]) -> void:
	print("First Foundation breakthrough (QA-066): seed, bottleneck day, attempts [day chance pill? ok?/injury], success day, stones at bottleneck")
	var stuck: Array = []
	var attempt_counts: Array = []
	var with_pill := 0
	var below_half := 0
	var total := 0
	for i in runs.size():
		var r: Dictionary = runs[i]
		var seed_attempts: Array = []
		var success_day := -1
		var stones_at := -1
		for a: Dictionary in r["breaks"]:
			if int(a["from_realm"]) != 1:
				continue
			if stones_at < 0:
				stones_at = int(a["stones"])
			seed_attempts.append("d%d %.0f%%%s %s" % [a["day"], 100.0 * float(a["chance"]), " pill" if a["pill"] else "", ("ok" if a["success"] else ("fail+injury" if a["injury"] else "fail"))])
			total += 1
			if float(a["chance"]) < 0.5:
				below_half += 1
			if a["pill"]:
				with_pill += 1
			if a["success"] and success_day < 0:
				success_day = int(a["day"])
		var bday: int = int(r["bottleneck_day"].get(1, -1))
		print("  seed %2d bottleneck d%-4d attempts %d [%s] success d%d stones %d%s" % [i + 1, bday, seed_attempts.size(), ", ".join(seed_attempts), success_day, stones_at, ("  waited %dd" % int(r["waited_days"])) if _wait_for_pill > 0 else ""])
		if bday >= 0:
			attempt_counts.append(seed_attempts.size())
			if success_day >= 0:
				stuck.append(success_day - bday)
	print("  medians: days stuck at the bottleneck %.0f (%d seeds that succeeded), attempts %.0f, share of attempts with a pill %d%% (%d of %d), attempts under 50%%: %d of %d" % [_median(stuck.duplicate()), stuck.size(), _median(attempt_counts.duplicate()), 100 * with_pill / maxi(1, total), with_pill, total, below_half, total])


## QA-156: QR9 (the Foundation bottleneck) and Foundation days, seeds at Foundation by m12/m24/m36, injuries and lives spent.
func _print_pacing_summary(runs: Array[Dictionary], months: int) -> void:
	var qr9: Array = []
	var found: Array = []
	var lives := 0
	var injuries := 0
	for r: Dictionary in runs:
		injuries += int(r.get("injuries", 0))
		if r["bottleneck_day"].has(1):
			qr9.append(int(r["bottleneck_day"][1]))
		for a: Dictionary in r["breaks"]:
			if int(a["from_realm"]) == 1 and a["success"]:
				found.append(int(a["day"]))
				break
		lives += int(r.get("recharges", 0))
	var by := []
	for m in [12, 24, 36]:
		if m <= months:
			var n := 0
			for r: Dictionary in runs:
				var md: Array = r["month_days"]
				for a: Dictionary in r["breaks"]:
					if int(a["from_realm"]) == 1 and a["success"] and md.size() >= m and int(a["day"]) <= int(md[m - 1]):
						n += 1
						break
			by.append("m%d %d/%d" % [m, n, runs.size()])
	print("Pacing (QA-156): QR9 median day %.0f (%d seeds), Foundation median day %.0f (%d seeds); Foundation by %s; artifact lives bought %d, injuries at the end %d" % [_median(qr9.duplicate()), qr9.size(), _median(found.duplicate()), found.size(), ", ".join(by), lives, injuries])


## QA-155: per seed the day the body art was learned and the Core Disciple trial odds the first month a trial was open.
func _print_body_art(seeds: int) -> void:
	print("Body art / trial (QA-155): seed, art learned day, trial first open month, odds then")
	var odds: Array = []
	var learned := 0
	for sd in range(1, seeds + 1):
		var l: Dictionary = FirstHour.body_art_log.get(sd, {"learned": -1, "odds": -1.0, "month": -1})
		print("  seed %2d art d%d trial m%d odds %.0f" % [sd, int(l["learned"]), int(l["month"]), 100.0 * float(l["odds"])])
		if int(l["learned"]) >= 0:
			learned += 1
		if float(l["odds"]) >= 0.0:
			odds.append(float(l["odds"]))
	print("  art learned in %d/%d seeds; trial opened in %d; median odds %.0f in 100" % [learned, seeds, odds.size(), 100.0 * _median(odds.duplicate())])


## QA-161: one line per arm: stones at m12/m36, qi pills bought, fights lost, artifact lives, final deaths.
func _print_arm_report(runs: Array[Dictionary], months: int) -> void:
	var s12: Array = []
	var s36: Array = []
	for r: Dictionary in runs:
		if r["stones"].size() >= 12:
			s12.append(int(r["stones"][11]))
		if r["stones"].size() >= months:
			s36.append(int(r["stones"][months - 1]))
	var lost := 0
	for t: Dictionary in _foes.values():
		lost += int(t["fights"]) - int(t["wins"])
	var finals := 0
	for d: Dictionary in _deaths:
		if d["final"]:
			finals += 1
	var lives := 0
	for r: Dictionary in runs:
		lives += int(r.get("recharges", 0))
	var ql: Dictionary = FirstHour.qi_log
	print("Arm report (QA-161): stones median m12 %.0f, m36 %.0f; qi pills bought %d for %d stones (used %d, +%d qi); fights lost %d; artifact lives bought %d; final deaths %d" % [_median(s12.duplicate()), _median(s36.duplicate()), ql["bought"], ql["stones"], ql["used"], ql["qi"], lost, lives, finals])


## QA-091: per foe over all seeds: fights, wins, real win %, mean rated %, deaths, how fights started.
func _print_foe_table() -> void:
	print("Per foe (QA-091): fights, wins, real win %, mean rated %, deaths, started by mission/deed/bounty/other")
	var ids: Array = _foes.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(_foes[a]["deaths"]) > int(_foes[b]["deaths"]) or (int(_foes[a]["deaths"]) == int(_foes[b]["deaths"]) and int(_foes[a]["fights"]) > int(_foes[b]["fights"])))
	for id: String in ids:
		var t: Dictionary = _foes[id]
		var n := maxi(1, int(t["fights"]))
		print("  %-26s %3d fights %3d wins  real %3d%%  rated %3d%%  deaths %2d  %d/%d/%d/%d" % [id, t["fights"], t["wins"], 100 * int(t["wins"]) / n, roundi(100.0 * float(t["odds"]) / n), t["deaths"], t["mission"], t["deed"], t["bounty"], t["other"]])


## QA-091: per seed, artifact lives bought and lives left at the end of the run.
func _print_lives(runs: Array[Dictionary]) -> void:
	print("Artifact lives (QA-091): seed, recharges bought, lives at the end")
	for i in runs.size():
		print("  seed %2d bought %d lives at end %s" % [i + 1, int(runs[i].get("recharges", 0)), str(runs[i].get("lives", "?"))])


## QA-096: one seed, one line per month; ends with what the HUD would tell the player.
func _trace(args: Array[String]) -> void:
	var months := int(args[1]) if args.size() > 1 else 36
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var bus: Node = root.get_node("EventBus")
	print("Trace seed %d, %d months: month realm qi/needed chance stones lives injuries region | log" % [_trace_seed, months])
	var hook := func(month: int) -> void:
		var c: CharacterData = gs.player
		var lines: Array[String] = []
		for i in range(maxi(0, bus.history.size() - 4), bus.history.size()):
			lines.append(String(bus.history[i]["text"]).left(60))
		print("  m%-3d %-28s %6.0f/%-6.0f %3.0f%% stones=%-4d lives=%d inj=%d %s | %s" % [month + 1, Cultivation.realm_label(c, gs.data), c.qi, Cultivation.qi_required(c, gs.data), 100.0 * Cultivation.breakthrough_chance(c, gs.data), c.item_count("spirit_stone"), c.artifact_lives, c.injuries.size(), gs.current_region, " / ".join(lines)])
	var r: Dictionary = FirstHour.play(gs, clock, _trace_seed, months, true, hook, false, _wait_for_pill)
	print("Breakthrough attempts: ", r["breaks"].size())
	for a: Dictionary in r["breaks"]:
		print("  d%d realm %d %.0f%% pill=%s stones=%d success=%s injury=%s" % [a["day"], a["from_realm"], 100.0 * float(a["chance"]), str(a["pill"]), a["stones"], str(a["success"]), str(a["injury"])])
	var c: CharacterData = gs.player
	print("Hints now:")
	for h: String in Guidance.hints(c, gs.data, 1.0, 8, {}, gs.world_flags, gs.current_region, clock.total_days):
		print("  - ", h)
	print("Goals now:")
	for g: String in Guidance.goals(c, gs.data, gs.world_flags):
		print("  - ", g)
	gs.end_session()
	quit(0)


func _tech_line(c: CharacterData) -> String:
	var parts: Array[String] = []
	for id: String in c.techniques:
		parts.append("%s L%d" % [id, int(c.techniques[id]["level"])])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _gear_line(c: CharacterData, data: GameData) -> String:
	var parts: Array[String] = []
	for slot: String in c.equipment:
		parts.append("%s=%s" % [slot, c.equipment[slot]])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _stat_line(c: CharacterData, data: GameData) -> String:
	var st := Combat.stats(c, data)
	return "hp %d atk %d def %d spd %d" % [st["max_hp"], st["attack"], st["defense"], st["speed"]]


## QA-114: why the curious player is weak at Foundation entry. Per seed the state after the breakthrough,
## the same for combat_balance's typical player at Foundation stage 0, rated odds of both against the
## roadside rogue and the three easiest Foundation foes, then the typical player with one thing swapped
## in from the curious one at a time (which gap costs the most odds).
func _print_fe_gap() -> void:
	var gs: Node = root.get_node("GameState")
	var data: GameData = gs.data
	var typical := CombatBalance.typical_player(data, 2, 0)
	var foes: Array[Dictionary] = []
	for e: Dictionary in data.enemies.values():
		if String(e.get("realm", "")) == "foundation_establishment":
			foes.append(e)
	var target: Dictionary = data.enemies["roadside_rogue_cultivator"]
	foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Combat.win_chance(typical, data, a) > Combat.win_chance(typical, data, b))
	var easy: Array[Dictionary] = []
	for e in foes:
		if e["id"] != "roadside_rogue_cultivator" and easy.size() < 2:
			easy.append(e)
	var rated: Array[Dictionary] = [target]
	rated.append_array(easy)
	print("Foundation entry gap (QA-114): curious player right after the breakthrough vs the typical player (Foundation, stage 0)")
	print("  typical: %s | techniques %s | gear %s" % [_stat_line(typical, data), _tech_line(typical), _gear_line(typical, data)])
	var names: Array[String] = []
	for e in rated:
		names.append("%s %.0f%%" % [e["id"], 100.0 * Combat.win_chance(typical, data, e)])
	print("  typical odds: %s" % ", ".join(names))
	var sums := {"all": 0.0, "typical_techs": 0.0, "typical_gear": 0.0, "typical_attrs": 0.0, "typical_all": 0.0}
	var n := 0
	var n60 := 0
	var half60 := 0
	var rogue60 := 0
	for s: int in _fe_snaps:
		var c: CharacterData = _fe_snaps[s]
		var odds: Array[String] = []
		for e in rated:
			odds.append("%.0f%%" % (100.0 * Combat.win_chance(c, data, e)))
		print("  seed %2d at entry stage %d: %s | techniques %s | gear %s | rated %s" % [s, c.stage, _stat_line(c, data), _tech_line(c), _gear_line(c, data), " / ".join(odds)])
		if _fe_snaps60.has(s):
			var c60: CharacterData = _fe_snaps60[s]
			var odds60: Array[String] = []
			var all_half := true
			for e in rated:
				var w := Combat.win_chance(c60, data, e)
				odds60.append("%.0f%%" % (100.0 * w))
				if w < 0.5:
					all_half = false
			n60 += 1
			if all_half:
				half60 += 1
			if Combat.win_chance(c60, data, target) >= 0.5:
				rogue60 += 1
			print("  seed %2d +60 days stage %d: %s | techniques %s | gear %s | rated %s" % [s, c60.stage, _stat_line(c60, data), _tech_line(c60), _gear_line(c60, data), " / ".join(odds60)])
		else:
			print("  seed %2d +60 days: run ended before the snapshot" % s)
		var variants := {"typical_techs": ["techniques"], "typical_gear": ["equipment"], "typical_attrs": ["attributes"], "typical_all": ["techniques", "equipment", "attributes"]}
		sums["all"] += Combat.win_chance(c, data, target)
		for key: String in variants:
			var v := CharacterData.from_dict(c.to_dict())
			v.stage = 0
			for field: String in variants[key]:
				v.set(field, typical.get(field).duplicate(true))
			if key == "typical_all":
				v.injuries.clear()
			sums[key] += Combat.win_chance(v, data, target)
		n += 1
		if n == 1:
			print("    HUD hints for seed %d at that moment:" % s)
			for h: String in Guidance.hints(c, data, 1.0, 8, {}, {}, "qingshi_village", 0):
				print("      - ", h)
	if n == 0:
		print("  no seed reached Foundation")
		return
	print("  at +60 days (%d seeds with a snapshot): rated >= 50%% against all three foes in %d, against the roadside rogue in %d" % [n60, half60, rogue60])
	_print_fe_levers(data, typical, rated)
	print("  mean rated odds vs roadside_rogue_cultivator over %d seeds: curious %.0f%%; with the typical player's techniques %.0f%%, gear %.0f%%, attributes %.0f%%, all three (injuries cleared) %.0f%%" % [n, 100.0 * sums["all"] / n, 100.0 * sums["typical_techs"] / n, 100.0 * sums["typical_gear"] / n, 100.0 * sums["typical_attrs"] / n, 100.0 * sums["typical_all"] / n])


## QA-125: at +60 days, the curious player changed in ONE way at a time (on a copy): injuries cleared,
## the typical player's techniques / gear / attributes, Stone Skin Tempering at level 1. Rated odds against
## the roadside rogue and the easiest Foundation foe, one row per seed, medians per column.
func _print_fe_levers(data: GameData, typical: CharacterData, rated: Array[Dictionary]) -> void:
	var cols := ["base", "a_healed", "b_techs", "c_gear", "d_attrs", "e_stone_skin"]
	for target: Dictionary in [rated[0], rated[1]]:
		print("  QA-125 levers at +60 days vs %s (rated %%): %s" % [target["id"], " | ".join(cols)])
		var per_col := {}
		for k: String in cols:
			per_col[k] = []
		for s: int in _fe_snaps60:
			var row: Array[String] = []
			for k: String in cols:
				var v := CharacterData.from_dict((_fe_snaps60[s] as CharacterData).to_dict())
				match k:
					"a_healed":
						v.injuries.clear()
					"b_techs":
						v.techniques = typical.techniques.duplicate(true)
					"c_gear":
						v.equipment = typical.equipment.duplicate(true)
					"d_attrs":
						v.attributes = typical.attributes.duplicate(true)
					"e_stone_skin":
						v.techniques["stone_skin"] = {"level": 1, "xp": 0.0}
				var w := 100.0 * Combat.win_chance(v, data, target)
				per_col[k].append(w)
				row.append("%3.0f" % w)
			print("    seed %2d: %s" % [s, " | ".join(row)])
		var meds: Array[String] = []
		for k: String in cols:
			meds.append("%3.0f" % _median(per_col[k]))
		print("    median : %s" % " | ".join(meds))


## QA-116 (--defence): per seed, what following GUIDE-065's hint cost and bought.
func _print_defence_log(seeds: int) -> void:
	var trips := 0
	var armored := 0
	var armed := 0
	var hint_seeds := 0
	print("Defence hint followed (QA-116): seed, trips to another region, armor bought, body manual bought, injuries healed")
	for s in range(1, seeds + 1):
		if not FirstHour.defence_log.has(s):
			continue
		var l: Dictionary = FirstHour.defence_log[s]
		hint_seeds += 1
		trips += int(l["trips"])
		armored += 1 if int(l["armor"]) > 0 else 0
		armed += 1 if int(l["manual"]) > 0 else 0
		print("  seed %2d: trips %d, armor %d, manual %d, healed %d" % [s, l["trips"], l["armor"], l["manual"], l["healed"]])
	print("  %d of %d seeds heard the hint; %d bought armor, %d learned a body art, %d trips away from the home region" % [hint_seeds, seeds, armored, armed, trips])
