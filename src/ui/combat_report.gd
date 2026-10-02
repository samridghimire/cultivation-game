class_name CombatReport
extends PanelContainer
## Modal blow-by-blow report shown after a fight (EventBus.combat_finished).

signal closed

var _title: Label
var _log: RichTextLabel
var _close_button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel().get_theme_stylebox("panel"))
	custom_minimum_size = Vector2(620, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 24)
	box.add_child(_title)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(596, 360)
	_log.add_theme_font_size_override("normal_font_size", 15)
	box.add_child(_log)
	_close_button = UIStyle.button("Continue", close)
	box.add_child(_close_button)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func show_fight(enemy_name: String, victory: bool, lines: PackedStringArray) -> void:
	var color: Color = UIStyle.ACCENT if victory else UIStyle.CATEGORY_COLORS["danger"]
	_title.text = "%s: %s" % ["Victory" if victory else "Defeat", enemy_name]
	_title.add_theme_color_override("font_color", color)
	_log.clear()
	for i in lines.size():
		var line := lines[i]
		if i == 0 or i == lines.size() - 1:
			line = "[color=#%s]%s[/color]" % [color.to_html(false), line]
		_log.append_text(line + "\n")
	visible = true
	_close_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
