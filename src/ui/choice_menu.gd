class_name ChoiceMenu
extends PanelContainer
## Modal list of actions offered by an Interactable (see Interactable.menu_options).

signal closed

var _source: Node
var _title: Label
var _buttons: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(440, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 22, UIStyle.ACCENT)
	box.add_child(_title)
	_buttons = VBoxContainer.new()
	box.add_child(_buttons)


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
		b.tooltip_text = String(option.get("reason", ""))
		_buttons.add_child(b)
	_buttons.add_child(UIStyle.button("Leave", close))
	_focus_first.call_deferred()


func _choose(option: Dictionary) -> void:
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
