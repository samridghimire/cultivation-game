class_name CreditsScreen
extends PanelContainer
## Credits (REL-003): title, the Godot Engine notice and license text (required
## for release) and the third-party list from data/credits.json. Scrollable;
## ui_cancel or Back closes.

signal closed

const DATA_PATH := "res://data/credits.json"

var _body: RichTextLabel
var _back: Button


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	custom_minimum_size = Vector2(900, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Credits", 24, UIStyle.ACCENT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_body = RichTextLabel.new()
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 16)
	scroll.add_child(_body)
	_back = UIStyle.button("Back", close)
	box.add_child(_back)


## The credits text: title, engine notice, third-party list, then the Godot license.
static func credits_text() -> String:
	var lines := PackedStringArray()
	lines.append(str(ProjectSettings.get_setting("application/config/name")))
	lines.append("")
	lines.append("Made with Godot Engine (https://godotengine.org)")
	lines.append("")
	lines.append("Third-party:")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		for entry: Dictionary in parsed.get("third_party", []):
			lines.append("- %s: %s (%s)" % [entry.get("name", "?"), entry.get("what", ""), entry.get("license", "?")])
	lines.append("")
	lines.append("Godot Engine license:")
	lines.append(Engine.get_license_text())
	return "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_body.text = credits_text()
	visible = true
	_back.grab_focus.call_deferred()


func close() -> void:
	visible = false
	closed.emit()
