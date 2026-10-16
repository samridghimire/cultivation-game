extends SceneTree
## QA-041: three curious years. Runs the curious first-hour policy (tests/sim/first_hour.gd)
## for many months and prints, per 6-month block, distinct action kinds, new features first
## used, stones and realm, then flags dull blocks.
## QA-076: `--wait-for-pill=N` makes the player wait up to N days at the Foundation bottleneck, earning, to afford the pill.
## QA-096: `--trace=<seed>` runs only that seed and prints one line per month (realm, qi, breakthrough chance, stones, lives, injuries,
## log lines) plus the HUD hints and goals at the end; the default output is unchanged.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_curious_years.gd -- [seeds] [months] [--wait-for-pill=N] [--trace=<seed>]

const FirstHour := preload("res://tests/sim/first_hour.gd")
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
var _wait_for_pill := 0
var _trace_seed := 0


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
	print("Curious player, %d seeds, %d months" % [seeds, months])
	print("  seed  block  kinds  new  stones  realm")
	for s in range(1, seeds + 1):
		_seed = s
		var r: Dictionary = FirstHour.play(gs, clock, s, months, true, Callable(), false, _wait_for_pill)
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
