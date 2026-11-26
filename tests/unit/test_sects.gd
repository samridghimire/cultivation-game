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


func test_trial_lessons_grow_cap_and_reset() -> void:
	var c := new_character()
	assert_eq(Sects.trial_lesson(c, data()), 0.0, "a rogue learns nothing")
	c.alignment = -300
	Sects.join(c, data(), "blood_lotus_sect")
	c.realm_index = data().realm_index_of("core_formation")
	Sects.add_contribution(c, data(), 100000)
	assert_eq(Sects.trial_lesson(c, data()), 0.0)
	var base: float = float(Sects.trial_opponent(data(), Sects.trial_enemy(c, data())).get("power_mult", 1.0))
	Sects.note_trial_loss(c)
	assert_almost_eq(Sects.trial_lesson(c, data()), 0.06, 0.0001)
	assert_almost_eq(float(Sects.trial_foe(c, data()).get("power_mult", 1.0)), base * 0.94, 0.0001)
	for i in 5:
		Sects.note_trial_loss(c)
	assert_almost_eq(Sects.trial_lesson(c, data()), 0.18, 0.0001, "capped")
	assert_true(Sects.pass_trial(c, data()))
	assert_eq(int(c.sect["trial_losses"]), 0, "promotion resets the lessons")
	assert_eq(Sects.trial_lesson(c, data()), 0.0)


func test_trial_foe_empty_without_trial() -> void:
	assert_true(Sects.trial_foe(new_character(), data()).is_empty())


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


## MISSION-003: a mission with max_realm is offered up to that realm and not above it.
func test_mission_max_realm() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	c.realm_index = d.realm_index_of("qi_refining")
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	var id: String = d.sect_missions.keys()[0]
	d.sect_missions[id] = (d.sect_missions[id] as Dictionary).duplicate()
	d.sect_missions[id]["max_realm"] = "qi_refining"
	d.sect_missions[id]["sects"] = []
	d.sect_missions[id].erase("min_realm")
	d.sect_missions[id].erase("min_stage")
	d.sect_missions[id].erase("requires_flag")
	assert_true(Sects.available_missions(c, d).has(id))
	c.realm_index = d.realm_index_of("qi_refining") + 1
	assert_false(Sects.available_missions(c, d).has(id))
	assert_true(Sects.check_mission(c, d, id).begins_with("Beneath you now") or Sects.check_mission(c, d, id) != "")
	assert_true(Sects.mission_rank_realm_reason(c, d, d.sect_missions[id]).begins_with("Beneath you now"))


func test_mission_max_realm_validation() -> void:
	var d := GameData.load_from_dir()
	var id: String = d.sect_missions.keys()[0]
	d.sect_missions[id] = (d.sect_missions[id] as Dictionary).duplicate()
	d.sect_missions[id]["max_realm"] = "nowhere"
	d.load_errors.clear()
	d._validate()
	assert_true(d.load_errors.size() > 0)
	d.sect_missions[id]["max_realm"] = "mortal"
	d.sect_missions[id]["min_realm"] = "qi_refining"
	d.load_errors.clear()
	d._validate()
	assert_true(d.load_errors.size() > 0)


## SECT-040: the trial advice names the biggest gap, in a fixed order.
func test_trial_advice_branches() -> void:
	var d := data()
	var c := new_character()
	assert_eq(Sects.trial_advice(c, d), "", "rogue: no trial")
	c.alignment = -300
	Sects.join(c, d, "blood_lotus_sect")
	var ranks := (d.sects["blood_lotus_sect"] as SectDef).ranks
	var had_trial = ranks[1].get("trial")
	ranks[1]["trial"] = "azure_sword_examiner"
	c.realm_index = d.realm_index_of("qi_refining")
	c.stage = 0
	c.injuries = {"broken_ribs": 5}
	assert_eq(Sects.trial_advice(c, d), "Heal first: you are injured.")
	c.injuries.clear()
	c.realm_index = 0
	assert_true(Sects.trial_advice(c, d).begins_with("The examiner is at "), "below the foe's realm")
	assert_true(Sects.trial_advice(c, d).ends_with("reach it first."))
	c.realm_index = d.realm_index_of("qi_refining")
	c.techniques.clear()
	var line := Sects.trial_advice(c, d)
	assert_true(line.begins_with("Learn an attack technique; the examiner uses "), line)
	c.techniques = {"metal_edge_sword": {"level": 1, "xp": 0.0}}
	assert_eq(Sects.trial_advice(c, d), "Close: train a few more days and try again.")
	# WU-630: items, capped, priority order, armor and meal only after the main gap is closed
	c.equipment["armor"] = ""
	c.buffs.clear()
	var items := Sects.trial_advice_items(c, d)
	assert_eq(items.size(), 2)
	assert_eq(items[0], Sects.trial_advice(c, d))
	assert_true(items[1].begins_with("Wear armor"), items[1])
	assert_eq(Sects.trial_advice_items(c, d, 3).size(), 3)
	c.injuries = {"broken_ribs": 5}
	assert_eq(Sects.trial_advice_items(c, d).size(), 1, "heal first stands alone")
	c.injuries.clear()
	if had_trial == null:
		ranks[1].erase("trial")
	else:
		ranks[1]["trial"] = had_trial


# --- SECT-038: the outer-sect contest -----------------------------------------

func _contest_day(sect_id: String = "azure_cloud_sect") -> int:
	return (int(data().sects[sect_id].contest["month"]) - 1) * Calendar.DAYS_PER_MONTH


func _contest_member() -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	Sects.join(c, data(), "azure_cloud_sect")
	return c


func test_contest_open_only_in_its_month_once_a_year() -> void:
	var c := _contest_member()
	c.sect["reported"] = true
	var day := _contest_day()
	assert_true(Sects.contest_open(c, data(), day))
	assert_false(Sects.contest_open(c, data(), day + Calendar.DAYS_PER_MONTH), "next month")
	Sects.enter_contest(c, data(), day)
	assert_false(Sects.contest_open(c, data(), day + 3), "entered this year")
	assert_true(Sects.contest_open(c, data(), day + Calendar.DAYS_PER_YEAR), "next year")


func test_contest_refuses_rogue_rank_two_and_unreported() -> void:
	var rogue := new_character()
	assert_false(Sects.contest_open(rogue, data(), _contest_day()))
	var c := _contest_member()
	c.sect["reported"] = false
	assert_false(Sects.contest_open(c, data(), _contest_day()))
	c.sect["reported"] = true
	c.sect["rank"] = 2
	assert_false(Sects.contest_open(c, data(), _contest_day()))


func test_contest_rounds_in_order_and_validated() -> void:
	var c := _contest_member()
	var def: Dictionary = data().sects["azure_cloud_sect"].contest
	assert_eq(Sects.contest_round(c, data(), 0)["foe"], def["foes"][0])
	assert_true(Sects.contest_round(c, data(), int(def["rounds"])).is_empty())
	assert_eq(Sects.validate_contests(data()).size(), 0)


var _contest_snapshot: Dictionary = {}


func test_contest_power_mults_default_and_validation() -> void:
	_contest_snapshot = (data().sects["azure_cloud_sect"] as SectDef).contest.duplicate(true)
	var c := _contest_member()
	var d := data()
	var sect: SectDef = d.sects["azure_cloud_sect"]
	var original := sect.contest
	var def := original.duplicate(true)  # SECT-049: edit a copy, never the shared def
	sect.contest = def
	def.erase("power_mults")
	assert_eq(Sects.contest_round(c, d, 0)["power_mult"], 1.0)
	def["power_mults"] = [0.8, 1.2, 1.5]
	assert_eq(Sects.contest_round(c, d, 1)["power_mult"], 1.2)
	assert_eq(Sects.validate_contests(d).size(), 0)
	def["power_mults"] = [1.0, 1.0]
	assert_true(Sects.validate_contests(d).size() > 0, "wrong length")
	def["power_mults"] = [1.0, 2.5, 1.0]
	assert_true(Sects.validate_contests(d).size() > 0, "out of range")
	def["power_mults"] = [1.0, 0.1, 1.0]
	assert_true(Sects.validate_contests(d).size() > 0, "too low")
	sect.contest = original
	assert_eq(original, _contest_snapshot, "the shared def is unchanged")
	var foe := Sects.trial_opponent(d, "village_boxer", 1.5)
	assert_eq(float(foe["power_mult"]), float(d.enemies["village_boxer"].get("power_mult", 1.0)) * 1.5)


func test_contest_entry_survives_leaving_and_rejoining() -> void:
	var c := _contest_member()
	c.sect["reported"] = true
	var day := _contest_day()
	Sects.enter_contest(c, data(), day)
	Sects.leave(c)
	Sects.join(c, data(), "azure_cloud_sect")
	c.sect["reported"] = true
	assert_false(Sects.contest_open(c, data(), day + 2), "same year, new membership")
	assert_true(Sects.contest_open(c, data(), day + Calendar.DAYS_PER_YEAR), "next year")


func test_last_contest_year_round_trips_and_defaults() -> void:
	var c := new_character()
	c.last_contest_year = 3
	assert_eq(CharacterData.from_dict(c.to_dict()).last_contest_year, 3)
	var d := c.to_dict()
	d.erase("last_contest_year")
	assert_eq(CharacterData.from_dict(d).last_contest_year, -1)
	d["sect"] = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "contest_year": 5}
	assert_eq(CharacterData.from_dict(d).last_contest_year, 5, "an old save falls back to the sect's year")


func test_contest_prize_pays_stones_and_contribution() -> void:
	var c := _contest_member()
	var stones_before := c.item_count("spirit_stone")
	Sects.pay_contest_prize(c, data(), {"contribution": 12, "spirit_stones": 7})
	assert_eq(c.item_count("spirit_stone"), stones_before + 7)
	assert_eq(int(c.sect["contribution"]), 12)


## RV-SECT038: a prize that crosses a trial-free rank threshold reports the promotion so GameState can announce it.
func test_contest_prize_reports_a_promotion() -> void:
	var c := _contest_member()
	assert_false(Sects.pay_contest_prize(c, data(), {"contribution": 10, "spirit_stones": 0}), "rank 1 needs its trial")
	var ranks: Array = data().sects["azure_cloud_sect"].ranks
	var had_trial: Variant = ranks[1].get("trial")
	ranks[1].erase("trial")
	c.sect["contribution"] = int(ranks[1]["contribution"]) - 5
	var promoted := Sects.pay_contest_prize(c, data(), {"contribution": 10, "spirit_stones": 0})
	ranks[1]["trial"] = had_trial
	assert_true(promoted)
	assert_eq(int(c.sect["rank"]), 1)


# --- WU-621: the contest line ---------------------------------------------------

func test_contest_line_before_during_after_entering() -> void:
	var c := _contest_member()
	c.sect["reported"] = true
	var day := _contest_day()
	assert_eq(Sects.contest_line(c, data(), day - 10), "Contest: month 3 (in 10 days)")
	assert_true(Sects.contest_line(c, data(), day + 1).begins_with("Contest: open now at the "))
	Sects.enter_contest(c, data(), day + 1)
	assert_eq(Sects.contest_line(c, data(), day + 2), "Contest: already entered this year")
	assert_eq(Sects.contest_line(c, data(), day + 40), "Contest: month 3 (in %d days)" % (day + Calendar.DAYS_PER_YEAR - day - 40))
	var d := new_character()
	d.realm_index = 1
	Sects.join(d, data(), "azure_cloud_sect")
	d.sect["reported"] = true
	d.sect["rank"] = 2
	var sect: SectDef = data().sects["azure_cloud_sect"]
	var saved := sect.inner_contest
	sect.inner_contest = {}  # SECT-045: without an inner block rank 2 is still barred
	assert_eq(Sects.contest_line(d, data(), day + 1), "Contest: for the first two ranks")
	sect.inner_contest = saved


func test_contest_line_absent_for_rogue() -> void:
	assert_eq(Sects.contest_line(new_character(), data(), 5), "")


# --- SECT-045: the inner-sect contest ------------------------------------------

func _inner_member(sect_id: String = "azure_cloud_sect") -> CharacterData:
	var c := new_character()
	c.realm_index = 2
	Sects.join(c, data(), sect_id)
	c.sect["reported"] = true
	return c


func test_rank_picks_outer_or_inner_block() -> void:
	var c := _inner_member()
	var sect: SectDef = data().sects["azure_cloud_sect"]
	assert_true(sect.inner_contest.size() > 0)
	c.sect["rank"] = 1
	assert_eq(Sects.contest_def(c, data()), sect.contest, "rank 1 sees the outer block")
	assert_eq(Sects.contest_round(c, data(), 0)["foe"], sect.contest["foes"][0])
	c.sect["rank"] = 2
	assert_eq(Sects.contest_def(c, data()), sect.inner_contest, "rank 2 sees the inner block")
	assert_eq(Sects.contest_round(c, data(), 0)["foe"], sect.inner_contest["foes"][0])
	assert_eq(Sects.contest_name(c, data()), "inner-sect contest")


func test_inner_contest_open_in_its_own_month_once_a_year() -> void:
	var c := _inner_member()
	c.sect["rank"] = 2
	var sect: SectDef = data().sects["azure_cloud_sect"]
	var day := (int(sect.inner_contest["month"]) - 1) * Calendar.DAYS_PER_MONTH
	assert_true(Sects.contest_open(c, data(), day))
	assert_false(Sects.contest_open(c, data(), (int(sect.contest["month"]) - 1) * Calendar.DAYS_PER_MONTH), "not the outer month")
	assert_true(Sects.contest_line(c, data(), day).begins_with("Inner-sect contest: open now"))
	Sects.enter_contest(c, data(), day)
	assert_false(Sects.contest_open(c, data(), day + 3))


func test_inner_prizes_beat_outer_and_validate() -> void:
	for sect: SectDef in data().sects.values():
		if sect.contest.is_empty():
			continue
		assert_false(sect.inner_contest.is_empty(), "%s holds an inner contest" % sect.id)
		assert_true(int(sect.inner_contest["prizes"][-1]["contribution"]) >= 2 * int(sect.contest["prizes"][-1]["contribution"]), sect.id)
	assert_eq(Sects.validate_contests(data()).size(), 0)


func test_sect_without_inner_contest_refuses_rank_two() -> void:
	var c := _inner_member()
	c.sect["rank"] = 2
	var sect: SectDef = data().sects["azure_cloud_sect"]
	var saved := sect.inner_contest
	sect.inner_contest = {}
	var day := (int(sect.contest["month"]) - 1) * Calendar.DAYS_PER_MONTH
	assert_eq(Sects.check_contest(c, data(), day), "The outer-sect contest is for disciples of the first two ranks.")
	sect.inner_contest = saved


# --- SECT-049: contest reason codes ---------------------------------------------

func test_contest_check_reason_codes_and_line() -> void:
	var day := _contest_day()
	var rogue := new_character()
	assert_eq(Sects.contest_check(rogue, data(), day)["reason"], "not_member")
	var c := _contest_member()
	c.sect["reported"] = true
	assert_eq(Sects.contest_check(c, data(), day)["reason"], "ok")
	assert_eq(Sects.contest_check(c, data(), day)["message"], "")
	assert_eq(Sects.contest_check(c, data(), day - Calendar.DAYS_PER_MONTH)["reason"], "wrong_month")
	assert_true(Sects.contest_line(c, data(), day - Calendar.DAYS_PER_MONTH).begins_with("Contest: month"))
	c.sect["reported"] = false
	assert_eq(Sects.contest_check(c, data(), day)["reason"], "need_report")
	assert_eq(Sects.contest_line(c, data(), day), "Contest: Report to the hall first.")
	c.sect["reported"] = true
	Sects.enter_contest(c, data(), day)
	assert_eq(Sects.contest_check(c, data(), day + 1)["reason"], "already_entered")
	assert_eq(Sects.contest_line(c, data(), day + 1), "Contest: already entered this year")
	var d := _contest_member()
	d.sect["reported"] = true
	d.sect["rank"] = 2
	var sect: SectDef = data().sects["azure_cloud_sect"]
	var saved := sect.inner_contest
	sect.inner_contest = {}
	assert_eq(Sects.contest_check(d, data(), day)["reason"], "rank_too_high")
	assert_eq(Sects.contest_line(d, data(), day), "Contest: for the first two ranks")
	sect.inner_contest = saved


# --- SECT-052: outer and inner contest records kept apart -----------------------

func test_outer_entry_does_not_bar_inner_same_year() -> void:
	var c := _inner_member()
	var sect: SectDef = data().sects["azure_cloud_sect"]
	c.sect["rank"] = 1
	var outer_day := (int(sect.contest["month"]) - 1) * Calendar.DAYS_PER_MONTH
	Sects.enter_contest(c, data(), outer_day)
	c.sect["rank"] = 2
	var inner_day := (int(sect.inner_contest["month"]) - 1) * Calendar.DAYS_PER_MONTH
	assert_eq(Calendar.year_of(outer_day), Calendar.year_of(inner_day))
	assert_true(Sects.contest_open(c, data(), inner_day), "the inner contest is open after an outer entry")
	Sects.enter_contest(c, data(), inner_day)
	assert_false(Sects.contest_open(c, data(), inner_day + 3), "inner twice in a year is refused")
	assert_eq(int(c.contest_years["outer"]), Calendar.year_of(outer_day))


func test_inner_record_apart_from_outer() -> void:
	var c := _inner_member()
	c.sect["rank"] = 1
	Sects.record_contest(c, data(), 2, 3, 100)
	c.sect["rank"] = 2
	assert_eq(Sects.contest_record_line(c, data()), "", "nothing entered at this tier")
	assert_eq(Sects.contest_record(c, data(), "outer")["best_round"], 2)
	assert_eq(Sects.contest_win_line(c, data()), "")
	var rounds := int(Sects.contest_def(c, data()).get("rounds", 3))
	assert_true(Sects.record_contest(c, data(), rounds, rounds, 500))
	assert_eq(Sects.contest_record(c, data(), "outer")["best_round"], 2, "outer record untouched")
	assert_true(Sects.contest_record_line(c, data()).begins_with("Inner-sect contest record: best round %d" % rounds))
	assert_true(Sects.contest_win_line(c, data()).contains("inner-sect contest in year %d" % Calendar.year_of(500)))


func test_old_flat_contest_record_migrates_to_outer() -> void:
	var d := new_character().to_dict()
	d["contest_record"] = {"best_round": 2, "last_year": 3, "sect": "azure_cloud_sect"}
	d["last_contest_year"] = 3
	d.erase("contest_years")
	var back := CharacterData.from_dict(d)
	assert_eq(back.contest_record["outer"]["best_round"], 2)
	assert_eq(back.contest_record["outer"]["last_year"], 3)
	assert_eq(back.contest_years, {"outer": 3})
