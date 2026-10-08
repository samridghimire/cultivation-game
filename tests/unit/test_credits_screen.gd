extends TestCase
## REL-003: credits screen from the main menu.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_credits_text_has_engine_license_and_third_party() -> void:
	var text := CreditsScreen.credits_text()
	assert_true(text.contains("Made with Godot Engine"))
	assert_true(text.contains(Engine.get_license_text().substr(0, 40)), "includes the Godot license text")
	assert_true(text.contains("Procedural sound effects"), "third-party list from data/credits.json")


func test_main_menu_opens_credits_with_focus_and_closes() -> void:
	var root := _tree().root
	var menu: Node = load("res://src/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	var button: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "Credits":
			button = b
	assert_true(button != null, "main menu has a Credits button")
	button.pressed.emit()
	await _tree().process_frame
	await _tree().process_frame
	var credits: CreditsScreen = menu.credits_screen()
	assert_true(credits.visible)
	var owner := root.gui_get_focus_owner()
	assert_true(owner != null and credits.is_ancestor_of(owner), "focus is inside credits")
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	root.push_input(ev)
	await _tree().process_frame
	assert_false(credits.visible, "ui_cancel closes")
	assert_true(menu._menu.visible)
	menu.queue_free()
