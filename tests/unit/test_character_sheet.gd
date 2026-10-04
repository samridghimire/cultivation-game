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


func test_sheet_shows_spouse_pregnancy_and_meditation_offers_try_for_child() -> void:
	var gs := _game_state()
	var c := CharacterFactory.create("Han Li", gs.data, seeded_rng(77), "male")
	gs.start_session(c)
	var wife := Npcs.spawn(gs.npcs, gs.data, seeded_rng(78), {"gender": "female", "region": gs.current_region})
	wife.age_days = 20 * Calendar.DAYS_PER_YEAR
	Family.marry(c, wife, "wife")
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var tries: Array = spot.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Try for a child"))
	assert_eq(tries.size(), 1)
	assert_false(tries[0]["disabled"], tries[0]["label"])
	wife.pregnancy = {"partner": c.id, "days_left": 60}
	tries = spot.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Try for a child"))
	assert_true(tries[0]["disabled"], "already with child")
	assert_true(String(tries[0]["label"]).contains("already with child"), tries[0]["label"])
	spot.free()
	var sheet := CharacterSheet.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sheet)
	sheet.open()
	var text := sheet._text.get_parsed_text()
	assert_true(text.contains("%s is with your child (2 months to the birth)" % wife.name), text)
	sheet.free()
	gs.end_session()
