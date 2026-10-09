extends SceneTree
## QA-060: why does "Ask for pointers" (almost) never succeed in a curious life?
## Each month, for every living NPC in the player's region who is senior to them,
## counts the reason Mentorship.check_pointers gives, and prints Elder Mo's favor.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/pointer_reasons.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")

var _reasons: Dictionary = {}
var _mo_favor: Dictionary = {6: [], 12: [], 24: []}
var _pointers_used := 0
var _best_is_mo: Dictionary = {}  # month -> seeds where Elder Mo is the highest-favor NPC (the gift policy's target)
var _gift_months := 0
var _unmastered: Dictionary = {}  # month -> [techniques known, unmastered] summed over seeds


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


## "<Name> does not know you well enough (favor 4/20)." -> "favor too low".
static func classify(reason: String) -> String:
	if reason == "":
		return "ok"
	if reason.contains("well enough"):
		return "favor too low"
	if reason.contains("recently"):
		return "cooldown"
	if reason.contains("no technique"):
		return "no technique to correct"
	if reason.contains("no stronger"):
		return "not senior"
	return "other: " + reason


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 24
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var hook := func(month: int) -> void:
		var c: CharacterData = gs.player
		for npc_id: String in gs.npcs:
			var npc: CharacterData = gs.npcs[npc_id]
			if not npc.alive or Npcs.region_of(npc, gs.data) != gs.current_region or not Mentorship.is_senior(c, npc):
				continue
			var key := classify(gs.check_pointers(npc_id))
			_reasons[key] = int(_reasons.get(key, 0)) + 1
		var best := ""
		for npc_id: String in gs.npcs:
			if gs.npcs[npc_id].alive and (best == "" or int(gs.npc_favor.get(npc_id, 0)) > int(gs.npc_favor.get(best, 0))):
				best = npc_id
		if month == 11 and best == "elder_mo":
			_best_is_mo[month] = int(_best_is_mo.get(month, 0)) + 1
		if [5, 11, 23].has(month):
			var known: Array = c.techniques.keys()
			var open := known.filter(func(t: String) -> bool: return not Techniques.is_mastered(c, gs.data, t))
			var sums: Array = _unmastered.get(month + 1, [0, 0])
			_unmastered[month + 1] = [sums[0] + known.size(), sums[1] + open.size()]
		if _mo_favor.has(month + 1):
			_mo_favor[month + 1].append(int(gs.npc_favor.get("elder_mo", 0)))
	for s in range(1, seeds + 1):
		var out := FirstHour.play(gs, clock, s, months, true, hook)
		_gift_months += out["kind_sets"].filter(func(k: Dictionary) -> bool: return k.has("gift")).size()
		_pointers_used += int(out["kind_sets"].filter(func(k: Dictionary) -> bool: return k.has("pointer")).size())
	print("senior NPC-months in the player's region, by check_pointers reason (%d seeds x %d months):" % [seeds, months])
	var keys := _reasons.keys()
	keys.sort()
	for k: String in keys:
		print("  %-26s %d" % [k, _reasons[k]])
	for m: int in _mo_favor:
		if m <= months:
			print("Elder Mo favor, median at month %d: %.0f" % [m, _median(_mo_favor[m])])
	for m: int in _unmastered:
		print("month %d: techniques known / unmastered, summed over seeds: %d / %d" % [m, _unmastered[m][0], _unmastered[m][1]])
	print("seeds where Elder Mo is the gift target at month 12: %d/%d; gift months: %d" % [int(_best_is_mo.get(11, 0)), seeds, _gift_months])
	print("months with a successful pointer: %d" % _pointers_used)
	quit()
