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
	for id: String in ["merchant_gossip", "friends_price", "festival_activities", "qi_rich_regions", "first_fighting_style", "secret_realm_word"]:
		assert_true(ids.has(id), "help page " + id)


func test_rival_moods_and_goals_pages() -> void:
	var by_id := {}
	for page in data().help_pages:
		by_id[page["id"]] = page
	assert_true(by_id.has("rival_attitudes"), "C-099 rival moods page")
	assert_true(by_id.has("goals"), "C-104 goals page")
	var rival := " ".join(by_id["rival_attitudes"]["body"])
	for word: String in ["friendly", "bitter", "bout", "amends"]:
		assert_true(rival.contains(word), "rival page mentions " + word)
	for word: String in ["answers any challenge", "bout record", "someone new names you", "no successor"]:
		assert_true(rival.contains(word), "rival page mentions " + word)
	var goals := " ".join(by_id["goals"]["body"])
	for word: String in ["Foundation", "Core Formation", "Goal done", "suggestions"]:
		assert_true(goals.contains(word), "goals page mentions " + word)


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
	assert_true(pad_bar.contains("[RT] family"), "trigger-bound actions show in the gamepad key bar: " + pad_bar)
	ic.last_input_joypad = false
	ic.rebind_key("interact", KEY_F)
	assert_true(ic.key_bar_text(hints).contains("[F] interact"))
	ic.reset_controls()
	ic.path = saved_path
	DirAccess.remove_absolute("user://test_controls_fh012.cfg")


func test_help_key_has_keyboard_binding_and_hint() -> void:
	var input_config := _root().get_node("InputConfig")
	assert_true(input_config.KEYS.has("toggle_help"))
	assert_true(input_config.KEYS["toggle_help"].has(KEY_F1))
	assert_true(data().help_action_names.has("toggle_help"))
	var hinted := false
	for pair in load("res://src/ui/hud.gd").KEY_HINTS:
		hinted = hinted or pair[0] == "toggle_help"
	assert_true(hinted, "KEY_HINTS lists toggle_help")


func test_help_key_opens_help_and_close_returns_to_world() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Helper", gs.data, seeded_rng()))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	var ev := InputEventAction.new()
	ev.action = "toggle_help"
	ev.pressed = true
	hud._unhandled_input(ev)
	assert_true(hud._help.visible)
	hud._help.close()
	assert_false(hud._help.visible)
	assert_false(hud._pause_menu.visible, "help from its key does not open the pause menu")
	hud.free()


func test_c097_tribulation_page_explains_the_readiness_line() -> void:
	var page: Dictionary = {}
	for p: Dictionary in data().help_pages:
		if p["id"] == "tribulation":
			page = p
	var text := " ".join(PackedStringArray(page["body"]))
	for needle: String in ["Heavenly Tribulation ahead", "would not survive", "shield talismans", "defense technique", "armor", "Constitution", "heart demon"]:
		assert_true(text.contains(needle), needle)


## C-105: help pages sit in groups; every page has a known group and every group has pages.
func test_help_pages_are_grouped() -> void:
	var d := data()
	assert_eq(d.help_groups.size(), 6)
	var known := {}
	for g in d.help_groups:
		known[g["id"]] = 0
	var last_index := -1
	var ids: Array = d.help_groups.map(func(g): return g["id"])
	for page in d.help_pages:
		assert_true(known.has(page.get("group", "")), "page %s has a known group" % page["id"])
		known[page["group"]] += 1
		var idx := ids.find(page["group"])
		assert_true(idx >= last_index, "page %s is listed with its group, in group order" % page["id"])
		last_index = idx
	for gid: String in known:
		assert_gt(int(known[gid]), 0, "group %s has a page" % gid)


func test_help_validation_catches_bad_groups() -> void:
	var d := GameData.load_from_dir()
	d.help_pages[0]["group"] = "nope"
	d.help_groups.append({"id": "start", "title": "Again"})
	d._validate_help()
	assert_gt(d.load_errors.size(), 1)


func test_list_shows_group_headers_and_focus_stays_on_buttons() -> void:
	var screen := HelpScreen.new()
	_root().add_child(screen)
	screen.open()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var list: VBoxContainer = screen._list
	var headers := 0
	var buttons := 0
	for child in list.get_children():
		if child is Button:
			buttons += 1
		elif child is Label:
			headers += 1
	assert_eq(headers, data().help_groups.size(), "one header per group")
	assert_eq(buttons, data().help_pages.size() + 1, "Controls + every page")
	assert_true(list.get_child(0) is Button, "Controls stays first")
	assert_true(screen.get_viewport().gui_get_focus_owner() is Button, "focus on a button")
	assert_eq(HelpScreen.group_title([{"id": "a", "title": "Alpha"}], "a"), "Alpha")
	screen.queue_free()
