extends TestCase
## MENTOR-001: asking a senior for pointers (Mentorship).


func _pair() -> Array[CharacterData]:
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	var npc := new_character(77)
	npc.id = "elder"
	npc.name = "Elder Lu"
	npc.age_days = 40 * Calendar.DAYS_PER_YEAR
	npc.realm_index = 2
	npc.stage = 0
	return [c, npc]


func test_is_senior() -> void:
	var p := _pair()
	assert_true(Mentorship.is_senior(p[0], p[1]))
	p[1].realm_index = 1
	assert_false(Mentorship.is_senior(p[0], p[1]), "equal")
	p[1].stage = 1
	assert_true(Mentorship.is_senior(p[0], p[1]), "same realm, higher stage")
	assert_false(Mentorship.is_senior(p[1], p[0]))


func test_pointer_technique_choice() -> void:
	var p := _pair()
	var d := data()
	assert_eq(Mentorship.pointer_technique(p[0], p[1], d), "iron_fist")
	var def: TechniqueDef = d.techniques["iron_fist"]
	p[0].techniques["iron_fist"]["level"] = def.max_level
	assert_eq(Mentorship.pointer_technique(p[0], p[1], d), "", "mastered is skipped")
	p[0].techniques = {}
	assert_eq(Mentorship.pointer_technique(p[0], p[1], d), "", "no techniques")
	var other := ""
	for id in d.techniques:
		if id != "iron_fist" and not (d.techniques[id] as TechniqueDef).is_method() and (d.techniques[id] as TechniqueDef).max_level > 1:
			other = id
			break
	p[0].techniques = {"iron_fist": {"level": 1, "xp": 0.0}, other: {"level": 2, "xp": 0.0}}
	assert_eq(Mentorship.pointer_technique(p[0], p[1], d), "iron_fist", "lowest level first")
	p[1].techniques = {other: {"level": 1, "xp": 0.0}}
	assert_eq(Mentorship.pointer_technique(p[0], p[1], d), other, "a shared one wins")


func test_check_reasons() -> void:
	var p := _pair()
	var d := data()
	assert_eq(Mentorship.check_pointers(p[0], null, 50, d, 0), "They are not here.")
	p[1].alive = false
	assert_eq(Mentorship.check_pointers(p[0], p[1], 50, d, 0), "They are not here.")
	p[1].alive = true
	p[1].age_days = 10 * Calendar.DAYS_PER_YEAR
	assert_true(Mentorship.check_pointers(p[0], p[1], 50, d, 0).contains("too young"))
	p[1].age_days = 40 * Calendar.DAYS_PER_YEAR
	p[1].realm_index = 1
	p[1].stage = 0
	assert_true(Mentorship.check_pointers(p[0], p[1], 50, d, 0).contains("no stronger"))
	p[1].realm_index = 2
	assert_true(Mentorship.check_pointers(p[0], p[1], 5, d, 0).contains("favor 5/20"))
	assert_eq(Mentorship.check_pointers(p[0], p[1], 20, d, 0), "")
	p[0].techniques = {}
	assert_true(Mentorship.check_pointers(p[0], p[1], 20, d, 0).contains("no technique"))


func test_give_pointers_xp_cooldown_and_shared() -> void:
	var p := _pair()
	var d := data()
	var rules: Dictionary = d.family["mentorship"]["pointers"]
	var expected: float = Techniques.xp_per_day(p[0]) * int(rules["practice_days"])
	var r := Mentorship.give_pointers(p[0], p[1], 25, d, 100)
	assert_true(r["ok"], r["reason"])
	assert_false(r["shared"])
	var total: float = float(p[0].techniques["iron_fist"]["xp"])
	for l in range(1, Techniques.level(p[0], "iron_fist")):
		total += (d.techniques["iron_fist"] as TechniqueDef).xp_to_next(l)
	assert_almost_eq(total, expected, 0.01)
	assert_eq(p[0].npc_action_days["pointers:elder"], 100)
	assert_true(Mentorship.check_pointers(p[0], p[1], 25, d, 110).contains("20 days"))
	assert_eq(Mentorship.check_pointers(p[0], p[1], 25, d, 130), "")
	# a shared technique doubles it
	var q := _pair()
	q[1].techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	var s := Mentorship.give_pointers(q[0], q[1], 25, d, 0)
	assert_true(s["shared"])
	var shared_total: float = float(q[0].techniques["iron_fist"]["xp"])
	for l in range(1, Techniques.level(q[0], "iron_fist")):
		shared_total += (d.techniques["iron_fist"] as TechniqueDef).xp_to_next(l)
	assert_almost_eq(shared_total, expected * float(rules["shared_multiplier"]), 0.01)


func test_validator_and_save() -> void:
	var d := GameData.load_from_dir()
	assert_eq(Mentorship.validate(d).size(), 0)
	d.family["mentorship"]["pointers"]["days"] = -1
	assert_eq(Mentorship.validate(d).size(), 1)
	d.family["mentorship"]["pointers"]["days"] = 1
	d.family["mentorship"]["pointers"]["shared_multiplier"] = 0.5
	assert_eq(Mentorship.validate(d).size(), 1)
	var c := new_character()
	c.npc_action_days["pointers:x"] = 42
	assert_eq(CharacterData.from_dict(c.to_dict()).npc_action_days["pointers:x"], 42)
	assert_eq(CharacterData.from_dict({}).npc_action_days.size(), 0)
