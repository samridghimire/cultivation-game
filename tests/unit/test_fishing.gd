extends TestCase
## FISH-003: fishing skill (Fishing), xp gain through GameState.fish, save round-trip.


func test_rank_names() -> void:
	assert_eq(Fishing.rank_name(0), "Novice")
	assert_eq(Fishing.rank_name(9), "Novice")
	assert_eq(Fishing.rank_name(10), "Angler")
	assert_eq(Fishing.rank_name(40), "Old Hand")
	assert_eq(Fishing.rank_name(99), "Old Hand")
	assert_eq(Fishing.rank_name(100), "Master")


func test_default_cast_leaves_the_table_unchanged() -> void:
	var table := [{"item": "", "weight": 4}, {"item": "silver_carp", "weight": 5}, {"item": "mist_koi", "weight": 1}]
	var t := Fishing.skill_table(table, 0.5, 0)
	for i in table.size():
		assert_almost_eq(float(t[i]["weight"]), float(table[i]["weight"]))


func test_skill_and_quality_raise_only_rare_weights() -> void:
	var table := [{"item": "", "weight": 4}, {"item": "silver_carp", "weight": 5}, {"item": "mist_koi", "weight": 1}]
	var t := Fishing.skill_table(table, 1.0, 100)
	assert_almost_eq(float(t[2]["weight"]), 1.0 * (1.0 + 0.25 + 0.5))
	assert_eq(t[0]["weight"], 4)
	assert_eq(t[1]["weight"], 5)
	assert_true(Fishing.rare_mult(0.0, 0) < 1.0)


func test_zone_width() -> void:
	assert_almost_eq(Fishing.zone_width(0), 0.18)
	assert_almost_eq(Fishing.zone_width(100), 0.35)
	assert_almost_eq(Fishing.zone_width(500), 0.35)


func test_got_away_only_at_quality_zero() -> void:
	var rng := seeded_rng(7)
	for i in 20:
		assert_false(Fishing.got_away(0.5, rng))
	var lost := 0
	for i in 200:
		if Fishing.got_away(0.0, rng):
			lost += 1
	assert_true(lost > 30 and lost < 90, "about 30%% of 200 got away, got %d" % lost)


func test_default_quality_draws_the_same_catch_as_plain_gather() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := CharacterFactory.create("Angler", gs.data, seeded_rng(1))
	gs.start_session(c)
	gs.rng = seeded_rng(99)
	var table := [{"item": "", "weight": 4}, {"item": "silver_carp", "weight": 5, "min": 1, "max": 2}, {"item": "marsh_eel", "weight": 2, "min": 1, "max": 1}]
	var expected := Exploration.gather(c, Weather.scale_catch(table, Weather.fishing_multiplier(gs.data, Weather.of(gs.data, gs.current_region, GameClock.total_days))), seeded_rng(99))
	gs.fish(table, 1)
	for id: String in expected:
		assert_eq(c.item_count(id), int(expected[id]))
	assert_eq(c.fishing_xp, Fishing.xp_gain(table, expected))


func test_xp_gain_is_two_for_a_rare_catch() -> void:
	var table := [{"item": "silver_carp", "weight": 5}, {"item": "mist_koi", "weight": 1}]
	assert_eq(Fishing.xp_gain(table, {"silver_carp": 1}), 1)
	assert_eq(Fishing.xp_gain(table, {"mist_koi": 1}), 2)
	assert_eq(Fishing.xp_gain(table, {}), 1)


func test_fish_always_adds_xp() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := CharacterFactory.create("Angler", gs.data, seeded_rng(2))
	gs.start_session(c)
	gs.fish([{"item": "", "weight": 1}], 1)
	assert_eq(c.fishing_xp, 1, "even an empty trip teaches something")


func test_fishing_xp_round_trips_and_defaults() -> void:
	var c := new_character()
	c.fishing_xp = 37
	assert_eq(CharacterData.from_dict(c.to_dict()).fishing_xp, 37)
	var d := c.to_dict()
	d.erase("fishing_xp")
	assert_eq(CharacterData.from_dict(d).fishing_xp, 0)
