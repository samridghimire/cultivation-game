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


func test_sell_crafted_talisman_pays_material_capped_price() -> void:
	var c := _start()
	var gs := _game_state()
	c.inventory = {"golden_bell_talisman": 3}
	gs.sell_item("golden_bell_talisman", 2)
	assert_eq(c.item_count("golden_bell_talisman"), 1)
	assert_eq(c.item_count("spirit_stone"), 2 * Items.sell_price(gs.data, "golden_bell_talisman"))
	assert_gt(30, c.item_count("spirit_stone"))  # not the old 15 stones apiece
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


func _arm_blood_drinker(c: CharacterData) -> void:
	c.add_item("blood_drinker_saber", 1)
	Equipment.equip(c, _game_state().data, "blood_drinker_saber")


func test_fight_with_evil_weapon_burns_a_year() -> void:
	var c := _start()
	var gs := _game_state()
	_arm_blood_drinker(c)
	var before := Cultivation.years_left(c, gs.data)
	gs.fight("wild_boar")
	assert_true(c.alive)
	assert_eq(Cultivation.years_left(c, gs.data), before - 1)
	gs.end_session()


func test_evil_weapon_drinking_last_year_kills_of_old_age() -> void:
	var c := _start()
	var gs := _game_state()
	_arm_blood_drinker(c)
	c.age_days = (Cultivation.lifespan_years(c, gs.data) - 1) * Calendar.DAYS_PER_YEAR
	gs.fight("wild_boar")
	assert_false(c.alive)
	assert_true(c.cause_of_death.contains("weapon drinks the last"))
	gs.end_session()


func test_violent_death_does_not_also_drain_lifespan() -> void:
	var c := _start()
	var gs := _game_state()
	_arm_blood_drinker(c)
	var doom := {"id": "doom", "name": "Doom", "realm": "tribulation", "stage": 9, "hp": 100000, "attack": 100000, "defense": 100000, "speed": 100, "lethal": true, "techniques": [], "rewards": {}}
	gs.fight_enemy(doom)
	assert_eq(c.lifespan_spent_years, 0, "a respawned soul keeps its years; the saber drinks only after survived fights")
	gs.end_session()


func test_choose_gender_once_for_old_saves() -> void:
	var c := _start()
	var gs := _game_state()
	c.gender = ""
	gs.choose_gender("dragon")
	assert_eq(c.gender, "")
	gs.choose_gender("female")
	assert_eq(c.gender, "female")
	gs.choose_gender("male")
	assert_eq(c.gender, "female", "gender can only be picked once")


func test_gathering_skips_realm_gated_finds() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 0
	var table := [{"item": "nine_leaf_soul_grass", "weight": 1, "min": 1, "max": 1, "min_realm": "foundation_establishment"}]
	gs.gather(table, 5)
	assert_eq(c.item_count("nine_leaf_soul_grass"), 0, "too shallow to find it")
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	gs.gather(table, 5)
	assert_gt(c.item_count("nine_leaf_soul_grass"), 0)


func test_deed_with_enemy_needs_a_win() -> void:
	var c := _start()
	var gs := _game_state()
	c.realm_index = 0
	c.stage = 0
	var alignment_before := c.alignment
	gs.perform_deed("free_bandit_captives")
	assert_false(gs.world_flags.get("bandit_camp_gone", false), "a mortal loses to the bandit lord")
	assert_eq(c.alignment, alignment_before)
	assert_true(c.alive, "the bandit lord is not lethal")
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	gs.perform_deed("free_bandit_captives")
	assert_true(gs.world_flags.get("bandit_camp_gone", false), "a Foundation cultivator wins and frees them")
	assert_gt(c.alignment, alignment_before)
