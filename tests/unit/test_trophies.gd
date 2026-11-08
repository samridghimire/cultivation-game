extends TestCase
## WILD-022: trophies hung on the wall of your home.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _homed() -> Array:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Hunter", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("qi_refining")
	c.add_item("spirit_stone", 1000)
	gs.current_region = "misty_forest"
	gs.claim_abode("waterfall_cave")
	return [gs, c]


func test_hang_and_take_down() -> void:
	var r := _homed()
	var gs: Node = r[0]
	var c: CharacterData = r[1]
	c.add_item("old_tuskers_broken_tusk", 1)
	gs.hang_trophy("old_tuskers_broken_tusk")
	assert_eq(c.hung_trophies, ["old_tuskers_broken_tusk"] as Array[String])
	assert_eq(c.item_count("old_tuskers_broken_tusk"), 0)
	gs.take_down_trophy("old_tuskers_broken_tusk")
	assert_true(c.hung_trophies.is_empty())
	assert_eq(c.item_count("old_tuskers_broken_tusk"), 1, "returned")


func test_max_three_and_needs_home_and_trophy_tag() -> void:
	var r := _homed()
	var gs: Node = r[0]
	var c: CharacterData = r[1]
	for id in ["old_tuskers_broken_tusk", "tuskers_sow_bristle", "scarred_tuskers_spear_head", "cloud_cranes_crown_plume"]:
		c.add_item(id, 1)
		gs.hang_trophy(id)
	assert_eq(c.hung_trophies.size(), Trophies.MAX_HUNG)
	assert_eq(c.item_count("cloud_cranes_crown_plume"), 1, "fourth stays in the pack")
	c.add_item("spirit_stone", 0)
	assert_false(Trophies.check_hang(c, gs.npcs, gs.data, "misty_forest", "spirit_stone").is_empty(), "not a trophy")
	assert_false(Trophies.check_hang(c, gs.npcs, gs.data, "qingshi_village", "cloud_cranes_crown_plume").is_empty(), "no home there")


func test_monthly_renown_and_save_round_trip() -> void:
	var r := _homed()
	var gs: Node = r[0]
	var c: CharacterData = r[1]
	c.add_item("old_tuskers_broken_tusk", 1)
	c.add_item("tuskers_sow_bristle", 1)
	gs.hang_trophy("old_tuskers_broken_tusk")
	gs.hang_trophy("tuskers_sow_bristle")
	assert_eq(Trophies.monthly_renown(c, gs.npcs, gs.data, 1), 2)
	assert_eq(Trophies.monthly_renown(c, gs.npcs, gs.data, 3), 6)
	var before := Renown.value(c, "misty_forest")
	gs.current_region = "qingshi_village"
	gs._pass_time(Calendar.DAYS_PER_MONTH)
	assert_gt(Renown.value(c, "misty_forest"), before, "renown lands in the home's region")
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(back.hung_trophies, c.hung_trophies)
	var old := c.to_dict()
	old.erase("hung_trophies")
	assert_true(CharacterData.from_dict(old).hung_trophies.is_empty())


func test_comment_once_a_month() -> void:
	var r := _homed()
	var gs: Node = r[0]
	var c: CharacterData = r[1]
	var flags := {}
	assert_eq(Trophies.comment(c, gs.npcs, gs.data, flags, "misty_forest", 100), "", "nothing hung")
	c.add_item("old_tuskers_broken_tusk", 1)
	gs.hang_trophy("old_tuskers_broken_tusk")
	var line := Trophies.comment(c, gs.npcs, gs.data, flags, "misty_forest", 100)
	assert_true(line.contains("Old Tusker's Broken Tusk"))
	assert_eq(Trophies.comment(c, gs.npcs, gs.data, flags, "misty_forest", 101), "", "second chat that month")
	assert_false(Trophies.comment(c, gs.npcs, gs.data, flags, "misty_forest", 100 + Calendar.DAYS_PER_MONTH).is_empty(), "next month")
	assert_eq(Trophies.comment(c, gs.npcs, gs.data, {}, "qingshi_village", 100), "", "not at home")
