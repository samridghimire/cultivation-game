extends TestCase
## FAM-010: the family tree screen (FamilyScreen) and its character sheet button.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _person(people: Dictionary, id: String, seed_value: int) -> CharacterData:
	var n := new_character(seed_value)
	n.id = id
	n.name = id
	people[id] = n
	return n


func test_generations_group_relatives() -> void:
	var people := {}
	var me := new_character()
	var father := _person(people, "father", 2)
	var wife := _person(people, "wife", 3)
	var son := _person(people, "son", 4)
	var grandson := _person(people, "grandson", 5)
	me.parents = [father.id, "unknown"] as Array[String]
	me.spouses = [wife.id] as Array[String]
	me.children = [son.id] as Array[String]
	son.children = [grandson.id] as Array[String]
	assert_eq(FamilyScreen.generations(me, people), [["Parents", ["father"]], ["Spouses", ["wife"]], ["Children", ["son"]], ["Grandchildren", ["grandson"]]])
	assert_eq(FamilyScreen.generations(new_character(), people), [], "no family, no groups")


func test_person_lines() -> void:
	var people := {}
	var me := new_character()
	var son := _person(people, "son", 4)
	son.age_days = 8 * Calendar.DAYS_PER_YEAR
	me.children = [son.id] as Array[String]
	var lines := FamilyScreen.person_lines(me, son, data(), people, {"son": 12}, null)
	assert_true(lines[0].ends_with("age 8"), lines[0])
	assert_true(lines.has("Favor: 12"), str(lines))
	assert_true(lines.has("Training: none"), str(lines))
	son.alive = false
	son.cause_of_death = "fell in battle"
	assert_eq(FamilyScreen.person_lines(me, son, data(), people, {}, null), PackedStringArray(["Departed: fell in battle, at 8."]))


func test_screen_lists_family_and_names_an_heir() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.inventory["spirit_stone"] = 2000
	var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(40), {"gender": "female", "region": gs.current_region})
	wife.age_days = 30 * Calendar.DAYS_PER_YEAR
	Family.marry(c, wife, "wife")
	var son := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 5, "region": gs.current_region})
	var daughter := Npcs.spawn(gs.npcs, gs.data, seeded_rng(6), {"age_years": 3, "region": gs.current_region})
	c.children.append_array([son.id, daughter.id])
	c.abode = "waterfall_cave"
	gs.found_clan()

	var sheet := CharacterSheet.new()
	sheet._rebuild()
	assert_true(sheet._family_button.visible)
	var opened: Array = []
	var cb := func(): opened.append(true)
	EventBus.family_requested.connect(cb)
	sheet._family_button.pressed.emit()
	EventBus.family_requested.disconnect(cb)
	assert_eq(opened.size(), 1, "the sheet button asks for the family screen")
	sheet.free()

	var screen := FamilyScreen.new()
	_root().add_child(screen)
	screen.open()
	assert_true(screen._list.get_node_or_null(NodePath(wife.id)) != null, "spouse listed")
	assert_true(screen._list.get_node_or_null(NodePath(daughter.id)) != null, "child listed")
	assert_eq(screen._selected, wife.id, "first relative selected")
	assert_true(screen._actions.get_node_or_null("Training") == null, "no training for a spouse")
	screen._select(daughter.id)
	assert_true(screen._info.text.contains("Training: none"), screen._info.text)
	assert_true(screen._actions.get_node_or_null("Training") != null)
	var heir := screen._actions.get_node("NameHeir") as Button
	assert_false(heir.disabled, heir.tooltip_text)
	heir.pressed.emit()
	assert_eq(gs.clan.heir, daughter.id)
	assert_true(screen._info.text.contains(Clans.heir_title(gs.data, daughter.gender)), screen._info.text)
	assert_true((screen._actions.get_node("NameHeir") as Button).disabled, "already the heir")
	screen.close()
	assert_false(screen.visible)
	screen.free()
	gs.end_session()


func test_sheet_button_hidden_without_family() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(new_character())
	var sheet := CharacterSheet.new()
	sheet._rebuild()
	assert_false(sheet._family_button.visible)
	sheet.free()
	gs.end_session()
