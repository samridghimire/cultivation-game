extends TestCase


func test_items_sorted_by_display_name() -> void:
	var c := new_character()
	c.inventory = {}
	c.add_item("spirit_stone", 5)
	c.add_item("qi_gathering_pill", 1)
	c.add_item("foundation_establishment_pill", 1)
	assert_eq(InventoryScreen.sorted_item_ids(c, data()), ["foundation_establishment_pill", "qi_gathering_pill", "spirit_stone"])


func test_describe_effects_lists_each_effect() -> void:
	var lines := InventoryScreen.describe_effects({"qi": 150, "breakthrough_bonus": 0.25, "alignment": -5, "items": {"spirit_stone": 3}}, data())
	assert_eq(lines.size(), 4)
	assert_true(lines.has("+150 qi"))
	assert_true(lines.has("+25% to your next breakthrough"))
	assert_true(lines.has("Alignment -5"))
	assert_true(lines.has("+3 Spirit Stone"))


func test_describe_effects_empty() -> void:
	assert_eq(InventoryScreen.describe_effects({}, data()).size(), 0)


func test_describe_effects_names_taught_technique() -> void:
	var lines := InventoryScreen.describe_effects({"learn_technique": "basic_breathing"}, data())
	assert_eq(lines, PackedStringArray(["Teaches the technique: Basic Breathing Method"]))
