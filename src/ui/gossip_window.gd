class_name GossipWindow
extends PanelContainer
## Read-only "Gossip" window opened by a merchant's "Ask about rumors" (WU-111):
## the lines GameState.hear_rumors posted, readable instead of scrolling past
## in the message log. ui_cancel or Close closes.

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
	box.add_child(UIStyle.label("Gossip", 24, UIStyle.ACCENT))
	_body = RichTextLabel.new()
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(600, 0)
	_body.add_theme_font_size_override("normal_font_size", 16)
	box.add_child(_body)
	_close = UIStyle.button("Close", close)
	box.add_child(_close)


static func window_text(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return "Nobody has anything to tell you."
	return "\n\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open(lines: PackedStringArray) -> void:
	_body.text = window_text(lines)
	visible = true
	_close.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()
