extends TestCase


func test_new_character_is_rogue() -> void:
	assert_true(new_character().is_rogue())


func test_righteous_sect_requires_qi_refining() -> void:
	var c := new_character()
	assert_false(Sects.check_join(c, data(), "azure_cloud_sect")["ok"])
	c.realm_index = 1
	assert_true(Sects.join(c, data(), "azure_cloud_sect")["ok"])
	assert_eq(c.sect["id"], "azure_cloud_sect")


func test_righteous_sect_rejects_evil() -> void:
	var c := new_character()
	c.realm_index = 1
	c.alignment = -500
	assert_false(Sects.check_join(c, data(), "azure_cloud_sect")["ok"])


func test_demonic_sect_rejects_the_virtuous() -> void:
	var c := new_character()
	c.alignment = 300
	assert_false(Sects.check_join(c, data(), "blood_lotus_sect")["ok"])
	c.alignment = -300
	assert_true(Sects.check_join(c, data(), "blood_lotus_sect")["ok"])


func test_cannot_join_two_sects() -> void:
	var c := new_character()
	c.alignment = -300
	Sects.join(c, data(), "blood_lotus_sect")
	assert_false(Sects.check_join(c, data(), "blood_lotus_sect")["ok"])


func test_contribution_promotes() -> void:
	var d := GameData.load_from_dir()
	for rank: Dictionary in (d.sects["blood_lotus_sect"] as SectDef).ranks:
		rank.erase("trial")
	var c := new_character()
	c.alignment = -300
	Sects.join(c, d, "blood_lotus_sect")
	c.realm_index = d.realm_index_of("core_formation")  # high ranks have realm minimums
	var promoted := Sects.add_contribution(c, d, 100000)
	assert_true(promoted)
	assert_eq(c.sect["rank"], d.sects["blood_lotus_sect"].ranks.size() - 1)


func test_contribution_stops_at_a_trial_rank() -> void:
	var c := new_character()
	c.alignment = -300
	Sects.join(c, data(), "blood_lotus_sect")
	c.realm_index = data().realm_index_of("core_formation")
	assert_false(Sects.add_contribution(c, data(), 100000))
	assert_eq(int(c.sect["rank"]), 0)
	assert_eq(Sects.check_promotion(c, data()), "", "the trial is open")


func test_leave_returns_to_rogue() -> void:
	var c := new_character()
	c.alignment = -300
	Sects.join(c, data(), "blood_lotus_sect")
	assert_eq(Sects.leave(c), "blood_lotus_sect")
	assert_true(c.is_rogue())
	assert_eq(Sects.cultivation_bonus(c, data()), 1.0)


func _duty_member(month_earned: int = 0) -> CharacterData:
	var c := new_character()
	c.realm_index = 2
	for sect: SectDef in data().sects.values():
		for r in sect.ranks.size():
			if c.is_rogue() and int(sect.ranks[r].get("monthly_duty", 0)) > 0:
				c.sect = {"id": sect.id, "rank": r, "contribution": 0, "spent": 0, "month_earned": month_earned}
	return c


func test_duty_days_left_at_month_start_and_end() -> void:
	var c := new_character()
	c.age_days = 30 * 100
	assert_eq(Sects.duty_days_left(c), 30)
	c.age_days += 29
	assert_eq(Sects.duty_days_left(c), 1)


func test_duty_reminder_text_and_empty_cases() -> void:
	var c := _duty_member(10)
	c.age_days = 30 * 100 + 25
	var duty := Sects.monthly_duty(c, data())
	assert_eq(Sects.duty_reminder(c, data()), "Your sect duty is 10 / %d contribution with 5 days left this month." % duty)
	c.sect["month_earned"] = duty
	assert_eq(Sects.duty_reminder(c, data()), "")
	c.sect["month_earned"] = 0
	c.sect["duty_grace"] = true
	assert_eq(Sects.duty_reminder(c, data()), "")
	assert_eq(Sects.duty_reminder(new_character(), data()), "")


func test_hints_show_duty_only_within_seven_days() -> void:
	var c := _duty_member()
	c.age_days = 30 * 100 + 10
	var early := Guidance.hints(c, data(), 1.0, 99)
	for h in early:
		assert_false(h.begins_with("Your sect duty"))
	c.age_days = 30 * 100 + 23
	var late := Guidance.hints(c, data(), 1.0, 99)
	var found := false
	for h in late:
		found = found or h.begins_with("Your sect duty")
	assert_true(found)


func _staged_rank_data() -> GameData:
	var d := GameData.load_from_dir()
	var ranks: Array = (d.sects["blood_lotus_sect"] as SectDef).ranks
	for rank: Dictionary in ranks:
		rank.erase("trial")
	ranks[1]["min_realm"] = "foundation_establishment"
	ranks[1]["min_stage"] = 3
	return d


func test_rank_min_stage_gates_promotion() -> void:
	var d := _staged_rank_data()
	var c := new_character()
	c.alignment = -300
	Sects.join(c, d, "blood_lotus_sect")
	c.realm_index = d.realm_index_of("foundation_establishment")
	c.stage = 0
	assert_false(Sects.add_contribution(c, d, 100000), "auto_promote stops at the staged rank")
	assert_eq(int(c.sect["rank"]), 0)
	var reason := Sects._rank_requirement_reason(c, d, 1)
	assert_true(reason.contains(d.realms[c.realm_index].stage_label(3)), reason)
	c.stage = 3
	assert_eq(Sects._rank_requirement_reason(c, d, 1), "")
	assert_true(Sects.auto_promote(c, d))
	assert_true(int(c.sect["rank"]) >= 1)


func test_rank_min_stage_validation() -> void:
	var d := _staged_rank_data()
	assert_eq(Sects.validate_ranks(d).size(), 0)
	(d.sects["blood_lotus_sect"] as SectDef).ranks[1]["min_stage"] = 99
	assert_true(Sects.validate_ranks(d).size() > 0)
