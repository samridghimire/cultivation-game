extends SceneTree
## FOLK-051: do named Qingshi friends rise beside the player? A player who lends a hand to every named Qingshi NPC
## weekly (so favor reaches folk_news.min_favor) plays 730 days per seed. Prints each friend's realm on days 365 and
## 730, how many own-news entries were queued and how many were congratulated. "begins QR" = a friend left Mortal.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/own_news.gd -- [seeds] [days]


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _realm_of(gs: Node, id: String) -> String:
	var c: CharacterData = gs.npcs.get(id)
	if c == null:
		return "?"
	if not c.alive:
		return "dead"
	return String(gs.data.realms[c.realm_index].id)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 6
	var days := int(args[1]) if args.size() > 1 else 730
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var risen_seeds := 0
	print("Friends beside you (lend a hand weekly, seeds 1-%d, %d days)" % [seeds, days])
	for s in range(1, seeds + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var c := CharacterFactory.create("Sim", gs.data, rng)
		gs.start_session(c)
		gs.current_region = gs.data.start_region
		var friends: Array[String] = []
		for id: String in gs.data.npcs:
			if String(gs.data.npcs[id].get("region", "")) == gs.data.start_region:
				friends.append(id)
		var start: int = clock.total_days
		var queued := 0
		var congratulated := 0
		var seen: Dictionary = {}
		var snap: Dictionary = {}
		var begun := false
		while clock.total_days - start < days:
			for id in friends:
				if gs.npcs.has(id) and gs.npcs[id].alive:
					gs.lend_a_hand(id)
			for id: String in c.friend_news.keys():
				var key := "%s@%d" % [id, int(c.friend_news[id].get("day", 0))]
				if not seen.has(key):
					seen[key] = true
					queued += 1
				if gs.can_congratulate(id):
					gs.congratulate(id)
					congratulated += 1
			gs._pass_time(7)
			var d: int = clock.total_days - start
			if not snap.has(365) and d >= 365:
				snap[365] = _row(gs, friends)
		snap[730] = _row(gs, friends)
		for id in friends:
			if gs.npcs.has(id) and gs.npcs[id].alive and ["xiao_ling", "hunter_ma", "fisher_pei"].has(id) and gs.npcs[id].realm_index >= 1:
				begun = true
		if begun:
			risen_seeds += 1
		print("  seed %d: queued %d, congratulated %d, mortal friend risen: %s" % [s, queued, congratulated, str(begun)])
		print("    day 365: %s" % snap.get(365, "-"))
		print("    day 730: %s" % snap[730])
		gs.end_session()
	print("Seeds where a Qingshi friend began Qi Refining: %d/%d" % [risen_seeds, seeds])
	quit(0)


func _row(gs: Node, friends: Array[String]) -> String:
	var parts: PackedStringArray = []
	for id in friends:
		parts.append("%s=%s" % [id, _realm_of(gs, id)])
	return ", ".join(parts)
