extends TestCase
## Dao insights (DAO-001): levels, Comprehension checks, technique and breakthrough bonuses.


func test_effect_grants_a_level_up_to_max() -> void:
	var c := new_character()
	var notes := Effects.apply(c, data(), {"dao_insight": "sword_dao"}, {})
	assert_eq(Dao.level(c, "sword_dao"), 1)
	assert_eq(notes.size(), 1)
	assert_eq(Dao.gain_levels(c, data(), "sword_dao", 100), Dao.max_level(data()) - 1)
	assert_eq(Dao.gain_levels(c, data(), "sword_dao"), 0)
	assert_eq(Dao.gain_levels(c, data(), "no_such_dao"), 0)


func test_insight_strengthens_matching_techniques_only() -> void:
	var c := new_character()
	c.spiritual_roots = {}
	c.techniques = {"metal_edge_sword": {"level": 2, "xp": 0.0}, "stone_skin": {"level": 2, "xp": 0.0}}
	var attack := Techniques.bonus(c, data(), "attack")
	var defense := Techniques.bonus(c, data(), "defense")
	Dao.gain_levels(c, data(), "sword_dao", 2)
	var per_level: float = data().dao_insights["sword_dao"]["technique_bonus"]
	assert_almost_eq(Techniques.bonus(c, data(), "attack"), attack * (1.0 + per_level * 2))
	assert_almost_eq(Techniques.bonus(c, data(), "defense"), defense)


func test_insight_adds_to_breakthrough_chance() -> void:
	var c := new_character()
	var before := Cultivation.breakthrough_chance(c, data())
	Dao.gain_levels(c, data(), "dao_of_breath", 2)
	var expected := before + float(data().dao_insights["dao_of_breath"]["breakthrough_bonus"]) * 2
	assert_almost_eq(Cultivation.breakthrough_chance(c, data()), minf(expected, 0.99))


func test_comprehension_raises_check_chance() -> void:
	var c := new_character()
	c.attributes["comprehension"] = 5
	var low := Dao.check_chance(c, data())
	c.attributes["comprehension"] = 20
	assert_gt(Dao.check_chance(c, data()), low)
	c.attributes["comprehension"] = 1000
	assert_almost_eq(Dao.check_chance(c, data()), float(data().dao["check"]["max"]))


func test_practice_long_enough_can_reveal_an_insight() -> void:
	var c := new_character()
	c.attributes["comprehension"] = 1000  # always passes the check
	var needed := Dao.progress_needed(c, data(), "dao_of_breath")
	assert_eq(Dao.on_practice(c, data(), "basic_breathing", int(needed) - 1, seeded_rng()).size(), 0)
	assert_eq(Dao.level(c, "dao_of_breath"), 0)
	var gained := Dao.on_practice(c, data(), "basic_breathing", 1, seeded_rng())
	assert_eq(gained.get("dao_of_breath", 0), 1)
	assert_eq(Dao.level(c, "dao_of_breath"), 1)
	assert_eq(Dao.on_practice(c, data(), "metal_edge_sword", 10000, seeded_rng()).has("dao_of_breath"), false)


func test_failed_check_keeps_part_of_progress() -> void:
	var c := new_character()
	c.attributes["comprehension"] = -1000  # always fails (min chance is tiny)
	var needed := Dao.progress_needed(c, data(), "dao_of_breath")
	var rng := seeded_rng()
	var failed := false
	for i in 20:
		if Dao.add_progress(c, data(), "dao_of_breath", needed, rng) == 0:
			failed = true
			break
	assert_true(failed)
	assert_true(Dao.progress(c, "dao_of_breath") < needed * 2)


func test_contemplation_needs_a_glimpse_first() -> void:
	var c := new_character()
	assert_false(Dao.contemplate(c, data(), "fire_dao", 30, seeded_rng())["ok"])
	assert_false(Dao.contemplate(c, data(), "no_such_dao", 30, seeded_rng())["ok"])
	Dao.gain_levels(c, data(), "fire_dao")
	c.attributes["comprehension"] = 1000
	var result := Dao.contemplate(c, data(), "fire_dao", 365, seeded_rng())
	assert_true(result["ok"])
	assert_gt(result["levels"], 0)
	Dao.gain_levels(c, data(), "fire_dao", 100)
	assert_false(Dao.contemplate(c, data(), "fire_dao", 30, seeded_rng())["ok"])


func test_dao_survives_save_round_trip() -> void:
	var c := new_character()
	Dao.gain_levels(c, data(), "water_dao", 2)
	Dao.add_progress(c, data(), "water_dao", 10.0, seeded_rng())
	var loaded := CharacterData.from_dict(c.to_dict())
	assert_eq(Dao.level(loaded, "water_dao"), 2)
	assert_almost_eq(Dao.progress(loaded, "water_dao"), 10.0)
	var old_save := c.to_dict()
	old_save.erase("dao")
	assert_true(CharacterData.from_dict(old_save).dao.is_empty())


func test_dao_data_is_valid_and_reachable() -> void:
	assert_eq(Dao.validate(data()).size(), 0)
	var granted := {}
	for enc: Dictionary in data().encounters.values():
		if enc.get("effects", {}).has("dao_insight"):
			granted[enc["effects"]["dao_insight"]] = true
	assert_gt(granted.size(), 0, "some encounter grants a Dao insight")


func test_game_state_contemplate_and_practice() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Sage", gs.data, seeded_rng())
	gs.start_session(c)
	gs.rng.seed = 12345  # Comprehension checks cap at 95%: don't depend on what earlier tests rolled
	var clock := (Engine.get_main_loop() as SceneTree).root.get_node("GameClock")
	var days_before: int = clock.total_days
	gs.contemplate_dao("fire_dao", 30)  # refused: not glimpsed, no time passes
	assert_eq(clock.total_days, days_before)
	Dao.gain_levels(c, gs.data, "fire_dao")
	c.attributes["comprehension"] = 1000
	gs.rng.seed = 7  # the check still fails 5% of the time; keep the outcome independent of earlier tests
	gs.contemplate_dao("fire_dao", 365)
	assert_eq(clock.total_days, days_before + 365)
	assert_gt(Dao.level(c, "fire_dao"), 1)
	Techniques.learn(c, gs.data, "basic_breathing")
	gs.rng.seed = 7  # the year of contemplation drew a varying number of rolls (world sim); reseed for the practice check
	gs.practice_technique("basic_breathing", 400)
	assert_gt(Dao.level(c, "dao_of_breath"), 0)
	gs.end_session()


func test_every_insight_can_be_glimpsed_and_strengthens_an_art() -> void:
	var d := data()
	var granted := {}
	for item: Dictionary in d.items.values():
		granted[item.get("effects", {}).get("dao_insight", "")] = true
	for enc: Dictionary in d.encounters.values():
		granted[enc.get("effects", {}).get("dao_insight", "")] = true
		for choice: Dictionary in enc.get("choices", []):
			granted[choice.get("effects", {}).get("dao_insight", "")] = true
	for insight_id in d.dao_insights:
		var insight: Dictionary = d.dao_insights[insight_id]
		assert_true(granted.has(insight_id), "%s is granted by an item or encounter" % insight_id)
		var arts := 0
		for tech: TechniqueDef in d.techniques.values():
			if Dao.matches(insight, tech):
				arts += 1
		assert_gt(arts, 0, "%s strengthens at least one technique" % insight_id)


func test_slaughter_field_offers_opposite_daos() -> void:
	var enc: Dictionary = data().encounters["marsh_slaughter_field"]
	var c := new_character()
	c.alignment = -500
	Effects.apply(c, data(), enc["choices"][0]["effects"], {})
	assert_eq(Dao.level(c, "dao_of_slaughter"), 1)
	assert_true(c.alignment < -500)
	var saint := new_character()
	Effects.apply(saint, data(), enc["choices"][1]["effects"], {})
	assert_eq(Dao.level(saint, "vajra_dao"), 1)
