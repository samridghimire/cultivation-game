class_name HelpScreen
extends PanelContainer
## Modal help opened from the pause menu: a Controls page generated from the
## InputConfig bindings (keyboard and gamepad), then the pages in data/help.json.
## Gamepad: up/down picks a page, B closes.

signal closed

const CONTROLS_ID := "controls"
const JOY_BUTTON_NAMES := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
}
const JOY_AXIS_NAMES := {
	JOY_AXIS_LEFT_X: ["Left stick Left", "Left stick Right"],
	JOY_AXIS_LEFT_Y: ["Left stick Up", "Left stick Down"],
	JOY_AXIS_RIGHT_X: ["Right stick Left", "Right stick Right"],
	JOY_AXIS_RIGHT_Y: ["Right stick Up", "Right stick Down"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "LT"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "RT"],
}
const MENU_HINT := "In menus: arrow keys / d-pad move, Enter / A chooses, Esc / B goes back.\nRebind keys and buttons in Settings > Controls."

var _list: VBoxContainer
var _title: Label
var _body: RichTextLabel
var _page_buttons: Array[Button] = []
var _page := ""


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	custom_minimum_size = Vector2(900, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Help", 24, UIStyle.ACCENT))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(260, 0)
	# Many pages: the list scrolls (it follows focus) instead of growing past a Steam Deck screen.
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(280, 540)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.add_child(_list)
	columns.add_child(list_scroll)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(details)
	_title = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(scroll)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 16)
	_body.add_theme_font_size_override("bold_font_size", 16)
	scroll.add_child(_body)

	box.add_child(UIStyle.button("Back", close))


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_build_list()
	_show_page(CONTROLS_ID)
	visible = true
	_page_buttons[0].grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## [action name, keyboard keys, gamepad inputs] for every bound action, in
## InputConfig order. `names` maps action ids to display names.
static func control_rows(keys: Dictionary, joy_buttons: Dictionary, joy_axes: Dictionary, names: Dictionary) -> Array:
	var actions: Array = keys.keys()
	for action in joy_buttons.keys() + joy_axes.keys():
		if not actions.has(action):
			actions.append(action)
	var rows: Array = []
	for action in actions:
		var keyboard := PackedStringArray()
		for key in keys.get(action, []):
			keyboard.append(OS.get_keycode_string(key))
		var pad := PackedStringArray()
		for button in joy_buttons.get(action, []):
			pad.append(JOY_BUTTON_NAMES.get(button, "Button %d" % button))
		if joy_axes.has(action):
			var axis: int = joy_axes[action][0]
			var side := 0 if float(joy_axes[action][1]) < 0.0 else 1
			pad.append(JOY_AXIS_NAMES[axis][side] if JOY_AXIS_NAMES.has(axis) else "Axis %d" % axis)
		rows.append([String(names.get(action, action)), ", ".join(keyboard), ", ".join(pad)])
	return rows


## BBCode for the Controls page.
static func controls_text(rows: Array) -> String:
	var dim := Color(0.7, 0.7, 0.7).to_html(false)
	var out := "[table=3][cell][color=#%s]Action[/color][/cell][cell][color=#%s]Keyboard[/color][/cell][cell][color=#%s]Gamepad[/color][/cell]" % [dim, dim, dim]
	for row in rows:
		out += "[cell]%s   [/cell][cell]%s   [/cell][cell]%s[/cell]" % [row[0], row[1] if row[1] != "" else "-", row[2] if row[2] != "" else "-"]
	return out + "[/table]\n\n" + MENU_HINT


## BBCode for one data/help.json page.
static func page_text(page: Dictionary) -> String:
	return "\n\n".join(PackedStringArray(page.get("body", [])))


func _build_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_page_buttons.clear()
	_add_page_button(CONTROLS_ID, "Controls")
	for page: Dictionary in GameState.data.help_pages:
		_add_page_button(page["id"], page["title"])


func _add_page_button(id: String, title: String) -> void:
	var b := UIStyle.button(title, _show_page.bind(id))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Moving focus with the d-pad shows the page right away.
	b.focus_entered.connect(_show_page.bind(id))
	_list.add_child(b)
	_page_buttons.append(b)


func _show_page(id: String) -> void:
	_page = id
	_body.clear()
	if id == CONTROLS_ID:
		_title.text = "Controls"
		_body.append_text(controls_text(control_rows(InputConfig.keys, InputConfig.joy_buttons, InputConfig.JOY_AXES, GameState.data.help_action_names)))
		return
	for page: Dictionary in GameState.data.help_pages:
		if page["id"] == id:
			_title.text = page["title"]
			_body.append_text(page_text(page))
