extends SceneTree
## PERF-001: times NPC.get_options() and each helper it calls for a Foundation Establishment
## session, per NPC node of the current region.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/profile_npc_menu.gd

const HELPERS: Array[String] = ["_child_options", "_letter_options", "_acquaintance_options", "_mentor_options", "_treatment_options", "_adoption_options", "_courtship_options", "_karma_options"]


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var c := CharacterFactory.create("Profile", gs.data, RandomNumberGenerator.new(), "male")
	c.spiritual_roots = {"fire": 70, "wood": 50}
	gs.start_session(c)
	gs.rng.seed = 5
	gs.pending_event = ""
	c.add_item("spirit_stone", 20000)
	Techniques.learn(c, gs.data, "iron_fist")
	for item_id: String in gs.data.items:  # a loaded pack, as in the interactable fuzz
		if item_id != "spirit_stone" and int(gs.data.items[item_id].get("price", 0)) > 0:
			c.add_item(item_id, 2)
	c.age_days = 40 * Calendar.DAYS_PER_YEAR
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.stage = 3
	gs.join_sect("azure_cloud_sect")
	gs.current_region = "qingshi_village"
	for i in 6:
		Npcs.spawn(gs.npcs, gs.data, RandomNumberGenerator.new(), {"region": "qingshi_village", "realm": "foundation_establishment" if i % 2 == 0 else "qi_refining", "stage": 2 + i % 3, "age_years": 30, "gender": "female" if i % 3 == 0 else "male"})
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	for id: String in gs.npcs:
		gs.npc_favor[id] = 100  # spar odds only show once the NPC would accept
	var totals := {}
	var calls: Array[float] = []
	for node in world.get_children():
		if node.get_script() == null or not String(node.get_script().resource_path).ends_with("interactables/npc.gd") or not node.is_available():
			continue
		for i in 3:
			if i == 0:
				Combat._chance_cache.clear()  # the first call of each NPC is cold
			var t0 := Time.get_ticks_usec()
			var opts: Array[Dictionary] = node.get_options()
			if OS.get_cmdline_user_args().has("--labels") and i == 0:
				print(node.display_name, ": ", opts.map(func(o: Dictionary) -> String: return String(o["label"])))
			calls.append((Time.get_ticks_usec() - t0) / 1000.0)
		for h in HELPERS:
			Combat._chance_cache.clear()
			var t1 := Time.get_ticks_usec()
			node.call(h)
			totals[h] = float(totals.get(h, 0.0)) + (Time.get_ticks_usec() - t1) / 1000.0
	calls.sort()
	print("npc get_options calls: %d, median %.1f ms, max %.1f ms" % [calls.size(), calls[calls.size() / 2] if not calls.is_empty() else -1.0, calls.back() if not calls.is_empty() else -1.0])
	var keys: Array = totals.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return totals[a] > totals[b])
	for k: String in keys:
		print("  %-24s %.1f ms total" % [k, totals[k]])
	quit()
