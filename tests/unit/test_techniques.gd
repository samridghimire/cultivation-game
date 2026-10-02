extends TestCase


func test_learn_and_cannot_relearn() -> void:
	var c := new_character()
	assert_true(Techniques.learn(c, data(), "basic_breathing")["ok"])
	assert_eq(Techniques.level(c, "basic_breathing"), 1)
	assert_false(Techniques.learn(c, data(), "basic_breathing")["ok"])


func test_realm_requirement() -> void:
	var c := new_character()
	assert_true(Techniques.can_learn(c, data(), "flowing_water_sutra") != "")
	c.realm_index = 1
	assert_eq(Techniques.can_learn(c, data(), "flowing_water_sutra"), "")


func test_unknown_technique_cannot_be_learned() -> void:
	var c := new_character()
	assert_false(Techniques.learn(c, data(), "no_such_art")["ok"])


func test_practice_levels_up_and_caps_at_max() -> void:
	var c := new_character()
	Techniques.learn(c, data(), "basic_breathing")
	var result := Techniques.practice(c, data(), "basic_breathing", 100000)
	assert_true(result["ok"])
	var max_level: int = data().techniques["basic_breathing"].max_level
	assert_eq(Techniques.level(c, "basic_breathing"), max_level)
	assert_eq(result["levels_gained"], max_level - 1)
	assert_true(Techniques.is_mastered(c, data(), "basic_breathing"))
	assert_false(Techniques.practice(c, data(), "basic_breathing", 30)["ok"])


func test_practice_requires_knowing_it() -> void:
	var c := new_character()
	assert_false(Techniques.practice(c, data(), "iron_fist", 30)["ok"])


func test_cultivation_technique_speeds_qi_gathering() -> void:
	var c := new_character()
	var before := Cultivation.qi_per_day(c, data())
	Techniques.learn(c, data(), "basic_breathing")
	assert_gt(Cultivation.qi_per_day(c, data()), before)


func test_element_affinity() -> void:
	var c := new_character()
	c.techniques = {"stone_skin": {"level": 1, "xp": 0.0}}
	var per_level: float = data().techniques["stone_skin"].bonuses["defense"]
	c.spiritual_roots = {"earth": 50}
	assert_almost_eq(Techniques.bonus(c, data(), "defense"), per_level * (1.0 + data().technique_affinity_bonus))
	c.spiritual_roots = {"fire": 50}
	assert_almost_eq(Techniques.bonus(c, data(), "defense"), per_level * (1.0 - data().technique_mismatch_penalty))


func test_using_manual_teaches_technique() -> void:
	var c := new_character()
	c.add_item("manual_iron_fist", 1)
	assert_true(Items.use(c, data(), "manual_iron_fist", {})["ok"])
	assert_true(Techniques.knows(c, "iron_fist"))
	assert_eq(c.item_count("manual_iron_fist"), 0)


func test_manual_not_consumed_if_cannot_learn() -> void:
	var c := new_character()
	c.add_item("manual_flowing_water", 1)
	assert_false(Items.use(c, data(), "manual_flowing_water", {})["ok"])
	assert_eq(c.item_count("manual_flowing_water"), 1)


func test_techniques_survive_save_round_trip() -> void:
	var c := new_character()
	Techniques.learn(c, data(), "iron_fist")
	Techniques.practice(c, data(), "iron_fist", 45)
	var restored := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(Techniques.level(restored, "iron_fist"), Techniques.level(c, "iron_fist"))
	assert_almost_eq(float(restored.techniques["iron_fist"]["xp"]), float(c.techniques["iron_fist"]["xp"]))
