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
