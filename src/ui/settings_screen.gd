class_name SettingsScreen
extends PanelContainer
## Modal settings editor used by the main menu and the pause menu. Every
## change is applied and saved immediately through the Settings autoload.
## A Controls page (UI-003c) lists every action with its first key and first
## gamepad button; "Rebind" waits for the next key / button press (Esc cancels
## a key rebind) and InputConfig swaps bindings on conflicts and saves them.

signal closed

const SLIDERS := [
	["ui_scale", "UI Scale"],
	["master_volume", "Master Volume"],
	["music_volume", "Music Volume"],
	["sfx_volume", "Effects Volume"],
]

var _fullscreen: CheckButton
var _hints: CheckButton
var _autosave: CheckButton
var _fast_skips: CheckButton
var _sliders: Dictionary = {}  # setting key -> HSlider
var _value_labels: Dictionary = {}  # setting key -> Label
var _general: VBoxContainer
var _controls: VBoxContainer
var _control_grid: GridContainer
var _control_status: Label
var _controls_button: Button
## [action, "key" | "joy"] while waiting for a press to rebind, else [].
var _waiting: Array = []


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(480, 0)
	visible = false
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	add_child(outer)
	outer.add_child(UIStyle.label("Settings", 26, UIStyle.ACCENT))
	_general = VBoxContainer.new()
	_general.add_theme_constant_override("separation", 12)
	outer.add_child(_general)
	var box := _general
	_build_controls(outer)

	_fullscreen = CheckButton.new()
	_fullscreen.text = "Fullscreen"
	_fullscreen.add_theme_font_size_override("font_size", 18)
	_fullscreen.toggled.connect(func(on: bool): Settings.set_value("window_mode", "fullscreen" if on else "windowed"))
	box.add_child(_fullscreen)
	_hints = CheckButton.new()
	_hints.text = "Show next-step hint on the HUD"
	_hints.add_theme_font_size_override("font_size", 18)
	_hints.toggled.connect(func(on: bool): Settings.set_value("show_hints", on))
	box.add_child(_hints)
	_autosave = CheckButton.new()
	_autosave.text = "Autosave (travel, breakthroughs, monthly)"
	_autosave.add_theme_font_size_override("font_size", 18)
	_autosave.toggled.connect(func(on: bool): Settings.set_value("autosave", on))
	box.add_child(_autosave)

	_fast_skips = CheckButton.new()
	_fast_skips.text = "Fast time skips (no meditation/travel overlay)"
	_fast_skips.add_theme_font_size_override("font_size", 18)
	_fast_skips.toggled.connect(func(on: bool): Settings.set_value("fast_time_skips", on))
	box.add_child(_fast_skips)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	box.add_child(grid)
	for entry in SLIDERS:
		var key: String = entry[0]
		grid.add_child(UIStyle.label(entry[1], 16))
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(220, 24)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if key == "ui_scale":
			slider.min_value = Settings.UI_SCALE_RANGE.x
			slider.max_value = Settings.UI_SCALE_RANGE.y
			slider.step = 0.05
		else:
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.05
		# Scale only applies on release so the panel doesn't resize mid-drag.
		if key == "ui_scale":
			slider.value_changed.connect(func(v: float): _value_labels[key].text = format_value(key, v))
			slider.drag_ended.connect(func(_changed: bool): Settings.set_value(key, slider.value))
		else:
			slider.value_changed.connect(_on_slider.bind(key))
		grid.add_child(slider)
		var value_label := UIStyle.label("", 16)
		value_label.custom_minimum_size = Vector2(56, 0)
		grid.add_child(value_label)
		_sliders[key] = slider
		_value_labels[key] = value_label

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_controls_button = UIStyle.button("Controls...", _show_controls.bind(true))
	buttons.add_child(_controls_button)
	buttons.add_child(UIStyle.button("Reset to Defaults", _reset))
	buttons.add_child(UIStyle.button("Close", close))


func _build_controls(outer: VBoxContainer) -> void:
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 10)
	_controls.visible = false
	outer.add_child(_controls)
	_control_status = UIStyle.label("Pick an action to rebind.", 15, Color(0.75, 0.75, 0.75))
	_controls.add_child(_control_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_controls.add_child(scroll)
	_control_grid = GridContainer.new()
	_control_grid.columns = 3
	_control_grid.add_theme_constant_override("h_separation", 12)
	_control_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_control_grid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_controls.add_child(row)
	row.add_child(UIStyle.button("Reset Controls", _reset_controls))
	var back := UIStyle.button("Back", _show_controls.bind(false))
	back.name = "ControlsBack"
	row.add_child(back)


## Actions shown on the Controls page: every action with a key or button.
static func control_actions() -> Array:
	var out: Array = InputConfig.KEYS.keys()
	for action in InputConfig.JOY_BUTTONS:
		if not out.has(action):
			out.append(action)
	return out


func _rebuild_controls() -> void:
	for child in _control_grid.get_children():
		_control_grid.remove_child(child)
		child.queue_free()
	var names: Dictionary = GameState.data.help_action_names if GameState.data != null else {}
	for action in control_actions():
		_control_grid.add_child(UIStyle.label(String(names.get(action, String(action).capitalize())), 15))
		var key_list: Array = InputConfig.keys.get(action, [])
		var key_button := UIStyle.button(OS.get_keycode_string(key_list[0]) if not key_list.is_empty() else "-", _start_rebind.bind(action, "key"))
		key_button.name = "key_" + action
		key_button.custom_minimum_size = Vector2(150, 0)
		_control_grid.add_child(key_button)
		var joy_list: Array = InputConfig.joy_buttons.get(action, [])
		var joy_button := UIStyle.button(HelpScreen.JOY_BUTTON_NAMES.get(joy_list[0], "Button %d" % joy_list[0]) if not joy_list.is_empty() else "-", _start_rebind.bind(action, "joy"))
		joy_button.name = "joy_" + action
		joy_button.custom_minimum_size = Vector2(150, 0)
		_control_grid.add_child(joy_button)


func _show_controls(on: bool) -> void:
	_waiting = []
	_general.visible = not on
	_controls.visible = on
	if on:
		_rebuild_controls()
		_control_status.text = "Pick an action to rebind."
		_grab_later(_control_grid.get_child(1) as Button)
	else:
		_grab_later(_controls_button)


func _start_rebind(action: String, kind: String) -> void:
	_waiting = [action, kind]
	var names: Dictionary = GameState.data.help_action_names if GameState.data != null else {}
	_control_status.text = ("Press a key for %s (Esc cancels)." if kind == "key" else "Press a gamepad button for %s.") % names.get(action, action)


## Finishes a pending rebind with `event`. Returns true if it was used.
func rebind_with(event: InputEvent) -> bool:
	if _waiting.is_empty() or not event.is_pressed() or event.is_echo():
		return false
	var action := String(_waiting[0])
	if _waiting[1] == "key" and event is InputEventKey:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_NONE:
			key = (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			_control_status.text = "Rebind cancelled."
		else:
			InputConfig.rebind_key(action, key)
			_control_status.text = "%s is now on %s." % [action, OS.get_keycode_string(key)]
	elif _waiting[1] == "joy" and event is InputEventJoypadButton:
		InputConfig.rebind_joy(action, (event as InputEventJoypadButton).button_index)
		_control_status.text = "Bound."
	else:
		return false
	var focus_name := ("key_" if _waiting[1] == "key" else "joy_") + action
	_waiting = []
	_rebuild_controls()
	_grab_later(_control_grid.get_node_or_null(focus_name) as Button)
	return true


## Focuses `b` next frame if it is still on screen (gamepad focus).
func _grab_later(b: Control) -> void:
	_grab_now.call_deferred(b)


func _grab_now(b: Control) -> void:
	if is_instance_valid(b) and b.is_inside_tree() and b.is_visible_in_tree():
		b.grab_focus()


func _reset_controls() -> void:
	InputConfig.reset_controls()
	_rebuild_controls()
	_control_status.text = "Controls reset to the defaults."


func _input(event: InputEvent) -> void:
	if visible and not _waiting.is_empty() and rebind_with(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		get_viewport().set_input_as_handled()
		if _controls.visible:
			_show_controls(false)
		else:
			close()


func open() -> void:
	_sync()
	_general.visible = true
	_controls.visible = false
	_waiting = []
	visible = true
	_fullscreen.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	# A keyboard/gamepad change to UI scale never fires drag_ended.
	var scale_slider: HSlider = _sliders["ui_scale"]
	if not is_equal_approx(scale_slider.value, Settings.get_value("ui_scale")):
		Settings.set_value("ui_scale", scale_slider.value)
	visible = false
	closed.emit()


static func format_value(key: String, value: float) -> String:
	if key == "ui_scale":
		return "%d%%" % roundi(value * 100)
	return "%d%%" % roundi(value * 100) if value > 0.0 else "Off"


func _sync() -> void:
	_fullscreen.set_pressed_no_signal(Settings.get_value("window_mode") == "fullscreen")
	_hints.set_pressed_no_signal(Settings.get_value("show_hints"))
	_autosave.set_pressed_no_signal(Settings.get_value("autosave"))
	_fast_skips.set_pressed_no_signal(Settings.get_value("fast_time_skips"))
	for key in _sliders:
		_sliders[key].set_value_no_signal(Settings.get_value(key))
		_value_labels[key].text = format_value(key, Settings.get_value(key))


func _on_slider(value: float, key: String) -> void:
	_value_labels[key].text = format_value(key, value)
	Settings.set_value(key, value)


func _reset() -> void:
	Settings.reset_to_defaults()
	_sync()
