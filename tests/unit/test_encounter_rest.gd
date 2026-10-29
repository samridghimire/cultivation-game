## ENC-010: fading happenings rest between repeats.
extends TestCase


func _beat(id: String = "rest_beat") -> Dictionary:
	return {"id": id, "tags": ["rest_tag"], "weight": 1, "text": "x", "effects": {}}


func test_rest_blocks_then_releases() -> void:
	var c := new_character()
	var d := data()
	var e := _beat()
	assert_eq(d.encounter_rest_days, 120)
	assert_false(Exploration.resting(c, d, e, 100), "never met")
	Exploration.note_met(c, e, 100)
	assert_true(Exploration.resting(c, d, e, 150))
	assert_false(Exploration.resting(c, d, e, 220))


func test_per_encounter_override_and_exemptions() -> void:
	var c := new_character()
	var d := data()
	for e: Dictionary in [{"id": "a", "rest_days": 0}, {"id": "b", "repeatable": true}, {"id": "c", "enemy": "wolf"}]:
		Exploration.note_met(c, e, 100)
		assert_false(Exploration.resting(c, d, e, 101), str(e))
	var longer := {"id": "d", "rest_days": 400}
	Exploration.note_met(c, longer, 100)
	assert_true(Exploration.resting(c, d, longer, 450))


func test_no_day_keeps_old_behaviour() -> void:
	var c := new_character()
	var e := _beat()
	Exploration.note_met(c, e, 100)
	assert_false(Exploration.resting(c, data(), e, -1))
	Exploration.note_met(c, _beat("other"))
	assert_false(c.encounter_last_day.has("other"))


func test_eligible_skips_resting() -> void:
	var d := data()
	var c := new_character()
	var e := _beat()
	d.encounters["rest_beat"] = e
	var ids := func(day: int) -> Array:
		return Exploration.eligible_encounters(c, d, ["rest_tag"], {}, null, 1.0, "", "", 0, Callable(), day).map(func(r: Dictionary) -> String: return r["encounter"]["id"])
	Exploration.note_met(c, e, 100)
	assert_true(ids.call(150).is_empty())
	assert_eq(ids.call(220), ["rest_beat"])
	assert_eq(ids.call(-1), ["rest_beat"])
	d.encounters.erase("rest_beat")


func test_last_day_round_trips() -> void:
	var c := new_character()
	c.encounter_last_day["x"] = 77
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.encounter_last_day, {"x": 77})
	var d := c.to_dict()
	d.erase("encounter_last_day")
	assert_eq(CharacterData.from_dict(d).encounter_last_day, {})


func test_validation_rejects_bad_rest_days() -> void:
	for bad: Variant in [-5, "soon", 2.5]:
		var d := GameData.load_from_dir()
		d.encounters.values()[0]["rest_days"] = bad
		d.load_errors.clear()
		d._validate()
		assert_true(Array(d.load_errors).any(func(m: String) -> bool: return m.contains("rest_days")), str(bad))


func test_game_state_does_not_repeat_a_beat_on_consecutive_days() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs: Node = root.get_node("GameState")
	var c := CharacterFactory.create("Rest", gs.data, seeded_rng(5))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	gs.data.encounters["t_rest_only"] = _beat("t_rest_only")
	gs.data.encounters["t_rest_only"]["tags"] = ["t_rest_only"]
	gs.world_flags["found_hermit_garden"] = true  # Qingshi's deeper path would stop the run
	gs.world_flags["discovered_" + String(gs.current_region)] = true
	assert_eq(gs.explore_many(7, ["t_rest_only"]), 1)
	assert_eq(int(gs.player.encounter_counts.get("t_rest_only", 0)), 1)
	assert_eq(gs.explore_many(3, ["t_rest_only"]), 3, "the beat is resting, so three quiet days")
	assert_eq(int(gs.player.encounter_counts.get("t_rest_only", 0)), 1, "still resting")
	gs.end_session()


func test_repeatable_with_rest_days_rests() -> void:
	var c := new_character()
	var d := data()
	var timed := {"id": "t", "repeatable": true, "rest_days": 60}
	var plain := {"id": "p", "repeatable": true}
	Exploration.note_met(c, timed, 100)
	Exploration.note_met(c, plain, 100)
	assert_true(Exploration.resting(c, d, timed, 159))
	assert_false(Exploration.resting(c, d, timed, 160))
	assert_false(Exploration.resting(c, d, plain, 101), "no rest_days: never rests")


func test_weather_gate_and_validation() -> void:
	var d := data()
	var region := d.start_region
	var rainy := -1
	var dry := -1
	for day in range(1, 400):
		if Weather.of(d, region, day) == "rain":
			rainy = day if rainy < 0 else rainy
		elif dry < 0:
			dry = day
	assert_gt(rainy, 0, "the start region rains some day")
	var e := {"id": "w", "weather": ["rain"]}
	assert_true(Exploration.weather_allows(d, e, region, rainy))
	assert_false(Exploration.weather_allows(d, e, region, dry))
	assert_true(Exploration.weather_allows(d, e, region, -1), "day < 0 ignores the gate")
	assert_true(Exploration.weather_allows(d, e, "", dry), "no region ignores the gate")
	assert_true(Exploration.weather_allows(d, {"id": "x"}, region, dry))
	var c := new_character()
	d.encounters["w_beat"] = {"id": "w_beat", "tags": ["rest_tag"], "weight": 1, "text": "x", "effects": {}, "weather": ["rain"]}
	var count := func(day: int) -> int:
		return Exploration.eligible_encounters(c, d, ["rest_tag"], {}, null, 1.0, "", region, 0, Callable(), day).size()
	assert_eq(count.call(rainy), 1)
	assert_eq(count.call(dry), 0)
	var bad := GameData.load_from_dir()
	var first: String = bad.encounters.keys()[0]
	bad.encounters[first]["weather"] = ["hail"]
	bad.load_errors.clear()
	bad._validate()
	assert_true(", ".join(bad.load_errors).contains("unknown weather"), str(bad.load_errors))
