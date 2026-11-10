extends TestCase
## COOK-003: the friend who taught you a dish remarks on it in their next chat within 14 days (+3 favor, once per dish).


func _root() -> Node:
	return Engine.get_main_loop().root


func _taught(gs: Node) -> void:
	gs.player.lessons_taught["xiao_ling:0"] = 1  # egg_custard
	gs.player.known_dishes.append("egg_custard")
	gs.player.add_item("hen_egg", 6)
	gs.player.add_item("well_water", 4)


func test_record_only_for_taught_dish_once() -> void:
	var d := data()
	var c := new_character()
	var flags := {}
	assert_false(Folk.record_dish_cooked(flags, c, d, "egg_custard", 10), "not taught by a friend")
	c.lessons_taught["xiao_ling:0"] = 1
	assert_true(Folk.record_dish_cooked(flags, c, d, "egg_custard", 10))
	assert_false(Folk.record_dish_cooked(flags, c, d, "egg_custard", 11), "once per dish")


func test_window_and_told_once() -> void:
	var d := data()
	var c := new_character()
	c.lessons_taught["xiao_ling:0"] = 1
	var flags := {}
	Folk.record_dish_cooked(flags, c, d, "egg_custard", 10)
	var npc := CharacterData.new()
	npc.id = "xiao_ling"
	assert_true(Folk.dish_noticed(npc, d, flags, 25, true).is_empty(), "after 14 days it fades")
	var found := Folk.dish_noticed(npc, d, flags, 24, false)
	assert_true(String(found["line"]).contains("steamed egg custard"), String(found["line"]))
	assert_false(Folk.dish_noticed(npc, d, flags, 24, true).is_empty(), "peek did not consume")
	assert_true(Folk.dish_noticed(npc, d, flags, 24, true).is_empty(), "told once")


func test_validation() -> void:
	var d := data()
	assert_true(Folk.validate_taught_dish_line(d).is_empty())
	d.npcs["xiao_ling"]["taught_dish_line"] = "no placeholder"
	assert_false(Folk.validate_taught_dish_line(d).is_empty())
	d.npcs["xiao_ling"]["taught_dish_line"] = "{dish} " + "x".repeat(160)
	assert_false(Folk.validate_taught_dish_line(d).is_empty())


func test_cook_then_chat_gives_favor_once_and_survives_save() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	_taught(gs)
	gs.npc_favor["xiao_ling"] = 30
	gs.cook_meal("egg_custard")
	assert_true(gs.world_flags.has("dish_memory"), "remembered")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(gs.world_flags))
	assert_true(restored["dish_memory"].has("egg_custard"), "round-trips as plain JSON")
	var before := int(gs.npc_favor["xiao_ling"])
	gs._dish_noticed("xiao_ling")
	assert_eq(int(gs.npc_favor["xiao_ling"]), before + Folk.DISH_NOTICED_FAVOR)
	gs._dish_noticed("xiao_ling")
	assert_eq(int(gs.npc_favor["xiao_ling"]), before + Folk.DISH_NOTICED_FAVOR, "once per dish")
	gs.cook_meal("egg_custard")
	assert_false(gs._dish_noticed("xiao_ling"), "a second cook records nothing new")
