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


func test_join_and_leave_sect() -> void:
	var c := _start()
	var gs := _game_state()
	c.alignment = 0
	gs.join_sect("blood_lotus_sect")
	assert_eq(c.sect.get("id", ""), "blood_lotus_sect")
	# Already in a sect: second join is refused and changes nothing.
	gs.join_sect("myriad_treasure_pavilion")
	assert_eq(c.sect.get("id", ""), "blood_lotus_sect")
	gs.leave_sect()
	assert_true(c.is_rogue())
	gs.leave_sect()  # leaving while rogue is harmless
	assert_true(c.is_rogue())
	gs.end_session()


func test_join_sect_rejects_wrong_alignment() -> void:
	var c := _start()
	var gs := _game_state()
	c.alignment = 500
	gs.join_sect("blood_lotus_sect")
	assert_true(c.is_rogue())
	gs.end_session()


func test_buy_item_spends_stones() -> void:
	var c := _start()
	var gs := _game_state()
	c.inventory["spirit_stone"] = 20
	gs.buy_item("qi_gathering_pill")  # price 15
	assert_eq(c.item_count("qi_gathering_pill"), 1)
	assert_eq(c.item_count("spirit_stone"), 5)
	gs.buy_item("qi_gathering_pill")  # cannot afford
	assert_eq(c.item_count("qi_gathering_pill"), 1)
	assert_eq(c.item_count("spirit_stone"), 5)
	gs.end_session()


func test_use_item_consumes_and_applies() -> void:
	var c := _start()
	var gs := _game_state()
	gs.use_item("qi_gathering_pill")  # none owned: refused
	assert_eq(c.qi, 0.0)
	c.add_item("qi_gathering_pill", 1)
	gs.use_item("qi_gathering_pill")
	assert_eq(c.item_count("qi_gathering_pill"), 0)
	assert_gt(c.qi, 0.0)
	gs.end_session()


func test_work_profession_pays_and_gives_contribution() -> void:
	var c := _start()
	var gs := _game_state()
	var clock := _root().get_node("GameClock")
	c.alignment = 0
	gs.join_sect("blood_lotus_sect")
	var stones_before := c.item_count("spirit_stone")
	gs.work_profession("talisman_master", Calendar.DAYS_PER_MONTH)  # favored by Blood Lotus
	assert_eq(clock.total_days, Calendar.DAYS_PER_MONTH)
	assert_gt(c.item_count("spirit_stone"), stones_before)
	assert_gt(int(c.sect["contribution"]), 0)
	gs.end_session()


func test_work_profession_promotes_in_sect() -> void:
	var c := _start()
	var gs := _game_state()
	c.alignment = 0
	gs.join_sect("blood_lotus_sect")
	c.sect["contribution"] = 399
	gs.work_profession("talisman_master", Calendar.DAYS_PER_MONTH)
	assert_eq(int(c.sect["rank"]), 1)
	gs.end_session()


func test_work_profession_rogue_has_no_contribution() -> void:
	var c := _start()
	var gs := _game_state()
	gs.work_profession("alchemist", Calendar.DAYS_PER_MONTH)
	assert_true(c.sect.is_empty())
	gs.end_session()
