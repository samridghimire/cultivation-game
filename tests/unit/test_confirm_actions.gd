extends TestCase
## WU-032: costly or irreversible actions need a second press.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _option(options: Array[Dictionary], prefix: String) -> Dictionary:
	for o: Dictionary in options:
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


func _joinable_sect(c: CharacterData) -> String:
	for sect: SectDef in _gs().data.sects.values():
		if Sects.check_join(c, _gs().data, sect.id)["ok"]:
			return sect.id
	return ""


func _btn(screen: ArtifactScreen, node_name: String) -> Button:
	for b in screen.buttons():
		if String(b.name) == node_name:
			return b
	return null


func test_warning_helpers() -> void:
	assert_true(Items.use_warning(data(), "blood_essence_pill").contains("5 years"))
	assert_true(Items.use_warning(data(), "blood_demon_pill").contains("alignment -5"))
	assert_eq(Items.use_warning(data(), "qi_gathering_pill"), "")
	var c := new_character()
	assert_true(Equipment.equip_warning(c, data(), "blood_drinker_saber").contains("1 year"))
	assert_true(Equipment.equip_warning(c, data(), "blood_drinker_saber").contains("-120"))
	c.bound_artifacts.append("blood_drinker_saber")
	assert_false(Equipment.equip_warning(c, data(), "blood_drinker_saber").contains("-120"), "already bound")
	assert_eq(Equipment.equip_warning(c, data(), "iron_sword"), "")


func test_sect_join_and_leave_ask_first() -> void:
	var gs := _gs()
	var c := new_character()
	gs.start_session(c)
	var sect_id := _joinable_sect(c)
	assert_true(sect_id != "", "some sect accepts a fresh character")
	var hall: Node = load("res://src/world/interactables/sect_hall.gd").new()
	var join := _option(hall.get_options(), "Join the %s" % gs.data.sects[sect_id].name)
	(join["action"] as Callable).call()
	assert_true(c.is_rogue(), "asking does not join")
	var options: Array[Dictionary] = hall.get_options()
	assert_eq(options[0]["label"], "No", "safe choice is first (focused)")
	assert_true(String(options[0]["description"]).contains("leave later"))
	(options[0]["action"] as Callable).call()
	assert_true(c.is_rogue())
	assert_true(String(_option(hall.get_options(), "Join")["label"]) != "No", "back to the normal list")
	(_option(hall.get_options(), "Join the %s" % gs.data.sects[sect_id].name)["action"] as Callable).call()
	(_option(hall.get_options(), "Yes")["action"] as Callable).call()
	assert_eq(c.sect.get("id", ""), sect_id, "confirm joins")
	# Leaving.
	c.sect["contribution"] = 42
	(_option(hall.get_options(), "Leave the")["action"] as Callable).call()
	assert_false(c.is_rogue(), "asking does not leave")
	options = hall.get_options()
	assert_eq(options[0]["label"], "No")
	assert_true(String(options[0]["description"]).contains("42 contribution"), options[0]["description"])
	hall.on_menu_closed()
	assert_false(hall.get_options()[0]["label"] == "No", "closing the menu cancels")
	(_option(hall.get_options(), "Leave the")["action"] as Callable).call()
	(_option(hall.get_options(), "Yes")["action"] as Callable).call()
	assert_true(c.is_rogue(), "confirm leaves")
	hall.free()
	gs.end_session()


func test_artifact_feed_all_and_big_stone_feed_arm_first() -> void:
	var gs := _gs()
	var c := new_character()
	c.inventory = {"spirit_stone": 150, "golden_bell_talisman": 2}
	gs.start_session(c)
	var screen := ArtifactScreen.new()
	screen.open()
	var b: Button = _btn(screen, "feed_stones_100")
	b.pressed.emit()
	assert_eq(c.artifact_energy, 0, "first press only arms")
	b = _btn(screen, "feed_stones_100")
	assert_true(b.text.begins_with("Confirm"), b.text)
	b.pressed.emit()
	assert_eq(c.item_count("spirit_stone"), 50, "second press feeds")
	_btn(screen, "feed_stones_10").pressed.emit()
	assert_eq(c.item_count("spirit_stone"), 40, "small feeds are immediate")
	screen._show_page(ArtifactScreen.PAGE_FEED)
	_btn(screen, "feedall_golden_bell_talisman").pressed.emit()
	assert_eq(c.item_count("golden_bell_talisman"), 2, "feed all arms first")
	screen._show_page(ArtifactScreen.PAGE_FEED)
	_btn(screen, "feedall_golden_bell_talisman").pressed.emit()
	assert_eq(c.item_count("golden_bell_talisman"), 2, "changing page disarms")
	_btn(screen, "feedall_golden_bell_talisman").pressed.emit()
	assert_eq(c.item_count("golden_bell_talisman"), 0, "second press feeds all")
	screen.free()
	gs.end_session()


func test_inventory_risky_use_and_equip_arm_first() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := _gs()
	var c := new_character()
	gs.start_session(c)
	c.inventory = {"blood_essence_pill": 1, "blood_drinker_saber": 1}
	var inv := InventoryScreen.new()
	root.add_child(inv)
	inv.open()
	inv._select("blood_essence_pill")
	var years := c.lifespan_spent_years
	inv._use_selected()
	assert_eq(c.item_count("blood_essence_pill"), 1, "first press does not use it")
	assert_true(inv._use_button.text.contains("Press again"), inv._use_button.text)
	inv._select("blood_drinker_saber")
	assert_eq(inv._use_armed, "", "selecting another item disarms")
	inv._use_selected()
	assert_false(c.equipment.has("weapon"), "first press does not equip")
	assert_eq(c.alignment, new_character().alignment)
	inv._use_selected()
	assert_eq(String(c.equipment.get("weapon", "")), "blood_drinker_saber")
	inv._select("blood_essence_pill")
	inv._use_selected()
	inv._use_selected()
	assert_eq(c.item_count("blood_essence_pill"), 0, "confirmed use")
	assert_true(c.lifespan_spent_years > years)
	inv.free()
	gs.end_session()
