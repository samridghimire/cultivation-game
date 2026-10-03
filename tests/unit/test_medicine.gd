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


# --- Treating NPCs (G-007c) -----------------------------------------------------

func _patient() -> CharacterData:
	var p := new_character(999)
	p.id = "npc_patient"
	p.name = "Patient Wu"
	return p


func test_treat_npc_reasons() -> void:
	var doc := _doctor()
	assert_true(Medicine.check_treat_npc(doc, null) != "")
	var p := _patient()
	assert_true(Medicine.check_treat_npc(doc, p).contains("not injured"))
	assert_true(Medicine.check_treat_npc(doc, doc) != "", "self goes through treat_self")
	Injuries.inflict(p, data(), "broken_bones")
	assert_eq(Medicine.check_treat_npc(doc, p), "")
	p.alive = false
	assert_true(Medicine.check_treat_npc(doc, p) != "")
	assert_false(Medicine.treat_npc(doc, p, data())["ok"])


func test_treat_npc_heals_worst_injury_first() -> void:
	var doc := _doctor()
	var p := _patient()
	Injuries.inflict(p, data(), "broken_bones")  # 60 days
	Injuries.inflict(p, data(), "damaged_meridians")  # 365 days
	assert_eq(Medicine.worst_injury(p), "damaged_meridians")
	var align_before := doc.alignment
	var result := Medicine.treat_npc(doc, p, data())
	assert_true(result["ok"])
	assert_eq(result["injury"], "damaged_meridians")
	assert_false(result["healed"])
	assert_eq(p.injuries["damaged_meridians"], 365 - Medicine.self_treatment_power(doc, data()))
	assert_eq(result["favor"], int(data().medicine["npc_treatment_favor"]))
	assert_gt(doc.alignment, align_before)
	assert_gt(Professions.xp_of(doc, "doctor"), 0.0)


func test_treat_npc_full_heal_earns_extra_favor() -> void:
	var doc := _doctor(5)
	var p := _patient()
	Injuries.inflict(p, data(), "broken_bones")
	var result := Medicine.treat_npc(doc, p, data())
	assert_true(result["healed"])
	assert_true(p.injuries.is_empty())
	assert_eq(result["favor"], int(data().medicine["npc_treatment_favor"]) + int(data().medicine["npc_healed_favor"]))


func test_npcs_get_hurt_and_heal_over_time() -> void:
	var npcs := {}
	var rng := seeded_rng(5)
	for i in 30:
		var n := Npcs.spawn(npcs, data(), rng, {"age_years": 25})
		n.attributes["fortune"] = 10
	Npcs.simulate(npcs, data(), Calendar.DAYS_PER_YEAR * 2, rng)
	var hurt := 0
	for n: CharacterData in npcs.values():
		if not n.injuries.is_empty():
			hurt += 1
	# With a 5%/month chance, some of 30 NPCs carry an injury at any time.
	assert_gt(hurt, 0, "some NPCs should be injured")
	var one: CharacterData = npcs.values()[0]
	one.injuries = {"broken_bones": 10}
	Npcs.simulate({"x": one}, data(), 10, seeded_rng(1))
	assert_true(not one.injuries.has("broken_bones") or int(one.injuries["broken_bones"]) == 60, "healed (or freshly re-injured)")


func test_game_state_treat_npc() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs := tree.root.get_node("GameState")
	var clock := tree.root.get_node("GameClock")
	var c := CharacterFactory.create("Healer", gs.data, seeded_rng())
	gs.start_session(c)
	var patient: CharacterData = gs.npcs.values()[0]
	patient.injuries = {}
	gs.treat_npc(patient.id)  # not injured: refused, no time passes
	assert_eq(clock.total_days, 0)
	Injuries.inflict(patient, gs.data, "internal_injury")
	var favor_before := int(gs.npc_favor.get(patient.id, 0))
	gs.treat_npc(patient.id)
	assert_eq(clock.total_days, int(gs.data.medicine["npc_treatment_days"]))
	assert_gt(int(gs.npc_favor.get(patient.id, 0)), favor_before)
	gs.end_session()
