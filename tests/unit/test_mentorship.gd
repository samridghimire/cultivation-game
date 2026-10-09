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
	p[1].techniques = {other: {"level": 3, "xp": 0.0}}
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
	q[1].techniques = {"iron_fist": {"level": 2, "xp": 0.0}}
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


func test_spar_checks_and_aftermath() -> void:
	var p := _pair()
	var d := data()
	var c: CharacterData = p[0]
	var npc: CharacterData = p[1]
	assert_eq(Mentorship.check_spar(c, null, 50, d, 0), "They are not here.")
	npc.age_days = 10 * Calendar.DAYS_PER_YEAR
	assert_true(Mentorship.check_spar(c, npc, 50, d, 0).contains("too young"))
	npc.age_days = 40 * Calendar.DAYS_PER_YEAR
	c.realm_index = 0
	assert_true(Mentorship.check_spar(c, npc, 50, d, 0).contains("need to cultivate"))
	c.realm_index = 1
	npc.realm_index = 0
	assert_true(Mentorship.check_spar(c, npc, 50, d, 0).contains("does not cultivate"))
	npc.realm_index = 3
	assert_true(Mentorship.check_spar(c, npc, 50, d, 0).contains("so far"))
	npc.realm_index = 2
	assert_true(Mentorship.check_spar(c, npc, 5, d, 0).contains("favor 5/10"))
	assert_eq(Mentorship.check_spar(c, npc, 10, d, 0), "")
	var enemy := Mentorship.spar_enemy(npc, d)
	assert_true(enemy["spar"] and enemy["friendly"])
	assert_false(enemy["lethal"])
	c.techniques["common_qi_gathering"] = {"level": 1, "xp": 0.0}
	var r := Mentorship.after_spar(c, npc, d, false, 50)
	assert_eq(r["favor"], 0)
	assert_eq(r["practiced"].size(), 1, "only the unmastered non-method technique")
	assert_eq(c.techniques["common_qi_gathering"]["xp"], 0.0)
	assert_eq(c.npc_action_days["spar:elder"], 50)
	assert_true(Mentorship.check_spar(c, npc, 10, d, 52).contains("recently"))
	assert_eq(Mentorship.check_spar(c, npc, 10, d, 57), "")
	assert_eq(Mentorship.after_spar(c, npc, d, true, 60)["favor"], 2)


## GUIDE-012: hints and journal lines for pointers and sparring.
func _hint_setup() -> Dictionary:
	var p := _pair()
	p[1].home_region = "qingshi_village"
	return {"c": p[0], "npc": p[1], "people": {"elder": p[1]}, "favor": {"elder": 30}}


func _hints_of(s: Dictionary, today: int = 400, region: String = "qingshi_village") -> PackedStringArray:
	return Guidance.hints(s["c"], data(), 1.0, 99, s["people"], {}, region, today, s["favor"])


func _any_contains(lines: PackedStringArray, text: String) -> bool:
	for l in lines:
		if l.contains(text):
			return true
	return false


func test_pointer_hint_only_when_action_succeeds() -> void:
	var s := _hint_setup()
	assert_true(_any_contains(_hints_of(s), "Elder Lu"))
	assert_true(_any_contains(_hints_of(s), "could point out flaws in your"))
	assert_false(_any_contains(_hints_of(s, 400, "azure_peak"), "could point out flaws"), "other region")
	s["favor"] = {"elder": 1}
	assert_false(_any_contains(_hints_of(s), "could point out flaws"), "favor too low")
	s["favor"] = {"elder": 30}
	(s["c"] as CharacterData).npc_action_days["pointers:elder"] = 399
	assert_false(_any_contains(_hints_of(s), "could point out flaws"), "cooldown")


func test_pointer_hint_prefers_highest_favor() -> void:
	var s := _hint_setup()
	var other := new_character(78)
	other.id = "other"
	other.name = "Elder Wen"
	other.age_days = 40 * Calendar.DAYS_PER_YEAR
	other.realm_index = 2
	other.home_region = "qingshi_village"
	s["people"]["other"] = other
	s["favor"]["other"] = 60
	var hint := ""
	for l in _hints_of(s):
		if l.contains("could point out"):
			hint = l
	assert_true(hint.begins_with("Elder Wen"))


func test_pointer_journal_lines_capped() -> void:
	var s := _hint_setup()
	for i in 4:
		var n := new_character(90 + i)
		n.id = "n%d" % i
		n.name = "Mentor %d" % i
		n.age_days = 40 * Calendar.DAYS_PER_YEAR
		n.realm_index = 2
		n.home_region = "qingshi_village"
		s["people"][n.id] = n
		s["favor"][n.id] = 25
	var rows := Guidance.journal(s["c"], data(), {}, 400, "qingshi_village", 1.0, s["people"], [], null, s["favor"])
	var asks := rows.filter(func(e: Dictionary) -> bool: return e["section"] == "Opportunities" and String(e["text"]).begins_with("Ask "))
	assert_eq(asks.size(), 3)


func test_never_sparred_hint() -> void:
	var s := _hint_setup()
	LifeStats.add(s["c"], "encounters")
	LifeStats.add(s["c"], "realm_floors_cleared")
	assert_true(_any_contains(_hints_of(s), "would spar with you"))
	(s["c"] as CharacterData).npc_action_days["spar:someone"] = 1
	assert_false(_any_contains(_hints_of(s), "would spar with you"), "already sparred")


## RV-014: a friendly spar is free; pointers are only shared with a better teacher.
func _talisman_fighter() -> CharacterData:
	var p := _pair()
	var c := p[0]
	c.realm_index = 2
	c.inventory = {"fire_strike_talisman": 1, "earth_wall_talisman": 1}
	c.readied_talismans = ["fire_strike_talisman", "earth_wall_talisman"]
	return c


func test_friendly_spar_keeps_readied_talismans() -> void:
	var c := _talisman_fighter()
	var npc := _pair()[1]
	var result := Combat.resolve(c, data(), Mentorship.spar_enemy(npc, data()), seeded_rng(5))
	assert_true((result["talismans_used"] as Array).is_empty())
	for line: String in result["log"]:
		assert_false(line.contains("You burn") or line.contains("You hurl"), line)
	assert_eq(c.item_count("fire_strike_talisman"), 1)
	assert_eq(c.readied_talismans.size(), 2)


func test_trial_spar_still_burns_talismans() -> void:
	var c := _talisman_fighter()
	var npc := _pair()[1]
	var enemy := Mentorship.spar_enemy(npc, data())
	enemy.erase("friendly")
	var result := Combat.resolve(c, data(), enemy, seeded_rng(5))
	assert_false((result["talismans_used"] as Array).is_empty())


func test_pointers_shared_only_when_senior_knows_better() -> void:
	var p := _pair()
	var d := data()
	p[1].techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	assert_false(Mentorship.knows_better(p[0], p[1], "iron_fist"), "equal level")
	var r := Mentorship.give_pointers(p[0], p[1], 50, d, 0)
	assert_true(r["ok"])
	assert_false(r["shared"])
	p[1].techniques["iron_fist"]["level"] = 3
	assert_true(Mentorship.knows_better(p[0], p[1], "iron_fist"))
	assert_true(Mentorship.give_pointers(p[0], p[1], 50, d, 100)["shared"])
