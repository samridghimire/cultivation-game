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


func test_needs_trial_and_rank_requirement_reason() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	assert_false(Sects.needs_trial(c, d), "a rogue has no trial")
	assert_eq(Sects.rank_requirement_reason(c, d), "")
	c.alignment = -300
	Sects.join(c, d, "blood_lotus_sect")
	var sect: SectDef = d.sects["blood_lotus_sect"]
	assert_true(Sects.needs_trial(c, d), "the next rank has a trial")
	assert_true(Sects.rank_requirement_reason(c, d).contains("contribution"))
	sect.ranks[1].erase("trial")
	assert_false(Sects.needs_trial(c, d), "a trial-free next rank")
	c.sect["rank"] = sect.ranks.size() - 1
	assert_false(Sects.needs_trial(c, d), "top rank")
	assert_eq(Sects.rank_requirement_reason(c, d), "")


## TRAV-004: sects name a home region.
func test_sect_home_regions() -> void:
	var d := data()
	assert_eq(Sects.home_region(d, "azure_cloud_sect"), "azure_peak")
	assert_eq(Sects.home_region(d, "blood_lotus_sect"), "withered_bone_marsh")
	assert_eq(Sects.home_region(d, "myriad_treasure_pavilion"), "fallen_star_market")
	assert_eq(Sects.home_region(d, ""), "")
	assert_eq(Sects.home_region(d, "nope"), "")


func test_backfill_visits_home_region_only() -> void:
	var d := data()
	var c := new_character()
	c.sect = {"id": "blood_lotus_sect", "rank": 0}
	Exploration.backfill_visited(c, d, {})
	assert_true(c.visited_regions.has("withered_bone_marsh"))
	assert_false(c.visited_regions.has("azure_peak"))


func test_unknown_home_region_is_rejected() -> void:
	var d := GameData.load_from_dir()
	d.sects["azure_cloud_sect"].home_region = "nowhere"
	d.load_errors.clear()
	d._validate()
	assert_true(d.load_errors.size() > 0)


## C-063: a typical player (Iron Fist + Stone Skin, best buyable gear) at the gate of
## every rank-0 fight mission is not rated Dangerous or Deadly.
func test_rank_zero_fight_missions_are_fair_at_their_gate() -> void:
	var Balance := preload("res://tests/sim/combat_balance.gd")
	var d := data()
	var checked := 0
	for id: String in d.sect_missions:
		var m: Dictionary = d.sect_missions[id]
		var enemy_id := String(m.get("enemy", ""))
		if int(m.get("min_rank", 0)) != 0 or enemy_id == "":
			continue
		var realm_index := d.realm_index_of(String(m.get("min_realm", "")))
		var c: CharacterData = Balance.typical_player(d, realm_index, int(m.get("min_stage", 0)))
		var danger := Sects.mission_danger(c, d, id)
		assert_false(danger in ["Dangerous", "Deadly"], "%s is rated %s for a typical player at its gate" % [id, danger])
		checked += 1
	assert_true(checked > 0, "some rank-0 fight mission was checked")


## GUIDE-119: items a takeable deliver mission waits on are listed; rogues, rank gaps and cooldowns list nothing.
func test_deliver_needs() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_eq(Sects.deliver_needs(c, data()), {}, "rogue")
	Sects.join(c, data(), "azure_cloud_sect")
	var needs := Sects.deliver_needs(c, data())
	assert_true(int(needs.get("bone_setting_salve", 0)) >= 2)
	assert_true(int(needs.get("spirit_herb", 0)) >= 3)
	assert_false(needs.has("blood_ginseng"), "another sect's tithe")
	for id: String in Sects.available_missions(c, data()):
		c.mission_cooldowns[id] = c.age_days + 100
	assert_eq(Sects.deliver_needs(c, data()), {}, "all on cooldown")


func test_membership_perks_azure_qr8_rogue() -> void:
	var c := new_character()
	c.realm_index = 1
	c.stage = 7
	var sect: SectDef = data().sects["azure_cloud_sect"]
	var perks := Sects.membership_perks(c, data(), "azure_cloud_sect")
	assert_eq(perks[0], "gather qi x%s" % String.num(sect.cultivation_bonus, 1))
	assert_eq(perks[1], "hear %s each month" % sect.lecture["name"])
	var pill := Sects.best_breakthrough_entry(data(), sect.shop, data().realms[2].id)
	if pill.is_empty():
		assert_eq(perks.size(), 2)
	else:
		assert_eq(perks.size(), 3)
		assert_true(perks[2].begins_with("can claim"), perks[2])
	assert_true(Sects.membership_line(c, data(), "azure_cloud_sect").begins_with("Members gather qi x"))


func test_membership_perks_skip_pill_gated_by_realm() -> void:
	var c := new_character()
	c.realm_index = 1
	for p in Sects.membership_perks(c, data(), "azure_cloud_sect"):
		assert_false(p.contains("Core"), p)
	c.realm_index = 2
	var core_perk := false
	for p in Sects.membership_perks(c, data(), "azure_cloud_sect"):
		core_perk = core_perk or p.contains("Core Forming Pill")
	assert_true(core_perk, "C-260: a Foundation member can claim the Core pill")


func test_membership_perks_myriad_and_unknown() -> void:
	var c := new_character()
	c.realm_index = 1
	assert_eq(Sects.membership_perks(c, data(), "myriad_treasure_pavilion")[0], "gather qi x1.2")
	assert_true(Sects.membership_perks(c, data(), "nope").is_empty())
	assert_eq(Sects.membership_line(c, data(), "nope"), "")


## GUIDE-181: rank_needs lists every unmet need of the next rank.
func test_rank_needs_lists_every_unmet_need() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	assert_eq(Sects.rank_needs(c, d).size(), 0, "a rogue")
	c.sect = {"id": "azure_cloud_sect", "rank": 1, "contribution": 120, "spent": 0}
	c.realm_index = 1
	var needs := Sects.rank_needs(c, d)
	assert_eq(needs.size(), 2)
	assert_eq(needs[0], "earn 3000 contribution (you have 120)")
	assert_true(needs[1].begins_with("reach "), needs[1])
	c.sect["contribution"] = 3000
	assert_eq(Sects.rank_needs(c, d).size(), 1, "contribution met")
	c.sect["contribution"] = 120
	c.realm_index = 2
	assert_eq(Sects.rank_needs(c, d).size(), 1, "realm met")
	c.sect["contribution"] = 3000
	assert_eq(Sects.rank_needs(c, d).size(), 0)
	c.sect["rank"] = (d.sects["azure_cloud_sect"] as SectDef).ranks.size() - 1
	assert_eq(Sects.rank_needs(c, d).size(), 0, "highest rank")
