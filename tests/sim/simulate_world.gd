extends SceneTree
## Long-session performance sim (QA-014): runs a real GameState session for
## many years headless (monthly GameClock.advance, so NPC lives, families,
## clans, world events, pruning and the rest all run as in play) with an
## immortal-ish player, and reports every `report_every` years: living / total
## NPCs, world events under way, the save size (GameState.to_save_dict as JSON)
## and the average milliseconds per simulated month over the last stretch.
## Flags anything that keeps growing.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_world.gd -- [years] [seed] [report_every]


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 200
	var seed_value := int(args[1]) if args.size() > 1 else 1
	var report_every := int(args[2]) if args.size() > 2 else 20
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	gs.rng.seed = seed_value
	var player := CharacterFactory.create("Sim Patriarch", gs.data, gs.rng)
	gs.start_session(player)
	gs.pending_event = ""
	# A Mahayana player lives for millennia, so the session never ends by old age.
	player.realm_index = gs.data.realms.size() - 2
	var sizes: Array[int] = []
	var npc_totals: Array[int] = []
	print("World sim: %d years, seed %d" % [years, seed_value])
	print("  year  alive  total  events  save-kB  ms/month")
	var started := Time.get_ticks_usec()
	for year in range(1, years + 1):
		for month in 12:
			clock.advance(Calendar.DAYS_PER_MONTH)
		if year % report_every == 0 or year == years:
			var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
			var alive := 0
			for c: CharacterData in gs.npcs.values():
				if c.alive:
					alive += 1
			var size_kb := JSON.stringify(gs.to_save_dict()).length() / 1024
			sizes.append(size_kb)
			npc_totals.append(gs.npcs.size())
			print("  %4d  %5d  %5d  %6d  %7d  %8.2f" % [year, alive, gs.npcs.size(), gs.world_events.size(), size_kb, elapsed_ms / (report_every * 12)])
			started = Time.get_ticks_usec()
	if sizes.size() >= 3 and sizes[-1] > sizes[sizes.size() / 2] * 1.25:
		print("WARNING: the save grew more than 25%% in the second half (%d kB -> %d kB)" % [sizes[sizes.size() / 2], sizes[-1]])
	if npc_totals.size() >= 3 and npc_totals[-1] > npc_totals[npc_totals.size() / 2] * 1.25:
		print("WARNING: the NPC table grew more than 25%% in the second half")
	print("Done.")
	gs.end_session()
	quit()
