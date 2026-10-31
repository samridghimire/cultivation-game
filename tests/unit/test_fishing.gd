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
	var firsts := 0
	for id: String in expected:
		firsts += Fishing.FIRST_CATCH_XP if gs.data.items[id].get("tags", []).has("fish") else 0
	assert_eq(c.fishing_xp, Fishing.xp_gain(table, expected) + firsts)


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


## FISH-004: the angler's log.
func test_first_catch_once_and_counts() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := CharacterFactory.create("Angler", gs.data, seeded_rng(3))
	gs.start_session(c)
	var table := [{"item": "silver_carp", "weight": 5, "min": 1, "max": 1}]
	var caught := 0
	for i in 40:
		var before := c.item_count("silver_carp")
		gs.fish(table, 1, "", 0.5)
		caught += c.item_count("silver_carp") - before
	assert_true(caught > 0)
	assert_eq(int(c.catch_log["silver_carp"]), caught)
	assert_eq(c.fishing_xp, 40 + Fishing.FIRST_CATCH_XP, "one xp a trip, the first catch pays 2 once")


func test_record_catch_reports_first_only() -> void:
	var c := CharacterData.new()
	assert_true(Fishing.record_catch(c, "silver_carp", 2))
	assert_false(Fishing.record_catch(c, "silver_carp", 1))
	assert_eq(int(c.catch_log["silver_carp"]), 3)


func test_log_summary_counts_kinds_from_the_tables() -> void:
	var d := data()
	var c := CharacterData.new()
	assert_eq(Fishing.log_summary(c, d), "", "empty log, no line")
	var kinds := Fishing.catchable(d)
	assert_true(kinds.has("silver_carp") and kinds.has("mist_koi") and not kinds.has("fish_stew"))
	Fishing.record_catch(c, "silver_carp", 1)
	assert_eq(Fishing.log_summary(c, d), "Fish caught: 1 of %d kinds" % kinds.size())


func test_missing_hint_picks_first_uncaught_in_season_fish() -> void:
	var d := data()
	var c := CharacterData.new()
	assert_eq(Fishing.missing_hint(c, d, "misty_forest", "Summer"), "Silver Carp bites here in summer.")
	Fishing.record_catch(c, "silver_carp", 1)
	assert_eq(Fishing.missing_hint(c, d, "misty_forest", "Summer"), "Marsh Eel bites here in summer.")
	Fishing.record_catch(c, "marsh_eel", 1)
	Fishing.record_catch(c, "mist_koi", 1)
	assert_eq(Fishing.missing_hint(c, d, "misty_forest", "Summer"), "")
	assert_eq(Fishing.missing_hint(c, d, "no_such_region", "Summer"), "")


func test_catch_log_round_trips_and_defaults() -> void:
	var c := CharacterData.new()
	c.catch_log = {"silver_carp": 3}
	assert_eq(int(CharacterData.from_dict(c.to_dict()).catch_log["silver_carp"]), 3)
	var d := c.to_dict()
	d.erase("catch_log")
	assert_true(CharacterData.from_dict(d).catch_log.is_empty())


func test_progress_between_ranks() -> void:
	assert_eq(Fishing.progress(0), 0.0)
	assert_eq(Fishing.progress(5), 0.5)
	assert_eq(Fishing.progress(10), 0.0)
	assert_eq(Fishing.progress(100), 1.0)
	assert_eq(Fishing.progress(250), 1.0)


## FISH-005: trophy entries.
func _trophy_table() -> Array:
	return [{"item": "", "weight": 1}, {"item": "mist_koi", "weight": 1, "min": 1, "max": 1, "trophy": true}]


func test_trophy_allowed_edges() -> void:
	assert_true(Fishing.trophy_allowed(1.0, 10))
	assert_false(Fishing.trophy_allowed(0.99, 10))
	assert_false(Fishing.trophy_allowed(1.0, 9))


func test_filter_trophy_keeps_or_drops_the_entry() -> void:
	var t := _trophy_table()
	assert_eq(Fishing.filter_trophy(t, 1.0, 10).size(), 2)
	assert_eq(Fishing.filter_trophy(t, 0.5, 10).size(), 1)
	assert_eq(Fishing.filter_trophy(t, 1.0, 9).size(), 1)
	var plain := [{"item": "", "weight": 1}, {"item": "silver_carp", "weight": 2}]
	assert_eq(Fishing.filter_trophy(plain, 0.0, 0), plain, "no trophy entry: unchanged")


func test_trophy_validation() -> void:
	var d := data()
	assert_eq(Fishing.validate_table(d, _trophy_table(), "x").size(), 0)
	var two := _trophy_table() + [{"item": "silver_carp", "weight": 1, "trophy": true}]
	assert_eq(Fishing.validate_table(d, two, "x").size(), 1)
	assert_eq(Fishing.validate_table(d, [{"item": "mist_koi", "weight": 3, "trophy": true}], "x").size(), 1)
	assert_eq(Fishing.validate_table(d, [{"item": "spirit_herb", "weight": 1, "trophy": true}], "x").size(), 1)


func test_trophy_near_miss_and_clean_strike() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := CharacterFactory.create("Angler", gs.data, seeded_rng(1))
	gs.start_session(c)
	gs.rng = seeded_rng(5)
	var table := [{"item": "mist_koi", "weight": 10, "min": 1, "max": 1, "trophy": true}]
	for i in 5:
		gs.fish(table, 1, "", 0.5)
	assert_eq(c.item_count("mist_koi"), 0, "an ordinary cast never lands the trophy")
	c.fishing_xp = 10
	gs.fish(table, 1, "", 1.0)
	assert_gt(c.item_count("mist_koi"), 0, "a clean strike by an Angler lands it")
