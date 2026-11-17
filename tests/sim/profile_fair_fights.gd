extends SceneTree
## GUIDE-252: times Guidance.fair_fights cold (Combat._chance_cache cleared) and warm for four players and prints
## the win_chance simulation counts. Usage: tools/godot.sh --headless --path . -s res://tests/sim/profile_fair_fights.gd


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var cases: Array = [
		["mortal, qingshi_town", "mortal", 0, "qingshi_village"],
		["QR5, misty_forest", "qi_refining", 5, "misty_forest"],
		["Foundation 3, qingshi_town", "foundation_establishment", 3, "qingshi_village"],
		["Foundation 3, azure_peak", "foundation_establishment", 3, "azure_peak"],
	]
	for spec: Array in cases:
		var c := CharacterFactory.create("Profile", gs.data, RandomNumberGenerator.new(), "male")
		c.spiritual_roots = {"fire": 70, "wood": 50}
		gs.start_session(c)
		gs.pending_event = ""
		c.realm_index = gs.data.realm_index_of(String(spec[1]))
		c.stage = int(spec[2])
		c.techniques = {"iron_fist": {"level": 3, "xp": 0.0}, "stone_skin": {"level": 2, "xp": 0.0}}
		var region: String = spec[3]
		if not gs.data.regions.has(region):
			print("%s: region missing, skipped" % spec[0])
			continue
		gs.current_region = region
		var today: int = root.get_node("GameClock").total_days
		for run in 2:
			if run == 0:
				Combat._chance_cache.clear()
			var s0: int = Combat._sim_count
			var t0 := Time.get_ticks_usec()
			var f := Guidance.fair_fights(c, gs.data, gs.world_flags, today, region, gs.npcs, gs.npc_favor)
			print("%-28s %s: %6.1f ms, %3d sims, %d fights" % [spec[0], "cold" if run == 0 else "warm", (Time.get_ticks_usec() - t0) / 1000.0, Combat._sim_count - s0, f.size()])
	quit()
