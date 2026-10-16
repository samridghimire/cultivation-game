extends SceneTree
## QA-064: are the early inheritances reachable? Runs the curious first-hour policy
## (tests/sim/first_hour.gd) and, each month, checks the four early Qi Refining / Foundation
## inheritances: could the player pass every non-fight trial, and what are the rated odds of the
## final fight at that moment. When all non-fight trials pass and the fight is rated Even or
## better (win chance >= 70%), the player walks to the grounds, attempts every trial and walks back.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/early_inheritances.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const EARLY: Array[String] = ["fist_saint_grave", "village_founder_well", "reed_hermit_hut", "sword_mound_traveller"]
const EVEN := 0.70


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


## The non-fight trials `c` cannot pass yet ("" when all pass, or the fight comes first).
static func blocked_trials(c: CharacterData, data: GameData, def: Dictionary) -> String:
	for stage: Dictionary in def.get("stages", []):
		if String(stage.get("test", "")) == "fight":
			continue
		var why := Inheritances.check_test(c, data, stage)
		if why != "":
			return String(stage.get("name", "?"))
	return ""


static func final_odds(c: CharacterData, data: GameData, def: Dictionary) -> float:
	var stages: Array = def.get("stages", [])
	var enemy := Inheritances.stage_enemy(data, stages[stages.size() - 1])
	return Combat.win_chance(c, data, enemy) if not enemy.is_empty() else 1.0


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 36
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var passable := {}  # id -> [first month all non-fight trials passed]
	var odds_then := {}  # id -> [rated odds that month]
	var claimed := {}  # id -> seeds that claimed
	var claim_month := {}  # id -> [month of the claim]
	var lost := {}  # id -> seeds where a rival claimed it first
	var blockers := {}  # id -> {trial name: seeds blocked there at the end}
	for id in EARLY:
		passable[id] = []
		odds_then[id] = []
		claimed[id] = []
		claim_month[id] = []
		lost[id] = []
		blockers[id] = {}
	print("Early inheritances, curious player, %d seeds, %d months" % [seeds, months])
	for s in range(1, seeds + 1):
		var seen := {}
		var hook := func(month: int) -> void:
			var c: CharacterData = gs.player
			if not c.alive:
				return
			for id in EARLY:
				var def := Inheritances.inheritance(gs.data, id)
				if Inheritances.is_claimed(id, gs.world_flags) or Inheritances.is_lost(def, clock.total_days, gs.world_flags):
					continue
				if clock.total_days < Inheritances.appears_day(def) or blockers_for(c, gs, def) != "":
					continue
				var odds := final_odds(c, gs.data, def)
				if not seen.has(id):
					seen[id] = true
					passable[id].append(month + 1)
					odds_then[id].append(odds)
				if odds >= EVEN:
					_attempt(gs, id, def)
					if Inheritances.is_claimed(id, gs.world_flags):
						claim_month[id].append(month + 1)
		var r: Dictionary = FirstHour.play(gs, clock, s, months, true, hook)
		var c: CharacterData = r["player"]
		for id in EARLY:
			var def := Inheritances.inheritance(gs.data, id)
			if Inheritances.is_claimed(id, gs.world_flags):
				claimed[id].append(s)
			elif Inheritances.is_lost(def, clock.total_days, gs.world_flags):
				lost[id].append(s)
			if not seen.has(id) and c.alive:
				var b := blockers_for(c, gs, def)
				blockers[id][b] = int(blockers[id].get(b, 0)) + 1
		gs.end_session()
	print("Per inheritance (%d seeds): seeds that could pass every non-fight trial, median month, median rated odds of the final fight then (claiming retries the non-lethal fight until won, so the odds only decide the month the policy tries), seeds that claimed it, seeds lost to the deadline" % seeds)
	for id in EARLY:
		var def := Inheritances.inheritance(gs.data, id)
		var odds: Array = odds_then[id].duplicate()
		odds.sort()
		var months_v: Array = passable[id].duplicate()
		months_v.sort()
		print("  %-22s %-24s deadline y%-2d passable %2d/%d  month %s  odds %s  claimed %d (median month %s)  lost %d" % [id, def["region"], int(def["deadline_years"]), months_v.size(), seeds,
			("%d" % months_v[months_v.size() / 2]) if not months_v.is_empty() else "-",
			("%.0f%%" % (100.0 * odds[odds.size() / 2])) if not odds.is_empty() else "-", claimed[id].size(), _median(claim_month[id]), lost[id].size()])
		if not blockers[id].is_empty():
			print("      never passable; blocking trial at the end: %s" % str(blockers[id]))
	quit(0)


static func _median(v: Array) -> String:
	if v.is_empty():
		return "-"
	v.sort()
	return "%d" % v[v.size() / 2]


static func blockers_for(c: CharacterData, gs: Node, def: Dictionary) -> String:
	return blocked_trials(c, gs.data, def)


## Walks to the grounds, attempts every trial (fights retried up to 3 times), walks back.
func _attempt(gs: Node, id: String, def: Dictionary) -> void:
	var home: String = gs.current_region
	var region := String(def["region"])
	if home != region:
		_walk(gs, region)
		if gs.current_region != region:
			_walk(gs, home)
			return
	for i in 6:
		if not gs.player.alive or Inheritances.check_attempt(gs.player, gs.data, id, gs.current_region, root.get_node("GameClock").total_days, gs.world_flags) != "":
			break
		gs.attempt_inheritance(id)
	if gs.player.alive and gs.current_region != home:
		_walk(gs, home)


## Travels hop by hop along the shortest open route (the marsh is two hops from the village).
func _walk(gs: Node, target: String) -> void:
	var prev := {gs.current_region: ""}
	var queue: Array = [gs.current_region]
	while not queue.is_empty() and not prev.has(target):
		var here: String = queue.pop_front()
		for route: Dictionary in gs.data.regions.get(here, {}).get("routes", []):
			var to := String(route.get("to", ""))
			if not prev.has(to) and Exploration.check_travel(gs.player, gs.data, here, to)["ok"]:
				prev[to] = here
				queue.append(to)
	if not prev.has(target):
		return
	var path: Array = []
	var at := target
	while at != gs.current_region:
		path.push_front(at)
		at = prev[at]
	for hop: String in path:
		if not gs.player.alive:
			return
		gs.travel(hop)
		if gs.current_region != hop:
			return
