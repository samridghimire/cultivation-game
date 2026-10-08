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


func test_no_two_actions_share_a_key_or_button() -> void:
	# The HUD opens the first screen whose action matches, so a shared binding
	# makes the later screen unreachable.
	var input_config := _root().get_node("InputConfig")
	for table: Dictionary in [input_config.KEYS, input_config.JOY_BUTTONS]:
		var owner := {}
		for action: String in table:
			for code in table[action]:
				assert_false(owner.has(code), "'%s' and '%s' share binding %s" % [owner.get(code, ""), action, code])
				owner[code] = action


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


func test_main_menu_help_opens_without_a_session() -> void:
	var menu: Node = load("res://src/ui/main_menu.tscn").instantiate()
	_root().add_child(menu)
	var help_button: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "Help":
			help_button = b
	assert_true(help_button != null, "main menu has a Help button")
	help_button.pressed.emit()
	var help: HelpScreen = menu.help_screen()
	assert_true(help.visible, "help opens")
	assert_false(menu._menu.visible, "title buttons hidden behind help")
	help.close()
	assert_false(help.visible)
	assert_true(menu._menu.visible, "closing help returns to the title menu")
	menu.queue_free()


func test_binding_label_and_key_bar_follow_device_and_rebinds() -> void:
	var ic: Node = InputConfig
	var hints: Array = load("res://src/ui/hud.gd").KEY_HINTS
	var saved_path: String = ic.path
	ic.path = "user://test_controls_fh012.cfg"
	ic.reset_controls()
	assert_eq(ic.binding_label("interact", false), "E")
	assert_eq(ic.binding_label("interact", true), "A")
	assert_eq(ic.binding_label("quick_save", true), "", "no gamepad binding")
	ic.last_input_joypad = false
	assert_true(ic.key_bar_text(hints).contains("[E] interact"))
	assert_true(ic.key_bar_text(hints).contains("[F5] save"))
	ic.last_input_joypad = true
	var pad_bar: String = ic.key_bar_text(hints)
	assert_true(pad_bar.contains("[A] interact"), pad_bar)
	assert_false(pad_bar.contains("save"))
	ic.last_input_joypad = false
	ic.rebind_key("interact", KEY_F)
	assert_true(ic.key_bar_text(hints).contains("[F] interact"))
	ic.reset_controls()
	ic.path = saved_path
	DirAccess.remove_absolute("user://test_controls_fh012.cfg")
