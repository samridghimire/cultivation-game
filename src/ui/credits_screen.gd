class_name CreditsScreen
extends PanelContainer
## Credits (REL-003): title, the Godot Engine notice and license text (required
## for release) and the third-party list from data/credits.json. Scrollable;
## ui_cancel or Back closes.

signal closed

const SCROLL_SPEED := 900.0
const DIM := Color(0.6, 0.6, 0.6)
const DATA_PATH := "res://data/credits.json"

var _body: RichTextLabel
var _back: Button
var _scroll: ScrollContainer


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
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(860, 480)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_body = RichTextLabel.new()
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 16)
	_scroll.add_child(_body)
	box.add_child(UIStyle.label("Right stick / PgUp, PgDn: scroll    B / Esc: back", 14, DIM))
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
	lines.append_array(third_party_notices())
	return "\n".join(lines)


## Godot's bundled third-party components (FreeType, ENet, mbedTLS...) with their
## licenses, as its "Complying with licenses" page requires.
static func third_party_notices() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("")
	lines.append("Third-party components bundled with Godot:")
	var used := {}
	for comp: Dictionary in Engine.get_copyright_info():
		var licenses := {}
		var holders := PackedStringArray()
		for part: Dictionary in comp.get("parts", []):
			licenses[str(part.get("license", "?"))] = true
			for c: String in part.get("copyright", []):
				if not holders.has(c):
					holders.append(c)
		for l: String in licenses:
			used[l] = true
		lines.append("")
		lines.append("%s (%s)" % [comp.get("name", "?"), ", ".join(PackedStringArray(licenses.keys()))])
		for h in holders:
			lines.append("  (c) " + h)
	var texts: Dictionary = Engine.get_license_info()
	lines.append("")
	lines.append("License texts:")
	for l: String in used:
		for name: String in l.split(" and "):
			if texts.has(name.strip_edges()):
				lines.append("")
				lines.append(name.strip_edges())
				lines.append(str(texts[name.strip_edges()]))
	return lines


func _process(delta: float) -> void:
	if not visible:
		return
	var dir := Input.get_axis("scroll_up", "scroll_down")
	if dir != 0.0:
		_scroll.scroll_vertical += int(dir * SCROLL_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_body.text = credits_text()
	_scroll.scroll_vertical = 0
	visible = true
	_back.grab_focus.call_deferred()


func close() -> void:
	visible = false
	closed.emit()
