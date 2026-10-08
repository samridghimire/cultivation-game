extends TestCase
## QA-031: a few simulated years with save -> JSON -> load round trips in between
## must not change the saved state (the full 50-year version is tests/sim/simulate_save_soak.gd).


func test_round_trips_are_stable_over_a_decade() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	gs.rng.seed = 7
	gs.start_session(CharacterFactory.create("Soak", gs.data, gs.rng))
	gs.pending_event = ""
	gs.player.realm_index = gs.data.realms.size() - 2
	gs.load_save_dict(JSON.parse_string(JSON.stringify(gs.to_save_dict())))  # settle silent milestone awards
	for year in 10:
		for month in 12:
			clock.advance(Calendar.DAYS_PER_MONTH)
		if year % 3 == 2:
			var before: Variant = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
			gs.load_save_dict(before)
			var after: Variant = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
			assert_true(before == after, "save differs after a round trip in year %d" % (year + 1))
	gs.end_session()
