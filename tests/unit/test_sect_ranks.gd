extends TestCase
## Sect rank realm minimums, promotion trials, stipends and monthly duties (G-011).


## Fresh data whose Blood Lotus second rank needs a trial against a wild boar.
func _trial_data() -> GameData:
	var d := GameData.load_from_dir()
	(d.sects["blood_lotus_sect"] as SectDef).ranks[1]["trial"] = "wild_boar"
	return d


func _disciple(d: GameData) -> CharacterData:
	var c := CharacterFactory.create("Disciple", d, seeded_rng())
	c.alignment = -300
	assert_true(Sects.join(c, d, "blood_lotus_sect")["ok"])
	return c


func test_real_sect_ranks_are_valid() -> void:
	assert_eq(Sects.validate_ranks(data()).size(), 0, ", ".join(Sects.validate_ranks(data())))


func test_validation_catches_bad_rank_fields() -> void:
	var d := GameData.load_from_dir()
	var ranks := (d.sects["azure_cloud_sect"] as SectDef).ranks
	ranks[0]["trial"] = "wild_boar"
	ranks[1]["min_realm"] = "nowhere"
	ranks[2]["stipend"] = {"spirit_stones": -1, "items": {"no_such_item": 1}}
	ranks[3]["monthly_duty"] = -5
	assert_eq(Sects.validate_ranks(d).size(), 5)


func test_realm_minimum_holds_back_auto_promotion() -> void:
	var c := _disciple(data())
	Sects.add_contribution(c, data(), 3000)
	assert_eq(int(c.sect["rank"]), 1, "Blood Son needs Foundation Establishment")
	assert_true(Sects.check_promotion(c, data()).contains("Foundation"))
	c.realm_index = data().realm_index_of("foundation_establishment")
	var result := Sects.month_end(c, data())
	assert_true(result["promoted"], "a breakthrough unlocks the rank at month end")
	assert_eq(int(c.sect["rank"]), 2)


func test_trial_rank_is_never_automatic() -> void:
	var d := _trial_data()
	var c := _disciple(d)
	assert_false(Sects.add_contribution(c, d, 1000))
	assert_eq(int(c.sect["rank"]), 0)
	assert_eq(Sects.trial_enemy(c, d), "wild_boar")
	assert_eq(Sects.check_promotion(c, d), "")
	assert_true(Sects.pass_trial(c, d))
	assert_eq(int(c.sect["rank"]), 1)


func test_trial_needs_contribution_first() -> void:
	var d := _trial_data()
	var c := _disciple(d)
	assert_true(Sects.check_promotion(c, d).contains("contribution"))
	assert_false(Sects.pass_trial(c, d))
	assert_eq(int(c.sect["rank"]), 0)


func test_check_promotion_reasons() -> void:
	var c := new_character()
	assert_eq(Sects.check_promotion(c, data()), "Only sect disciples can be promoted.")
	c = _disciple(data())
	assert_true(Sects.check_promotion(c, data()).contains("contribution"))
	c.sect["rank"] = 3
	assert_eq(Sects.next_rank(c, data()), -1)
	assert_true(Sects.check_promotion(c, data()).contains("highest"))


func test_trial_opponent_is_a_harmless_spar() -> void:
	var enemy := Sects.trial_opponent(data(), "rogue_cultivator")
	assert_false(enemy["lethal"])
	assert_true(enemy["spar"])
	assert_true((enemy["rewards"] as Dictionary).is_empty())
	assert_true(data().enemies["rogue_cultivator"]["lethal"], "the enemy def is untouched")


func test_spar_defeat_takes_no_stones() -> void:
	var c := new_character()
	c.add_item("spirit_stone", 100)
	var stones := c.item_count("spirit_stone")
	var enemy := Sects.trial_opponent(data(), "wild_boar")
	var lost := {"victory": false, "draw": false, "talismans_used": []}
	var outcome := Combat.apply_outcome(c, data(), enemy, lost, {}, seeded_rng())
	assert_false(outcome["died"])
	assert_eq(c.item_count("spirit_stone"), stones)


func test_stipend_paid_when_duty_met() -> void:
	var c := _disciple(data())
	Sects.add_contribution(c, data(), 400)
	assert_eq(int(c.sect["rank"]), 1)
	Sects.month_end(c, data())  # month of promotion: duty waived
	var stones := c.item_count("spirit_stone")
	Sects.add_contribution(c, data(), Sects.monthly_duty(c, data()))
	var result := Sects.month_end(c, data())
	assert_true(result["paid"])
	assert_eq(c.item_count("spirit_stone"), stones + int(Sects.stipend(c, data())["spirit_stones"]))
	assert_eq(Sects.duty_progress(c), 0, "duty progress resets each month")


func test_missed_duty_withholds_stipend_without_demotion() -> void:
	var c := _disciple(data())
	Sects.add_contribution(c, data(), 400)
	Sects.month_end(c, data())
	var stones := c.item_count("spirit_stone")
	var result := Sects.month_end(c, data())
	assert_true(result["skipped"])
	assert_false(result["paid"])
	assert_eq(c.item_count("spirit_stone"), stones)
	assert_eq(int(c.sect["rank"]), 1)


func test_promotion_month_waives_duty() -> void:
	var c := _disciple(data())
	Sects.add_contribution(c, data(), 400)
	assert_true(Sects.month_end(c, data())["paid"])


func test_first_rank_has_no_stipend() -> void:
	var c := _disciple(data())
	var result := Sects.month_end(c, data())
	assert_false(result["paid"])
	assert_false(result["skipped"])


func test_stipend_items() -> void:
	var c := _disciple(data())
	c.realm_index = data().realm_index_of("foundation_establishment")
	Sects.add_contribution(c, data(), 2500)
	assert_eq(int(c.sect["rank"]), 2)
	var pills := c.item_count("blood_essence_pill")
	Sects.month_end(c, data())
	assert_eq(c.item_count("blood_essence_pill"), pills + 1)


func test_duty_state_survives_save() -> void:
	var c := _disciple(data())
	Sects.add_contribution(c, data(), 420)
	var loaded := CharacterData.from_dict(c.to_dict())
	assert_eq(Sects.duty_progress(loaded), 420)
	assert_true(bool(loaded.sect.get("duty_grace", false)))


func test_old_save_sect_loads_without_duty_fields() -> void:
	var d := new_character().to_dict()
	d["sect"] = {"id": "blood_lotus_sect", "rank": 1, "contribution": 450}
	var c := CharacterData.from_dict(d)
	assert_eq(Sects.duty_progress(c), 0)
	assert_true(Sects.month_end(c, data())["skipped"])
