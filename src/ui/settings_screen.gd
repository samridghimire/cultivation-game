class_name SettingsScreen
extends PanelContainer
## Modal settings editor used by the main menu and the pause menu. Every
## change is applied and saved immediately through the Settings autoload.

signal closed

const SLIDERS := [
	["ui_scale", "UI Scale"],
	["master_volume", "Master Volume"],
	["music_volume", "Music Volume"],
	["sfx_volume", "Effects Volume"],
]

var _fullscreen: CheckButton
var _hints: CheckButton
var _sliders: Dictionary = {}  # setting key -> HSlider
var _value_labels: Dictionary = {}  # setting key -> Label


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(480, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	box.add_child(UIStyle.label("Settings", 26, UIStyle.ACCENT))

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
	buttons.add_child(UIStyle.button("Reset to Defaults", _reset))
	buttons.add_child(UIStyle.button("Close", close))


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_sync()
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
	for key in _sliders:
		_sliders[key].set_value_no_signal(Settings.get_value(key))
		_value_labels[key].text = format_value(key, Settings.get_value(key))


func _on_slider(value: float, key: String) -> void:
	_value_labels[key].text = format_value(key, value)
	Settings.set_value(key, value)


func _reset() -> void:
	Settings.reset_to_defaults()
	_sync()
