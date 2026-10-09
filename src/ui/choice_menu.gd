class_name ChoiceMenu
extends PanelContainer
## Modal list of actions offered by an Interactable (see Interactable.menu_options).

signal closed

## Screen height kept free for the title, description line and panel padding.
const MENU_MARGIN := 190.0

var _source: Node
var _title: Label
var _buttons: VBoxContainer
var _scroll: ScrollContainer
var _description: Label


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(440, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 22, UIStyle.ACCENT)
	box.add_child(_title)
	# Long menus (a sect's whole shop) scroll instead of running off the screen (WU-065).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_buttons)
	_description = UIStyle.label("", 14, Color(0.7, 0.7, 0.75))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(0, 40)
	box.add_child(_description)


func _ready() -> void:
	# Refit when the window or the UI scale changes while a menu is open (WU-068).
	get_viewport().size_changed.connect(_fit_scroll.call_deferred)
	Settings.changed.connect(_on_setting_changed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open_for(source: Node) -> void:
	_source = source
	_rebuild()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	if is_instance_valid(_source) and _source.has_method("on_menu_closed"):
		_source.on_menu_closed()
	_source = null
	closed.emit()


func _rebuild() -> void:
	for child in _buttons.get_children():
		child.queue_free()
	_title.text = _source.display_name
	var options: Array[Dictionary] = _source.menu_options()
	if options.is_empty():
		_buttons.add_child(UIStyle.label("There is nothing to do here.", 16))
	for option in options:
		var b := UIStyle.button(option["label"], _choose.bind(option))
		b.disabled = option.get("disabled", false)
		var reason: String = String(option.get("reason", ""))
		b.tooltip_text = reason
		var warn := b.disabled and reason != ""
		var line: String = reason if warn else String(option.get("description", ""))
		if b.disabled:
			b.focus_mode = Control.FOCUS_ALL
		b.focus_entered.connect(_show_line.bind(line, warn))
		b.mouse_entered.connect(_show_line.bind(line, warn))
		_buttons.add_child(b)
	var leave := UIStyle.button("Leave", close)
	leave.focus_entered.connect(_show_line.bind("", false))
	_buttons.add_child(leave)
	_description.text = ""
	_fit_scroll.call_deferred()
	_focus_first.call_deferred()


## Caps the button list's height so the title, description and a margin stay on screen.
func _fit_scroll() -> void:
	if not is_inside_tree():
		return
	var room := get_viewport_rect().size.y - MENU_MARGIN
	_scroll.custom_minimum_size.y = minf(_buttons.get_combined_minimum_size().y, maxf(room, 160.0))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "ui_scale":
		_fit_scroll.call_deferred()


func _show_line(text: String, warn: bool) -> void:
	_description.text = text
	_description.add_theme_color_override("font_color", UIStyle.CATEGORY_COLORS["warning"] if warn else Color(0.7, 0.7, 0.75))


func _choose(option: Dictionary) -> void:
	if option.get("disabled", false):
		return
	(option["action"] as Callable).call()
	if option.get("keep_open", false) and visible and GameState.player.alive:
		_rebuild()
	else:
		close()


func _focus_first() -> void:
	for child in _buttons.get_children():
		if child is Button and not child.disabled and not child.is_queued_for_deletion():
			child.grab_focus()
			return
