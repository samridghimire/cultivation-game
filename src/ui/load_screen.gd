class_name LoadScreen
extends PanelContainer
## Modal list of save slots (SaveManager.list_slots) used by the main menu and
## the pause menu. Choosing a slot emits slot_chosen; the owner does the load.
## Delete asks for a second press to confirm.

signal closed
signal slot_chosen(slot: String)

var _rows: VBoxContainer
var _status: Label
var _close_button: Button
var _pending_delete: String = ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(640, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Load Game", 26, UIStyle.ACCENT))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)
	_status = UIStyle.label("", 14, Color(0.7, 0.7, 0.7))
	box.add_child(_status)
	_close_button = UIStyle.button("Back", close)
	box.add_child(_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu")):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_pending_delete = ""
	_status.text = ""
	_rebuild()
	visible = true
	_focus_first.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## One line describing a slot, e.g. "Li Wei - Qi Refining 3 - Year 1, Spring 4 - age 16".
static func describe_slot(meta: Dictionary) -> String:
	if bool(meta.get("damaged", false)):
		return "%s: damaged save" % meta.get("slot", "?")
	if bool(meta.get("newer_version", false)):
		return "%s: made by a newer version of the game" % meta.get("slot", "?")
	var label := "Autosave: " if String(meta.get("slot", "")) == SaveManager.AUTOSAVE_SLOT else ""
	var text := label + "%s  |  %s  |  %s  |  age %d" % [meta.get("name", "?"), meta.get("realm_label", "?"), meta.get("game_date", "?"), int(meta.get("age", 0))]
	if not bool(meta.get("alive", true)):
		return "%s%s, fallen at age %d" % [label, meta.get("name", "?"), int(meta.get("age", 0))]
	return text


func _rebuild() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var slots := SaveManager.list_slots()
	if slots.is_empty():
		_rows.add_child(UIStyle.label("No saved games yet.", 18, Color(0.75, 0.75, 0.8)))
		return
	for meta in slots:
		var slot: String = meta["slot"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var load_button := UIStyle.button(describe_slot(meta), slot_chosen.emit.bind(slot))
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		load_button.disabled = bool(meta.get("damaged", false)) or bool(meta.get("newer_version", false)) or not bool(meta.get("alive", true))
		load_button.tooltip_text = "%s (saved %s)" % [slot, meta.get("saved_at", "")]
		row.add_child(load_button)
		var delete_button := UIStyle.button("Delete", Callable())
		delete_button.pressed.connect(_on_delete.bind(slot, delete_button))
		row.add_child(delete_button)
		_rows.add_child(row)


func _on_delete(slot: String, button: Button) -> void:
	if _pending_delete != slot:
		_pending_delete = slot
		button.text = "Sure?"
		_status.text = "Press again to delete %s." % slot
		return
	_pending_delete = ""
	if SaveManager.delete_save(slot):
		_status.text = "Deleted %s." % slot
	else:
		_status.text = "Could not delete %s." % slot
	_rebuild()
	_focus_first.call_deferred()


func _focus_first() -> void:
	var buttons := _rows.find_children("*", "Button", true, false)
	if buttons.is_empty():
		_close_button.grab_focus()
	else:
		(buttons[0] as Button).grab_focus()
