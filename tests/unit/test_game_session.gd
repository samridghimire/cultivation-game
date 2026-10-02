extends TestCase
## Integration tests through the GameState / SaveManager autoloads.

const TEST_SLOT := "_test_slot"


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _game_state() -> Node:
	return _root().get_node("GameState")


func _start(seed_value: int = 4242) -> CharacterData:
	var gs := _game_state()
	var c := CharacterFactory.create("Integration", gs.data, seeded_rng(seed_value))
	c.spiritual_roots = {"fire": 80}  # guarantee a usable root
	gs.start_session(c)
	return c


func test_cultivating_advances_time_and_age() -> void:
	var c := _start()
	var clock := _root().get_node("GameClock")
	var age_before := c.age_days
	_game_state().cultivate(Calendar.DAYS_PER_MONTH)
	assert_eq(clock.total_days, Calendar.DAYS_PER_MONTH)
	assert_eq(c.age_days, age_before + Calendar.DAYS_PER_MONTH)
	assert_gt(c.qi, 0.0)


func test_mortal_can_reach_qi_refining() -> void:
	var c := _start()
	var gs := _game_state()
	for i in 24:
		if Cultivation.can_attempt_breakthrough(c, gs.data):
			break
		gs.cultivate(Calendar.DAYS_PER_MONTH)
	assert_true(Cultivation.can_attempt_breakthrough(c, gs.data), "should hit the mortal bottleneck within 2 years")
	for i in 50:
		if c.realm_index > 0:
			break
		gs.attempt_breakthrough()
		gs.cultivate(Calendar.DAYS_PER_MONTH)
	assert_eq(c.realm_index, 1)


func test_player_dies_of_old_age() -> void:
	var c := _start()
	var gs := _game_state()
	c.spiritual_roots = {}  # no cultivation, so lifespan never grows
	for i in 100:
		if not c.alive:
			break
		gs.perform_deed("help_villager")
		gs.work_profession("doctor", Calendar.DAYS_PER_YEAR)
	assert_false(c.alive)
	assert_true(c.cause_of_death != "")


func test_save_and_load_round_trip() -> void:
	var c := _start()
	var gs := _game_state()
	var saves := _root().get_node("SaveManager")
	gs.cultivate(Calendar.DAYS_PER_YEAR)
	gs.perform_deed("kill_villager")
	var expected: Dictionary = c.to_dict()
	var expected_days: int = _root().get_node("GameClock").total_days
	assert_true(saves.save_game(TEST_SLOT))
	gs.end_session()
	assert_true(saves.load_game(TEST_SLOT))
	assert_eq(gs.player.to_dict(), expected)
	assert_eq(_root().get_node("GameClock").total_days, expected_days)
	assert_true(gs.world_flags.get("villager_dead", false))
	DirAccess.remove_absolute(saves.save_path(TEST_SLOT))
	gs.end_session()
