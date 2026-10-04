extends TestCase
## Main cultivation methods (CM-001): one active method, qi rate, element affinity,
## max realm cap, switching, saves and the GameState action.

const METHOD := "verdant_spring_method"


func _game_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_everyone_starts_on_the_starter_method() -> void:
	var c := new_character()
	assert_eq(Techniques.main_method(c, data()), data().starter_method)
	assert_almost_eq(Techniques.method_rate(c, data()), 1.0)


func test_starter_method_keeps_old_speed() -> void:
	var c := new_character()
	var before := Cultivation.qi_per_day(c, data())
	c.main_method = "no_such_method"
	assert_almost_eq(Cultivation.qi_per_day(c, data()), before)
	assert_eq(Techniques.main_method(c, data()), data().starter_method)


func test_learning_first_method_makes_it_main_and_speeds_qi() -> void:
	var c := new_character()
	c.spiritual_roots = {"fire": 60}
	var before := Cultivation.qi_per_day(c, data())
	assert_true(Techniques.learn(c, data(), METHOD)["ok"])
	assert_eq(Techniques.main_method(c, data()), METHOD)
	assert_gt(Cultivation.qi_per_day(c, data()), before)


func test_element_affinity_scales_method_rate() -> void:
	var c := new_character()
	Techniques.learn(c, data(), METHOD)
	var extra: float = data().techniques[METHOD].qi_rate - 1.0
	c.spiritual_roots = {"wood": 60}
	assert_almost_eq(Techniques.method_rate(c, data()), 1.0 + extra * (1.0 + data().technique_affinity_bonus))
	c.spiritual_roots = {"fire": 60}
	assert_almost_eq(Techniques.method_rate(c, data()), 1.0 + extra * (1.0 - data().technique_mismatch_penalty))


func test_method_is_outgrown_past_max_realm() -> void:
	var c := new_character()
	Techniques.learn(c, data(), METHOD)
	c.realm_index = data().realm_index_of(data().techniques[METHOD].max_realm)
	assert_false(Techniques.is_outgrown(c, data(), METHOD))
	c.realm_index += 1
	assert_true(Techniques.is_outgrown(c, data(), METHOD))
	assert_almost_eq(Techniques.method_rate(c, data()), data().method_over_cap_rate)
	assert_true(Techniques.describe_method(c, data(), METHOD).contains("outgrown"))


func test_only_main_method_bonuses_apply() -> void:
	var c := new_character()
	c.spiritual_roots = {"wood": 60}
	Techniques.learn(c, data(), METHOD)
	assert_gt(Techniques.bonus(c, data(), "max_hp"), 0.0)
	assert_true(Techniques.set_main_method(c, data(), data().starter_method)["ok"])
	assert_almost_eq(Techniques.bonus(c, data(), "max_hp"), 0.0)
	assert_almost_eq(Techniques.method_rate(c, data()), 1.0)


func test_set_main_method_rules() -> void:
	var c := new_character()
	assert_true(Techniques.check_set_main(c, data(), METHOD) != "", "unknown method")
	assert_true(Techniques.check_set_main(c, data(), "iron_fist") != "", "not a method")
	assert_true(Techniques.check_set_main(c, data(), data().starter_method) != "", "already main")
	Techniques.learn(c, data(), METHOD)
	assert_true(Techniques.check_set_main(c, data(), METHOD) != "", "already main after learning")
	var result := Techniques.set_main_method(c, data(), data().starter_method)
	assert_true(result["ok"])
	assert_eq(result["days"], data().method_switch_days)
	assert_eq(c.main_method, "")
	assert_true(Techniques.set_main_method(c, data(), METHOD)["ok"])
	assert_eq(c.main_method, METHOD)


func test_main_method_survives_save_round_trip() -> void:
	var c := new_character()
	Techniques.learn(c, data(), METHOD)
	var loaded := CharacterData.from_dict(c.to_dict())
	assert_eq(loaded.main_method, METHOD)
	var old_save := c.to_dict()
	old_save.erase("main_method")
	assert_eq(CharacterData.from_dict(old_save).main_method, "")


func test_data_has_valid_starter_method() -> void:
	var starter: TechniqueDef = data().techniques.get(data().starter_method)
	assert_true(starter != null and starter.is_method())
	assert_almost_eq(starter.qi_rate, 1.0)


func test_game_state_set_main_method_takes_time() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Method", gs.data, seeded_rng())
	gs.start_session(c)
	c.add_item("manual_verdant_spring", 1)
	gs.use_item("manual_verdant_spring")
	assert_eq(Techniques.main_method(c, gs.data), METHOD)
	var clock := (Engine.get_main_loop() as SceneTree).root.get_node("GameClock")
	var days_before: int = clock.total_days
	gs.set_main_method(gs.data.starter_method)
	assert_eq(Techniques.main_method(c, gs.data), gs.data.starter_method)
	assert_eq(clock.total_days, days_before + gs.data.method_switch_days)
	gs.set_main_method("iron_fist")  # refused, no time passes
	assert_eq(clock.total_days, days_before + gs.data.method_switch_days)
	gs.end_session()

