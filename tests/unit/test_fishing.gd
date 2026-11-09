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
	assert_eq(Fishing.missing_hint(c, d, "misty_forest", "Summer"), "Lotus Bass bites here in summer.")
	Fishing.record_catch(c, "lotus_bass", 1)
	assert_eq(Fishing.missing_hint(c, d, "misty_forest", "Summer"), "Rain Bream bites here when it rains.")  # MARKET-005
	Fishing.record_catch(c, "rain_bream", 1)
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


## Review: a denied trophy draw loses only the trophy, not the rest of the trip's catch.
func test_trophy_near_miss_keeps_the_other_fish() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := CharacterFactory.create("Angler", gs.data, seeded_rng(1))
	gs.start_session(c)
	gs.rng = seeded_rng(5)
	var table := [{"item": "silver_carp", "weight": 10, "min": 1, "max": 1}, {"item": "mist_koi", "weight": 10, "min": 1, "max": 1, "trophy": true}]
	for i in 6:
		gs.fish(table, 1, "", 0.5)
	assert_eq(c.item_count("mist_koi"), 0, "no trophy without a clean strike")
	assert_gt(c.item_count("silver_carp"), 0, "the ordinary fish of a trip that drew the trophy are kept")


## FISH-006: rain on the water.
func test_filter_weather_keeps_matching_entries() -> void:
	var table := [{"item": "", "weight": 1}, {"item": "silver_carp", "weight": 1, "weather": ["rain"]}]
	assert_eq(Fishing.filter_weather(table, "clear").size(), 1)
	assert_eq(Fishing.filter_weather(table, "rain").size(), 2)


func test_extra_draws_only_on_rain() -> void:
	var data := GameData.new()
	data.fishing_rules = {"rain_extra_draws": 2}
	assert_eq(Fishing.extra_draws(data, "rain"), 2)
	assert_eq(Fishing.extra_draws(data, "clear"), 0)
	data.fishing_rules = {}
	assert_eq(Fishing.extra_draws(data, "rain"), 1, "default is one")


func test_validate_weather_and_rules() -> void:
	assert_eq(Fishing.validate_weather([{"item": "x", "weather": ["rain"]}], "p").size(), 0)
	assert_eq(Fishing.validate_weather([{"item": "x", "weather": ["hail"]}], "p").size(), 1)
	assert_eq(Fishing.validate_weather([{"item": "x", "weather": []}], "p").size(), 1)
	var errors: Array[String] = []
	Fishing.validate_rules({"rain_extra_draws": 9}, errors)
	assert_eq(errors.size(), 1)


func test_every_fishing_place_has_a_rain_only_fish() -> void:  # C-283
	var d := data()
	var places := 0
	for rid: String in d.regions:
		var rain_ok: bool = d.regions[rid].get("weather", {}).values().any(func(w: Dictionary) -> bool: return w.has("rain"))
		for place: Dictionary in d.regions[rid].get("places", []):
			if String(place.get("type", "")) != "fishing":
				continue
			places += 1
			var found := false
			for e: Dictionary in place.get("catch_table", []):
				if e.get("weather", []) == ["rain"]:
					found = true
			assert_true(found, "%s: no rain-only fish" % rid)
			assert_true(rain_ok, "%s: rains never fall, so the rain fish is unreachable" % rid)
	assert_eq(places, 5)


## FISH-007: rank bonus draws and perk lines.
func test_bonus_draws_by_rank() -> void:
	for seed_i in 20:
		assert_eq(Fishing.bonus_draws(0, seeded_rng(seed_i)), 0)
		assert_eq(Fishing.bonus_draws(100, seeded_rng(seed_i)), 1)
	var rng := seeded_rng(5)
	var angler := 0
	var hand := 0
	for i in 400:
		angler += Fishing.bonus_draws(10, rng)
		hand += Fishing.bonus_draws(40, rng)
	assert_true(absf(angler / 400.0 - 0.25) < 0.06, "Angler about 25%%, got %d/400" % angler)
	assert_true(absf(hand / 400.0 - 0.5) < 0.06, "Old Hand about 50%%, got %d/400" % hand)


func test_rank_perk_text() -> void:
	assert_eq(Fishing.rank_perk(0), "")
	assert_eq(Fishing.rank_perk(10), "An Angler lands an extra fish one trip in four.")
	assert_eq(Fishing.rank_perk(40), "An Old Hand lands an extra fish every other trip.")
	assert_eq(Fishing.rank_perk(100), "A Master always lands an extra fish.")


func test_master_lands_extra_fish_and_rank_up_names_perk() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var table := [{"item": "silver_carp", "weight": 1, "min": 1, "max": 1}]
	var c := CharacterFactory.create("Angler", gs.data, seeded_rng(1))
	gs.start_session(c)
	var weather: String = Weather.of(gs.data, gs.current_region, GameClock.total_days)
	if Fishing.too_wild(weather) or weather == "rain":
		gs.end_session()
		return
	c.fishing_xp = 100
	var before := c.item_count("silver_carp")
	gs.fish(table, 1, "", 0.5)
	assert_eq(c.item_count("silver_carp") - before, 2 * Exploration.GATHER_ROLLS, "a Master makes one bonus draw on top of the normal one")
	gs.end_session()
	var c2 := CharacterFactory.create("Angler", gs.data, seeded_rng(1))
	gs.start_session(c2)
	c2.fishing_xp = 9
	var seen := [""]
	var cb := func(text: String, _cat: String) -> void:
		if text.begins_with("Your fishing has improved"):
			seen[0] = text
	EventBus.message_posted.connect(cb)
	gs.fish(table, 1, "", 0.5)
	EventBus.message_posted.disconnect(cb)
	gs.end_session()
	if not Fishing.too_wild(weather):
		assert_true(String(seen[0]).contains("An Angler lands an extra fish"), "rank-up shows perk: %s" % seen[0])
