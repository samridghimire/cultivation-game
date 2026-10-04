extends TestCase


func test_lists_known_techniques_then_unlearned_manuals() -> void:
	var c := new_character()
	c.techniques = {}
	c.inventory = {}
	c.techniques["stone_skin"] = {"level": 2, "xp": 0.0}
	c.techniques["iron_fist"] = {"level": 1, "xp": 0.0}
	c.add_item("manual_basic_breathing", 1)
	c.add_item("manual_iron_fist", 1)  # already known, not listed twice
	assert_eq(TechniquesScreen.listed_ids(c, data()), ["iron_fist", "stone_skin", "basic_breathing"])


func test_lists_nothing_for_a_fresh_mortal() -> void:
	var c := new_character()
	c.techniques = {}
	c.inventory = {}
	assert_eq(TechniquesScreen.listed_ids(c, data()).size(), 0)


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_listed_ids_leave_methods_to_method_ids() -> void:
	var c := new_character()
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	c.inventory = {}
	assert_eq(TechniquesScreen.listed_ids(c, data()), ["iron_fist"])
	assert_eq(TechniquesScreen.method_ids(c, data()), [data().starter_method], "the starter method is always shown")


func test_method_ids_put_main_method_first_then_known_then_manuals() -> void:
	var c := new_character()
	c.techniques = {}
	c.inventory = {}
	c.add_item("manual_verdant_spring", 1)
	assert_eq(TechniquesScreen.method_ids(c, data()), [data().starter_method, "verdant_spring_method"])
	c.techniques["verdant_spring_method"] = {"level": 1, "xp": 0.0}
	c.main_method = "verdant_spring_method"
	assert_eq(TechniquesScreen.method_ids(c, data()), ["verdant_spring_method", data().starter_method], "the starter stays listed to switch back")


func test_method_text_shows_rate_and_cap() -> void:
	var c := new_character()
	var text := TechniquesScreen.method_text(c, data(), "verdant_spring_method")
	assert_true(text.contains("cultivation speed"), text)
	assert_true(text.contains("while it is your main method"), text)
	assert_eq(TechniquesScreen.method_text(c, data(), "iron_fist"), Techniques.describe_bonuses(c, data(), "iron_fist"))


func test_screen_marks_main_method_and_switches() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	c.techniques = {"verdant_spring_method": {"level": 1, "xp": 0.0}}
	c.main_method = "verdant_spring_method"
	gs.start_session(c)
	var screen := TechniquesScreen.new()
	screen._rebuild()
	assert_eq(screen._selected, "verdant_spring_method", "main method preselected")
	var main_entry := screen._list.get_node("verdant_spring_method") as Button
	assert_true(main_entry.text.ends_with("(main)"), main_entry.text)
	assert_true(screen._actions.get_node_or_null("SetMain") == null, "no switch button for the main method")
	screen._select(data().starter_method)
	var set_main := screen._actions.get_node("SetMain") as Button
	assert_false(set_main.disabled)
	var day: int = _root().get_node("GameClock").total_days
	set_main.pressed.emit()
	assert_eq(Techniques.main_method(gs.player, data()), data().starter_method)
	assert_eq(_root().get_node("GameClock").total_days - day, data().method_switch_days)
	screen.free()
