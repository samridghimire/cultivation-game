extends TestCase
## UI-003c: remappable controls (InputConfig rebinding and the Settings page).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _input_config() -> Node:
	return _root().get_node("InputConfig")


func test_rebound_swaps_on_conflict() -> void:
	var bindings := {"a": [KEY_E], "b": [KEY_Q, KEY_Z], "c": [KEY_R]}
	var out := InputConfig.rebound(bindings, "a", KEY_Q)
	assert_eq(out["a"], [KEY_Q])
	assert_eq(out["b"], [KEY_E, KEY_Z], "b takes a's old key")
	assert_eq(bindings["a"], [KEY_E], "input untouched")
	out = InputConfig.rebound(bindings, "c", KEY_Z)
	assert_eq(out["c"], [KEY_Z])
	assert_eq(out["b"], [KEY_Q, KEY_R])
	assert_eq(InputConfig.rebound(bindings, "a", KEY_E), bindings, "same key: no change")


func test_rebind_applies_saves_and_resets() -> void:
	var ic := _input_config()
	var old_path: String = ic.path
	ic.path = "user://test_controls.cfg"
	ic.reset_controls()
	ic.rebind_key("interact", KEY_F)
	assert_eq(ic.keys["interact"][0], KEY_F)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F
	assert_true(InputMap.action_has_event("interact", ev), "the InputMap follows the rebind")
	ic.rebind_joy("interact", JOY_BUTTON_B)
	assert_eq(ic.joy_buttons["interact"][0], JOY_BUTTON_B)
	ic.load_controls()
	assert_eq(ic.keys["interact"][0], KEY_F, "saved and loaded")
	ic.reset_controls()
	assert_eq(ic.keys["interact"], InputConfig.KEYS["interact"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ic.path))
	ic.path = old_path
	ic.load_controls()
	ic.apply()


func test_settings_controls_page_rebinds() -> void:
	var ic := _input_config()
	var old_path: String = ic.path
	ic.path = "user://test_controls.cfg"
	ic.reset_controls()
	var screen := SettingsScreen.new()
	_root().add_child(screen)
	screen.open()
	screen._show_controls(true)
	var key_button := screen._control_grid.get_node("key_toggle_map") as Button
	assert_eq(key_button.text, OS.get_keycode_string(KEY_M))
	key_button.pressed.emit()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_N
	ev.pressed = true
	assert_true(screen.rebind_with(ev))
	assert_eq(ic.keys["toggle_map"][0], KEY_N)
	assert_eq((screen._control_grid.get_node("key_toggle_map") as Button).text, OS.get_keycode_string(KEY_N))
	(screen._control_grid.get_node("key_interact") as Button).pressed.emit()
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	assert_true(screen.rebind_with(esc))
	assert_eq(ic.keys["interact"], InputConfig.KEYS["interact"], "Esc cancels")
	screen.free()
	ic.reset_controls()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ic.path))
	ic.path = old_path
	ic.load_controls()
	ic.apply()
