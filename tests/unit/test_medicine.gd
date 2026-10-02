extends TestCase


func _doctor(rank: int = 0) -> CharacterData:
	var c := new_character()
	c.attributes["spirit"] = 10
	if rank > 0:
		c.professions["doctor"] = {"rank": rank, "xp": 0.0}
	return c


func test_self_treatment_reduces_injury_and_trains_doctor() -> void:
	var c := _doctor()
	Injuries.inflict(c, data(), "damaged_meridians")
	var before: int = c.injuries["damaged_meridians"]
	var result := Medicine.treat_self(c, data(), "damaged_meridians")
	assert_true(result["ok"])
	assert_eq(c.injuries["damaged_meridians"], before - Medicine.self_treatment_power(c, data()))
	assert_gt(Professions.xp_of(c, "doctor"), 0.0)


func test_higher_rank_heals_more() -> void:
	assert_gt(Medicine.self_treatment_power(_doctor(3), data()), Medicine.self_treatment_power(_doctor(0), data()))


func test_self_treatment_can_finish_healing() -> void:
	var c := _doctor(9)
	Injuries.inflict(c, data(), "broken_bones")
	var result := Medicine.treat_self(c, data(), "broken_bones")
	assert_true(result["healed"])
	assert_false(Injuries.has_any(c))


func test_cannot_treat_missing_injury() -> void:
	assert_false(Medicine.treat_self(_doctor(), data(), "broken_bones")["ok"])
	assert_false(Medicine.visit_clinic(_doctor(), data(), "broken_bones")["ok"])


func test_clinic_cost_scales_with_days_left() -> void:
	var c := _doctor()
	Injuries.inflict(c, data(), "internal_injury")
	var full := Medicine.clinic_cost(c, data(), "internal_injury")
	assert_eq(full, int(data().injuries["internal_injury"]["treatment_cost"]))
	Injuries.pass_days(c, int(data().injuries["internal_injury"]["heal_days"]) / 2)
	assert_gt(full, Medicine.clinic_cost(c, data(), "internal_injury"))


func test_clinic_heals_for_stones() -> void:
	var c := _doctor()
	c.inventory = {}
	Injuries.inflict(c, data(), "broken_bones")
	assert_false(Medicine.visit_clinic(c, data(), "broken_bones")["ok"], "cannot afford")
	assert_true(Injuries.has_any(c))
	c.add_item("spirit_stone", 100)
	var result := Medicine.visit_clinic(c, data(), "broken_bones")
	assert_true(result["ok"])
	assert_false(Injuries.has_any(c))
	assert_eq(c.item_count("spirit_stone"), 100 - int(result["cost"]))


func test_treating_patients_beats_plain_work() -> void:
	var a := _doctor()
	var b := _doctor()
	var treat := Medicine.treat_patients(a, data(), Calendar.DAYS_PER_MONTH)
	var work := Professions.work(b, data(), "doctor", Calendar.DAYS_PER_MONTH)
	assert_gt(treat["xp"], work["xp"])
	assert_eq(treat["income"], work["income"])
	assert_gt(a.alignment, 0)


func test_game_state_doctor_actions() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var clock := tree.root.get_node("GameClock")
	var c := CharacterFactory.create("Healer", gs.data, seeded_rng())
	gs.start_session(c)
	Injuries.inflict(c, gs.data, "broken_bones")
	gs.treat_own_injury("broken_bones")
	assert_eq(clock.total_days, int(gs.data.medicine["self_treatment_days"]))
	c.add_item("spirit_stone", 500)
	Injuries.inflict(c, gs.data, "qi_deviation")
	gs.visit_clinic("qi_deviation")
	assert_false(c.injuries.has("qi_deviation"))
	var align_before := c.alignment
	gs.treat_patients(Calendar.DAYS_PER_MONTH)
	assert_gt(c.alignment, align_before)
	gs.end_session()
