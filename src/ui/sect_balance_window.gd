class_name SectBalanceWindow
extends PanelContainer
## Read-only "Balance of power" window opened from the sect hall (WU-002):
## every sect ranked by strength, plus the sect rumors. ui_cancel or Close closes.

signal closed

var _body: RichTextLabel
var _close: Button


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	custom_minimum_size = Vector2(640, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Balance of power", 24, UIStyle.ACCENT))
	_body = RichTextLabel.new()
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(600, 0)
	_body.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(_body)
	_close = UIStyle.button("Close", close)
	box.add_child(_close)


static func window_text(c: CharacterData, standings: Array[Dictionary], rumors: PackedStringArray) -> String:
	var lines := PackedStringArray()
	var mine := String(c.sect.get("id", ""))
	for i in standings.size():
		var s := standings[i]
		var line := "%d. %s: %d disciples, strength %d" % [i + 1, s["name"], int(s["members"]), int(s["strength"])]
		if mine != "" and String(s["id"]) == mine:
			line += " (your sect)"
		lines.append(line)
	if not rumors.is_empty():
		lines.append("")
		lines.append_array(rumors)
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_body.text = window_text(GameState.player, GameState.sect_standings(), SectFactions.rumors(GameState.data, GameState.npcs))
	visible = true
	_close.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
