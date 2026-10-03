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


func test_describe_effects_healing() -> void:
	assert_eq(InventoryScreen.describe_effects({"heal_injury": "all"}, data()), PackedStringArray(["Heals every injury"]))
	var name := Injuries.injury_name(data(), "broken_bones")
	assert_eq(InventoryScreen.describe_effects({"heal_injury": "broken_bones"}, data()), PackedStringArray(["Heals: %s" % name]))


func test_describe_equipment_shows_slot_stats_and_replacement() -> void:
	var c := new_character()
	var lines := InventoryScreen.describe_equipment(c, data(), "iron_sword")
	assert_eq(lines.size(), 1)
	assert_true(lines[0].begins_with("Weapon: ") and lines[0].contains("attack"), lines[0])
	c.equipment["weapon"] = "cold_iron_saber"
	lines = InventoryScreen.describe_equipment(c, data(), "iron_sword")
	assert_eq(lines.size(), 2)
	assert_true(lines[1].contains("Replaces your"), lines[1])


func test_equipment_button_equips_and_sheet_unequips() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := CharacterFactory.create("Smith", gs.data, seeded_rng())
	gs.start_session(c)
	c.inventory = {"iron_sword": 1}
	var inv := InventoryScreen.new()
	root.add_child(inv)
	inv.open()
	assert_eq(inv._use_button.text, "Equip")
	assert_true(inv._use_button.visible and not inv._use_button.disabled)
	assert_true(inv._effects.text.contains("Weapon: "), inv._effects.text)
	inv._use_selected()
	assert_eq(String(c.equipment.get("weapon", "")), "iron_sword")
	assert_eq(c.item_count("iron_sword"), 0)
	inv.free()
	var sheet := CharacterSheet.new()
	root.add_child(sheet)
	sheet.open()
	var text: String = sheet._text.get_parsed_text()
	assert_true(text.contains("Weapon: %s (" % gs.data.items["iron_sword"]["name"]), text)
	assert_true(text.contains("Armor: none"), text)
	var unequip := sheet._equip_row.get_node("unequip_weapon") as Button
	assert_true(unequip != null and sheet._equip_row.visible)
	unequip.pressed.emit()
	assert_false(c.equipment.has("weapon"))
	assert_eq(c.item_count("iron_sword"), 1)
	assert_true(sheet._text.get_parsed_text().contains("Weapon: none"))
	assert_false(sheet._equip_row.visible, "no gear, no unequip row")
	sheet.free()
	gs.end_session()
