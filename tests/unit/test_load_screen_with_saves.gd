extends TestCase
## The load screen must build rows (load + delete buttons) without errors when
## save files exist. Cloud runners start with no saves, so create one here.

const TEST_SLOT := "_test_load_screen"


func test_load_screen_lists_existing_saves() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	var c := CharacterFactory.create("Loader", gs.data, seeded_rng(7))
	gs.start_session(c)
	assert_true(saves.save_game(TEST_SLOT))
	var screen := LoadScreen.new()
	root.add_child(screen)
	screen.open()
	var found := false
	for button: Button in screen.find_children("*", "Button", true, false):
		if button.text == "Delete":
			found = true
	assert_true(found, "expected a Delete button for the test save")
	screen.queue_free()
	saves.delete_save(TEST_SLOT)
	gs.end_session()


func test_continue_label_names_the_character() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	var c := CharacterFactory.create("Continuer", gs.data, seeded_rng(8))
	gs.start_session(c)
	assert_true(saves.save_game(TEST_SLOT))
	var label := MainMenu.continue_label()
	assert_true(label.begins_with("Continue: "), label)
	assert_true(label.contains("Continuer"), label)
	assert_true(label.contains("age"), label)
	saves.delete_save(TEST_SLOT)
	gs.end_session()
