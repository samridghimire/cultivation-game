extends TestCase
## DEM-001: devouring a beaten cultivator's cultivation.


func _rogue() -> Dictionary:
	return data().enemies["rogue_cultivator"]


func test_real_rules_are_valid_and_cultivators_are_tagged() -> void:
	assert_eq(Devouring.validate(data()).size(), 0, ", ".join(Devouring.validate(data())))
	assert_true(Devouring.is_devourable(data(), _rogue()))
	assert_false(Devouring.is_devourable(data(), data().enemies["mist_wolf"]), "beasts have no cultivation to devour")
	assert_false(Devouring.is_devourable(data(), Sects.trial_opponent(data(), "rogue_cultivator")), "never a sparring partner")


func test_validation_catches_bad_rules() -> void:
	var d := GameData.load_from_dir()
	d.demonic_arts["devouring"] = {"tag": "", "qi_fraction": 0, "alignment": 5, "injury": "nope", "heart_demon_chance": 2.0, "days": -1}
	assert_eq(Devouring.validate(d).size(), 6, ", ".join(Devouring.validate(d)))


func test_qi_scales_with_enemy_realm() -> void:
	var low := Devouring.qi_gain(data(), _rogue())
	var high := Devouring.qi_gain(data(), data().enemies["demonic_cultivator"])
	assert_gt(low, 0)
	assert_gt(high, low)


func test_devour_gives_qi_drops_alignment_and_counts() -> void:
	var c := new_character()
	c.realm_index = 1
	c.qi = 0.0
	c.alignment = 0
	var rng := seeded_rng()
	var result := Devouring.devour(c, data(), _rogue(), rng)
	assert_true(result["ok"], result["reason"])
	assert_gt(int(result["qi"]), 0)
	assert_eq(c.alignment, int(Devouring.rules(data())["alignment"]))
	assert_eq(c.devoured, 1)
	assert_gt(Devouring.heart_demon_chance(c, data()), float(Devouring.rules(data())["heart_demon_chance"]), "each victim raises the risk")
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.devoured, 1, "saved")
	assert_eq(CharacterData.from_dict({}).devoured, 0, "old saves load")


func test_heart_demon_risk_is_capped_and_rolls() -> void:
	var c := new_character()
	c.realm_index = 1
	c.devoured = 100
	assert_eq(Devouring.heart_demon_chance(c, data()), float(Devouring.rules(data())["heart_demon_max_chance"]))
	var demons := 0
	for i in 40:
		c.injuries = {}
		if Devouring.devour(c, data(), _rogue(), seeded_rng(i))["injury"] == "heart_demon":
			demons += 1
	assert_gt(demons, 0, "a hardened devourer still meets heart demons")
	assert_true(c.injuries.has("heart_demon") or demons < 40)


func test_mortals_cannot_devour() -> void:
	var c := new_character()
	c.realm_index = 0
	assert_true(Devouring.check_devour(c, data(), _rogue()) != "")
	assert_false(Devouring.devour(c, data(), _rogue(), seeded_rng())["ok"])


func test_game_state_devours_after_a_won_fight() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	c.realm_index = 2
	c.alignment = 0
	var weak := (gs.data.enemies["rogue_cultivator"] as Dictionary).duplicate(true)
	weak["hp"] = -1000
	weak["attack"] = -1000
	assert_true(gs.fight_enemy(weak), "an easy win")
	assert_false(gs.devour_target.is_empty(), "the beaten cultivator can be devoured")
	var report := CombatReport.new()
	root.add_child(report)
	report.show_fight("Rogue Cultivator", true, PackedStringArray(["start", "end"]))
	assert_true(report._devour_button.visible and not report._devour_button.disabled, report._devour_button.text)
	assert_true(report._devour_button.text.contains("heart demon risk"))
	report._devour()
	assert_eq(c.devoured, 1)
	assert_lt_alignment(c)
	assert_true(gs.devour_target.is_empty(), "only once")
	assert_false(report._devour_button.visible)
	assert_true(gs.fight_enemy(weak))
	report.show_fight("Rogue Cultivator", true, PackedStringArray(["start", "end"]))
	report.close()
	assert_true(gs.devour_target.is_empty(), "the chance passes with the report")
	var beast := (gs.data.enemies["mist_wolf"] as Dictionary).duplicate(true)
	beast["hp"] = -1000
	beast["attack"] = -1000
	gs.fight_enemy(beast)
	assert_true(gs.devour_target.is_empty(), "beasts are not devoured")
	report.free()
	gs.end_session()


func assert_lt_alignment(c: CharacterData) -> void:
	assert_true(c.alignment < 0, "alignment %d should drop" % c.alignment)
