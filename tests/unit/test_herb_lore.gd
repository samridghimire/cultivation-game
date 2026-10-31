extends TestCase
## GATHER-001: herb lore ranks, bonus units, rare-weight scaling and the gather integration.

func _cfg() -> Dictionary:
	return {"ranks": [{"min": 0, "name": "Novice"}, {"min": 15, "name": "Forager"}, {"min": 50, "name": "Herbalist"}, {"min": 120, "name": "Herb Sage"}], "xp_cap": 120, "bonus_chance_max": 0.35, "rare_mult_max": 1.5}


func test_rank_name() -> void:
	var cfg := _cfg()
	assert_eq(HerbLore.rank_name(cfg, 0), "Novice")
	assert_eq(HerbLore.rank_name(cfg, 14), "Novice")
	assert_eq(HerbLore.rank_name(cfg, 15), "Forager")
	assert_eq(HerbLore.rank_name(cfg, 50), "Herbalist")
	assert_eq(HerbLore.rank_name(cfg, 120), "Herb Sage")
	assert_eq(HerbLore.rank_name(cfg, 999), "Herb Sage")
	assert_eq(HerbLore.rank_name({}, 5), "")


func test_status_line() -> void:
	assert_eq(HerbLore.status_line(_cfg(), 32), "Herb lore: Forager (32/50)")
	assert_eq(HerbLore.status_line(_cfg(), 130), "Herb lore: Herb Sage (130)")


func test_bonus_chance() -> void:
	assert_almost_eq(HerbLore.bonus_chance(_cfg(), 0), 0.0, 0.0001)
	assert_almost_eq(HerbLore.bonus_chance(_cfg(), 120), 0.35, 0.0001)
	assert_almost_eq(HerbLore.bonus_chance(_cfg(), 600), 0.35, 0.0001)


func test_skill_table() -> void:
	var table := [{"item": "a", "weight": 5}, {"item": "b", "weight": 2}, {"item": "", "weight": 1}]
	assert_eq(HerbLore.skill_table(_cfg(), table, 0), table)
	var full := HerbLore.skill_table(_cfg(), table, 120)
	assert_almost_eq(float(full[0]["weight"]), 5.0, 0.0001)
	assert_almost_eq(float(full[1]["weight"]), 3.0, 0.0001)
	assert_almost_eq(float(full[2]["weight"]), 1.0, 0.0001)
	assert_almost_eq(float(table[1]["weight"]), 2.0, 0.0001)


func test_bonus_units_draws_only_with_xp() -> void:
	var rng := seeded_rng()
	var found := {"a": 2}
	HerbLore.bonus_units(_cfg(), found, 0, rng)
	assert_eq(found["a"], 2)
	var fresh := seeded_rng()
	assert_eq(rng.randf(), fresh.randf(), "no draw at xp 0")
	var cfg := _cfg()
	cfg["bonus_chance_max"] = 1.0
	var got := HerbLore.bonus_units(cfg, found, 120, seeded_rng())
	assert_eq(found["a"], 3)
	assert_eq(got.size(), 1)


func test_xp_gain() -> void:
	var table := [{"item": "a", "weight": 5}, {"item": "b", "weight": 1}]
	assert_eq(HerbLore.xp_gain(_cfg(), table, {}), 1)
	assert_eq(HerbLore.xp_gain(_cfg(), table, {"a": 1}), 1)
	assert_eq(HerbLore.xp_gain(_cfg(), table, {"b": 1}), 2)


func test_validate() -> void:
	var errors: Array[String] = []
	HerbLore.validate(_cfg(), errors)
	assert_eq(errors.size(), 0)
	var bad := _cfg()
	bad["ranks"] = [{"min": 0, "name": "A"}, {"min": 50, "name": "B"}, {"min": 15, "name": "C"}]
	HerbLore.validate(bad, errors)
	assert_true(errors.size() > 0)
	var errs2: Array[String] = []
	bad = _cfg()
	bad["bonus_chance_max"] = 1.5
	bad["rare_mult_max"] = 0.5
	bad["xp_cap"] = 0
	HerbLore.validate(bad, errs2)
	assert_eq(errs2.size(), 3)


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func test_gather_adds_xp_and_posts_rank_up_once() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Forager", gs.data, seeded_rng(3))
	gs.start_session(c)
	gs.data.herb_lore = _cfg()
	c.gather_xp = 14
	var heard: Array[String] = []
	var cb := func(text: String, category: String) -> void:
		if text.begins_with("Your herb lore"):
			heard.append(text)
	EventBus.message_posted.connect(cb)
	gs.gather([{"item": "", "weight": 1}], 1)
	gs.gather([{"item": "", "weight": 1}], 1)
	EventBus.message_posted.disconnect(cb)
	assert_eq(c.gather_xp, 16)
	assert_eq(heard.size(), 1)
	assert_eq(heard[0], "Your herb lore has improved: Forager.")
	gs.data = GameData.load_from_dir()


func test_gather_at_zero_xp_matches_plain_gather() -> void:
	var gs := _gs()
	var c := CharacterFactory.create("Forager", gs.data, seeded_rng(4))
	gs.start_session(c)
	gs.rng = seeded_rng(77)
	var table := [{"item": "", "weight": 3}, {"item": "spirit_herb", "weight": 5, "min": 1, "max": 2}, {"item": "moon_lotus", "weight": 1, "min": 1, "max": 1}]
	var expected := Exploration.gather(c, Exploration.gather_table_for(c, gs.data, table, Calendar.season_of(GameClock.total_days)), seeded_rng(77))
	gs.data.weather_effects = {}
	gs.data.herb_lore = _cfg()
	gs.gather(table, 1)
	for id: String in expected:
		assert_eq(c.item_count(id), int(expected[id]))
	assert_eq(c.gather_xp, HerbLore.xp_gain(gs.data.herb_lore, table, expected))
	gs.data = GameData.load_from_dir()


func test_gather_xp_round_trips_and_defaults() -> void:
	var c := new_character()
	c.gather_xp = 41
	assert_eq(CharacterData.from_dict(c.to_dict()).gather_xp, 41)
	var d := c.to_dict()
	d.erase("gather_xp")
	assert_eq(CharacterData.from_dict(d).gather_xp, 0)


func test_real_data_validates() -> void:
	var data := GameData.load_from_dir()
	assert_false(data.herb_lore.is_empty())
	assert_eq(HerbLore.rank_name(data.herb_lore, 50), "Herbalist")
