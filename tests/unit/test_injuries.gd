extends TestCase


func test_injury_slows_cultivation() -> void:
	var c := new_character()
	var before := Cultivation.qi_per_day(c, data())
	assert_true(Injuries.inflict(c, data(), "qi_deviation"))
	var mult := float(data().injuries["qi_deviation"]["cultivation_mult"])
	assert_almost_eq(Cultivation.qi_per_day(c, data()), before * mult)


func test_injury_weakens_combat_stats() -> void:
	var c := new_character()
	var before: Dictionary = Combat.stats(c, data())
	Injuries.inflict(c, data(), "broken_bones")
	var after: Dictionary = Combat.stats(c, data())
	assert_gt(before["attack"], after["attack"])
	assert_gt(before["max_hp"], after["max_hp"])


func test_injuries_stack_multiplicatively() -> void:
	var c := new_character()
	Injuries.inflict(c, data(), "qi_deviation")
	Injuries.inflict(c, data(), "internal_injury")
	var expected := float(data().injuries["qi_deviation"]["cultivation_mult"]) * float(data().injuries["internal_injury"]["cultivation_mult"])
	assert_almost_eq(Injuries.cultivation_multiplier(c, data()), expected)


func test_reinjury_keeps_longer_duration() -> void:
	var c := new_character()
	Injuries.inflict(c, data(), "broken_bones")
	Injuries.pass_days(c, 10)
	Injuries.inflict(c, data(), "broken_bones")
	assert_eq(c.injuries["broken_bones"], int(data().injuries["broken_bones"]["heal_days"]))


func test_time_heals() -> void:
	var c := new_character()
	Injuries.inflict(c, data(), "broken_bones")
	var days := int(data().injuries["broken_bones"]["heal_days"])
	assert_eq(Injuries.pass_days(c, days - 1).size(), 0)
	assert_eq(Injuries.pass_days(c, 1), PackedStringArray(["broken_bones"]))
	assert_false(Injuries.has_any(c))


func test_unknown_injury_rejected() -> void:
	var c := new_character()
	assert_false(Injuries.inflict(c, data(), "stubbed_toe"))
	assert_false(Injuries.has_any(c))


func test_roll_respects_chance_and_table() -> void:
	var c := new_character()
	c.attributes["fortune"] = 10
	var hits := 0
	for i in 200:
		c.injuries = {}
		var id := Injuries.roll(c, data(), "breakthrough_failure", seeded_rng(i))
		if id != "":
			hits += 1
			assert_true(id == "qi_deviation" or id == "damaged_meridians", id)
	var chance := float(data().injury_sources["breakthrough_failure"]["chance"])
	assert_true(absf(hits / 200.0 - chance) < 0.12, "hit rate %d/200 vs chance %f" % [hits, chance])


func test_good_fortune_reduces_injury_chance() -> void:
	var c := new_character()
	var lucky := 0
	var unlucky := 0
	for i in 200:
		c.injuries = {}
		c.attributes["fortune"] = 30
		if Injuries.roll(c, data(), "breakthrough_failure", seeded_rng(i)) != "":
			lucky += 1
		c.injuries = {}
		c.attributes["fortune"] = 0
		if Injuries.roll(c, data(), "breakthrough_failure", seeded_rng(i)) != "":
			unlucky += 1
	assert_gt(unlucky, lucky)


func test_failed_breakthrough_can_injure() -> void:
	var c := new_character()
	c.realm_index = 2  # Foundation Establishment -> Core Formation is hard
	c.stage = data().realms[2].stage_count() - 1
	var injured := 0
	for i in 40:
		c.injuries = {}
		c.realm_index = 2
		c.stage = data().realms[2].stage_count() - 1
		c.qi = data().realms[2].qi_required(c.stage)
		var result := Cultivation.attempt_breakthrough(c, data(), seeded_rng(i))
		if not result["success"] and result["injury"] != "":
			injured += 1
			assert_true(c.injuries.has(result["injury"]))
	assert_gt(injured, 0)


func test_healing_items() -> void:
	var c := new_character()
	c.add_item("bone_setting_salve", 1)
	assert_false(Items.use(c, data(), "bone_setting_salve", {})["ok"], "useless when not injured")
	assert_eq(c.item_count("bone_setting_salve"), 1)
	Injuries.inflict(c, data(), "broken_bones")
	assert_true(Items.use(c, data(), "bone_setting_salve", {})["ok"])
	assert_false(Injuries.has_any(c))


func test_heal_all_pill() -> void:
	var c := new_character()
	Injuries.inflict(c, data(), "broken_bones")
	Injuries.inflict(c, data(), "qi_deviation")
	c.add_item("jade_marrow_pill", 1)
	assert_true(Items.use(c, data(), "jade_marrow_pill", {})["ok"])
	assert_false(Injuries.has_any(c))


func test_injuries_survive_save_round_trip() -> void:
	var c := new_character()
	Injuries.inflict(c, data(), "internal_injury")
	Injuries.pass_days(c, 7)
	var restored := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(restored.injuries, c.injuries)


func test_describe_lists_each_injury() -> void:
	var c := new_character()
	assert_eq(Injuries.describe(c, data()).size(), 0)
	Injuries.inflict(c, data(), "broken_bones")
	var lines := Injuries.describe(c, data())
	assert_eq(lines.size(), 1)
	assert_true(lines[0].begins_with("Broken Bones"))


func test_game_time_heals_injuries() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var c := CharacterFactory.create("Patient", gs.data, seeded_rng())
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	Injuries.inflict(c, gs.data, "broken_bones")
	gs.cultivate(Calendar.DAYS_PER_YEAR)
	assert_false(Injuries.has_any(c), "a year of rest heals broken bones")
	gs.end_session()
