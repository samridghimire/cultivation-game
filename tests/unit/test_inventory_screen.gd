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


func test_describe_talisman_kind_power_and_readied() -> void:
	var c := new_character()
	c.inventory = {"fire_strike_talisman": 2}
	var amount := CombatTalismans.amount(data(), "fire_strike_talisman")
	assert_eq(InventoryScreen.describe_talisman(c, data(), "fire_strike_talisman"), PackedStringArray(["Strike talisman: deals %d damage at the start of a fight" % amount]))
	assert_true(InventoryScreen.describe_talisman(c, data(), "earth_wall_talisman")[0].begins_with("Shield talisman: absorbs"))
	assert_true(InventoryScreen.describe_talisman(c, data(), "thousand_li_escape_talisman")[0].begins_with("Escape talisman"))
	CombatTalismans.ready_talisman(c, data(), "fire_strike_talisman")
	assert_eq(InventoryScreen.describe_talisman(c, data(), "fire_strike_talisman").size(), 2)


func test_readied_summary() -> void:
	var c := new_character()
	c.inventory = {"fire_strike_talisman": 2, "earth_wall_talisman": 1}
	assert_eq(InventoryScreen.readied_summary(c, data()), "No talismans readied for battle.")
	CombatTalismans.ready_talisman(c, data(), "fire_strike_talisman")
	CombatTalismans.ready_talisman(c, data(), "earth_wall_talisman")
	var text := InventoryScreen.readied_summary(c, data())
	assert_true(text.contains("Fire Strike Talisman x2") and text.contains("Earth Wall Talisman x1") and text.ends_with("(2/%d)" % CombatTalismans.MAX_READIED), text)


func test_ready_button_readies_and_puts_away_talismans() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var c := CharacterFactory.create("Inscriber", gs.data, seeded_rng())
	gs.start_session(c)
	c.inventory = {"fire_strike_talisman": 1, "earth_wall_talisman": 1, "five_thunder_talisman": 1, "black_tortoise_shell_talisman": 1, "spirit_stone": 3}
	var inv := InventoryScreen.new()
	root.add_child(inv)
	inv.open()
	inv._select("spirit_stone")
	assert_false(inv._ready_button.visible, "not a talisman")
	for item_id in ["black_tortoise_shell_talisman", "earth_wall_talisman", "fire_strike_talisman"]:
		inv._select(item_id)
		assert_true(inv._ready_button.visible and not inv._ready_button.disabled, item_id)
		assert_eq(inv._ready_button.text, "Ready for battle")
		inv._toggle_ready()
		assert_true(c.readied_talismans.has(item_id), item_id)
	assert_eq(inv._ready_button.text, "Put away")
	assert_true((inv._list.get_node("fire_strike_talisman") as Button).text.contains("(readied)"))
	assert_true(inv._readied.text.contains("(3/3)"), inv._readied.text)
	inv._select("five_thunder_talisman")
	assert_true(inv._ready_button.disabled, "all slots taken")
	assert_true(inv._effects.text.contains("kinds of talisman"), inv._effects.text)
	inv._select("fire_strike_talisman")
	inv._toggle_ready()
	assert_false(c.readied_talismans.has("fire_strike_talisman"))
	inv._select("five_thunder_talisman")
	assert_false(inv._ready_button.disabled, "a slot is free again")
	inv.free()
	gs.end_session()


func test_item_categories() -> void:
	var d := data()
	assert_eq(Items.category(d.items["iron_sword"]), "Equipment")
	assert_eq(Items.category(d.items["qi_gathering_pill"]), "Pills")
	assert_eq(Items.category(d.items["spirit_stone"]), "Other")
	for id in d.items:
		assert_true(Items.CATEGORIES.has(Items.category(d.items[id])), id)
	var kinds := {}
	for id in d.items:
		kinds[Items.category(d.items[id])] = true
	for cat in Items.CATEGORIES:
		if cat != "All":
			assert_true(kinds.has(cat), "no item in " + cat)


func test_category_tabs_filter_list_and_focus_first() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Tabber", gs.data, seeded_rng()))
	gs.player.inventory = {"iron_sword": 1, "qi_gathering_pill": 2}
	var inv := InventoryScreen.new()
	root.add_child(inv)
	inv.open()
	assert_eq(inv._list.get_child_count(), 2)
	inv._set_category("Equipment")
	assert_eq(inv._list.get_child_count(), 1)
	assert_eq(inv._selected, "iron_sword")
	inv._set_category("Talismans")
	assert_eq(inv._list.get_child_count(), 1)
	assert_eq((inv._list.get_child(0) as Label).text, "Nothing here.")
	inv._set_category("All")
	inv.queue_free()
