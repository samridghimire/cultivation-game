extends SceneTree
## PERF-002: advances a curious Qi Refining session 365 days, one `_pass_time(1)` at a time,
## and prints the total, per-day and worst-day cost. To see where it goes, temporarily wrap calls inside
## GameState._on_days_advanced / Npcs.simulate with Time.get_ticks_usec() and print the sums here.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/profile_days.gd
## QA-159: add `-- --hints` to time Guidance.hints / Guidance.journal for a Foundation Middle member instead
## (cold = Combat._chance_cache cleared, as after a stage-up or technique level; warm = second call).


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
	gs.join_sect("azure_cloud_sect")
	if OS.get_cmdline_user_args().has("--hints"):
		_profile_hints(gs, c)
		quit()
		return
	var total := 0
	var worst := 0
	for day in 365:
		var t0 := Time.get_ticks_usec()
		gs._pass_time(1)
		var dt := Time.get_ticks_usec() - t0
		total += dt
		worst = maxi(worst, dt)
		if not gs.player.alive:
			break
	print("365 days: %.1f ms total, %.0f us/day, worst day %.1f ms" % [total / 1000.0, total / 365.0, worst / 1000.0])
	quit()


func _profile_hints(gs: Node, c: CharacterData) -> void:
	var fe: int = gs.data.realm_index_of("foundation_establishment")
	c.realm_index = fe
	c.stage = 1
	c.qi = gs.data.realms[fe].qi_required(1) * 0.5
	c.techniques = {"iron_fist": {"level": 5, "xp": 0.0}, "stone_skin": {"level": 3, "xp": 0.0}}
	c.sect = {"id": "azure_cloud_sect", "rank": 3, "contribution": 7773, "spent": 0}
	gs.current_region = "qingshi_town"
	var density: float = gs.hint_density()
	var today: int = root.get_node("GameClock").total_days
	for run in 2:
		var label := "cold" if run == 0 else "warm"
		if run == 0:
			Combat._chance_cache.clear()
		var sims0: int = Combat._sim_count
		var t0 := Time.get_ticks_usec()
		var hints := Guidance.hints(c, gs.data, density, 6, gs.npcs, gs.world_flags, gs.current_region, today, gs.npc_favor)
		var t1 := Time.get_ticks_usec()
		var sims1: int = Combat._sim_count
		print("hints   %s: %.1f ms, %d rating sims, %d lines" % [label, (t1 - t0) / 1000.0, sims1 - sims0, hints.size()])
		if run == 0:
			for key: String in Combat._chance_cache:
				print("  rated by hints: %s" % key.get_slice("|", 2).left(70))
			Combat._chance_cache.clear()
		sims0 = Combat._sim_count
		t0 = Time.get_ticks_usec()
		var j := Guidance.journal(c, gs.data, gs.world_flags, today, gs.current_region, density, gs.npcs, gs.world_events, gs.clan, gs.npc_favor)
		t1 = Time.get_ticks_usec()
		print("journal %s: %.1f ms, %d rating sims, %d entries" % [label, (t1 - t0) / 1000.0, Combat._sim_count - sims0, j.size()])
