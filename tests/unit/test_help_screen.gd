extends TestCase
## UI-003: help pages load from data/help.json and the help screen lists the
## Controls page (from InputConfig) plus every page.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_help_pages_load_and_validate() -> void:
	var d := data()
	assert_eq(d.load_errors.size(), 0, ", ".join(d.load_errors))
	assert_gt(d.help_pages.size(), 3)
	var ids: Array = d.help_pages.map(func(p): return p["id"])
	assert_true(ids.has("cultivate"), str(ids))
	assert_true(d.help_action_names.has("interact"))


func test_control_rows_list_keyboard_and_gamepad() -> void:
	var rows := HelpScreen.control_rows(
		{"interact": [KEY_E], "pause_menu": [KEY_ESCAPE]},
		{"interact": [JOY_BUTTON_A], "pause_menu": [JOY_BUTTON_START], "pad_only": [JOY_BUTTON_RIGHT_SHOULDER]},
		{"interact": [JOY_AXIS_RIGHT_Y, -1.0]},
		{"interact": "Interact"})
	assert_eq(rows.size(), 3)
	assert_eq(rows[0], ["Interact", "E", "A, Right stick Up"])
	assert_eq(rows[1], ["pause_menu", "Escape", "Start"])
	assert_eq(rows[2], ["pad_only", "", "RB"])
	var text := HelpScreen.controls_text(rows)
	assert_true(text.contains("[cell]-   [/cell]"), "missing bindings show a dash")


func test_every_input_action_has_a_help_name() -> void:
	var names := data().help_action_names
	var input_config := _root().get_node("InputConfig")
	for action in input_config.KEYS.keys() + input_config.JOY_BUTTONS.keys():
		assert_true(names.has(action), "help.json action_names is missing '%s'" % action)


func test_screen_shows_controls_then_pages() -> void:
	var screen := HelpScreen.new()
	_root().add_child(screen)
	screen.open()
	assert_true(screen.visible)
	assert_eq(screen._page_buttons.size(), data().help_pages.size() + 1)
	assert_eq(screen._title.text, "Controls")
	var text := screen._body.get_parsed_text()
	assert_true(text.contains("Character sheet"), text)
	assert_true(text.contains("Start"), text)
	var first: Dictionary = data().help_pages[0]
	screen._page_buttons[1].pressed.emit()
	assert_eq(screen._title.text, first["title"])
	assert_true(screen._body.get_parsed_text().contains(String(first["body"][0]).left(30)))
	screen.close()
	assert_false(screen.visible)
	screen.free()
