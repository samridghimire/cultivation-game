extends TestCase
## FAM-001b: the character sheet shows family links and a one-time gender picker.


func _game_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_sheet_shows_family_and_gender_picker() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Han Li", gs.data, seeded_rng(77), "male")
	gs.start_session(c)
	var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(78), {"gender": "female"})
	Family.marry(c, wife, "wife")
	c.gender = ""
	var sheet := CharacterSheet.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sheet)
	sheet.open()
	var text := sheet._text.get_parsed_text()
	assert_true(text.contains("Family"), text)
	assert_true(text.contains(wife.name), text)
	assert_true(text.contains("of the Han family"), text)
	assert_true(sheet._gender_row.visible, "unknown gender shows the picker")
	sheet._choose_gender("male")
	assert_eq(c.gender, "male")
	assert_false(sheet._gender_row.visible)
	assert_true(sheet._text.get_parsed_text().contains("Wife: %s" % wife.name))
	sheet.free()
