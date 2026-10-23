extends SceneTree
## PERF-002: advances a curious Qi Refining session 365 days, one `_pass_time(1)` at a time,
## and prints the total, per-day and worst-day cost. To see where it goes, temporarily wrap calls inside
## GameState._on_days_advanced / Npcs.simulate with Time.get_ticks_usec() and print the sums here.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/profile_days.gd


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
