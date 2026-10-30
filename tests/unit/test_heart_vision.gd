extends TestCase
## HEART-001: the heart vision before a major breakthrough.


func _at_peak(realm: int = 1) -> CharacterData:
	var c := new_character()
	c.realm_index = realm
	c.stage = data().realms[realm].stage_count() - 1
	Cultivation.add_qi(c, data(), 1e15)
	return c


func test_no_vision_for_mid_realm_or_qi_refining_entry() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_true(HeartVision.vision(c, data()).is_empty(), "mid-realm")
	var m := _at_peak(0)
	assert_true(HeartVision.vision(m, data()).is_empty(), "Qi Refining entry has none")


func test_vision_at_qi_refining_peak() -> void:
	var c := _at_peak(1)
	var v := HeartVision.vision(c, data())
	assert_false(v.is_empty())
	assert_true(String(v["text"]).contains("a faceless figure"))
	assert_false(String(v["text"]).contains("{"))


func test_vision_names_the_rival() -> void:
	var c := _at_peak(1)
	var rival := new_character(77)
	rival.id = "rv"
	rival.name = "Lin Mo"
	c.rival = "rv"
	assert_true(String(HeartVision.vision(c, data(), {"rv": rival})["text"]).contains("Lin Mo"))


func test_choose_without_check_gives_bonus() -> void:
	var c := _at_peak(1)
	var r := HeartVision.choose(c, data(), 2, seeded_rng())
	assert_true(r["passed"])
	assert_almost_eq(c.heart_bonus, 0.0)
	assert_eq(c.heart_seen_realm, 2)


func test_choose_check_pass_and_fail() -> void:
	var passed := false
	var failed := false
	for s in 40:
		var c := _at_peak(1)
		c.attributes["comprehension"] = 14  # 90% clamp is not reached: chance 0.9 at target 14
		var r := HeartVision.choose(c, data(), 0, seeded_rng(s))
		if r["passed"]:
			passed = true
			assert_almost_eq(c.heart_bonus, 0.05)
		else:
			failed = true
			assert_almost_eq(c.heart_bonus, -0.03)
	assert_true(passed and failed)


func test_invalid_index_changes_nothing() -> void:
	var c := _at_peak(1)
	assert_true(HeartVision.choose(c, data(), 9, seeded_rng()).is_empty())
	assert_eq(c.heart_seen_realm, -1)


func test_breakdown_term_and_attempt_resets() -> void:
	var c := _at_peak(1)
	var before := Cultivation.breakthrough_chance(c, data())
	c.heart_bonus = 0.05
	assert_almost_eq(Cultivation.breakthrough_chance(c, data()), before + 0.05)
	assert_true(Cultivation.chance_breakdown(c, data()).any(func(t: Dictionary) -> bool: return t["label"] == "Heart steadied"))
	c.heart_bonus = -0.03
	assert_true(Cultivation.chance_breakdown(c, data()).any(func(t: Dictionary) -> bool: return t["label"] == "Heart shaken"))
	c.heart_seen_realm = 2
	Cultivation.attempt_breakthrough(c, data(), seeded_rng())
	assert_almost_eq(c.heart_bonus, 0.0)
	assert_eq(c.heart_seen_realm, 2)


func test_seen_vision_is_not_offered_again() -> void:
	var c := _at_peak(1)
	HeartVision.choose(c, data(), 2, seeded_rng())
	assert_true(HeartVision.vision(c, data()).is_empty())


func test_round_trip_and_old_saves() -> void:
	var c := _at_peak(1)
	c.heart_bonus = 0.05
	c.heart_seen_realm = 2
	var back := CharacterData.from_dict(c.to_dict())
	assert_almost_eq(back.heart_bonus, 0.05)
	assert_eq(back.heart_seen_realm, 2)
	var d := c.to_dict()
	d.erase("heart_bonus")
	d.erase("heart_seen_realm")
	var old := CharacterData.from_dict(d)
	assert_almost_eq(old.heart_bonus, 0.0)
	assert_eq(old.heart_seen_realm, -1)


func test_validation_rejects_bad_visions() -> void:
	var d := GameData.load_from_dir()
	var good: Dictionary = d.realms[2].heart_vision.duplicate(true)
	d.realms[2].heart_vision = good.duplicate(true)
	d.realms[2].heart_vision["choices"][0]["bonus"] = 0.3
	assert_gt(HeartVision.validate(d).size(), 0, "bonus 0.3")
	d.realms[2].heart_vision = good.duplicate(true)
	d.realms[2].heart_vision["choices"][2]["fail_bonus"] = -0.02
	assert_gt(HeartVision.validate(d).size(), 0, "fail_bonus without check")
	d.realms[2].heart_vision = good
	assert_eq(HeartVision.validate(d).size(), 0)


func _labels(c: CharacterData) -> Array:
	return HeartVision.vision(c, data())["choices"].map(func(ch: Dictionary) -> String: return ch["label"])


func test_choices_filtered_by_alignment() -> void:
	var c := _at_peak(1)
	c.alignment = -50
	assert_eq(_labels(c).size(), 4)
	assert_true(_labels(c).has("Embrace the hunger"))
	assert_false(_labels(c).has("Swear a vow to the righteous path"))
	c.alignment = 0
	assert_eq(_labels(c).size(), 3)
	c.alignment = 50
	assert_eq(_labels(c).size(), 4)
	assert_true(_labels(c).has("Swear a vow to the righteous path"))
	assert_false(_labels(c).has("Embrace the hunger"))


func test_every_vision_has_both_gated_choices() -> void:
	for realm in [1, 2, 3]:
		var def: Dictionary = data().realms[realm + 1].heart_vision
		var gated := 0
		for ch: Dictionary in def["choices"]:
			if ch.has("min_alignment") or ch.has("max_alignment"):
				gated += 1
		assert_eq(gated, 2, data().realms[realm + 1].id)


func test_demonic_choice_shifts_alignment_on_pass_or_fail() -> void:
	var c := _at_peak(1)
	c.alignment = -100
	assert_eq(_labels(c)[3], "Embrace the hunger")
	HeartVision.choose(c, data(), 3, seeded_rng())
	assert_eq(c.alignment, -103)


func test_hidden_index_is_refused() -> void:
	var c := _at_peak(1)
	c.alignment = 0
	assert_true(HeartVision.choose(c, data(), 3, seeded_rng()).is_empty())
	assert_eq(c.heart_seen_realm, -1)
	assert_eq(c.alignment, 0)


func test_vision_with_every_choice_hidden_is_skipped() -> void:
	var d := data()
	var realm = d.realms[2]
	var saved: Dictionary = realm.heart_vision
	realm.heart_vision = {"text": "x", "choices": [{"label": "a", "text": "a", "min_alignment": 500}]}
	var c := _at_peak(1)
	c.alignment = 0
	assert_true(HeartVision.vision(c, d).is_empty())
	realm.heart_vision = saved


func test_validation_flags_bad_alignment_ranges() -> void:
	var d := data()
	var realm = d.realms[2]
	var saved: Dictionary = realm.heart_vision
	var v: Dictionary = saved.duplicate(true)
	v["choices"][3]["min_alignment"] = 50
	v["choices"][3]["max_alignment"] = 10
	realm.heart_vision = v
	assert_gt(HeartVision.validate(d).size(), 0)
	v = saved.duplicate(true)
	v["choices"][3]["max_alignment"] = 5000
	realm.heart_vision = v
	assert_gt(HeartVision.validate(d).size(), 0)
	realm.heart_vision = saved
	assert_eq(HeartVision.validate(d).size(), 0)
