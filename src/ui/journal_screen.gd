class_name JournalScreen
extends PanelContainer
## Read-only journal (WU-007): "what can I do now?" Renders Guidance.journal
## grouped by section. Gamepad: right stick scrolls, B closes.

signal closed

const SCROLL_SPEED := 900.0
const DIM := Color(0.6, 0.6, 0.6)

var _scroll: ScrollContainer
var _text: RichTextLabel
var _close_button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(760, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Journal", 24, UIStyle.ACCENT))
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(736, 440)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 15)
	_scroll.add_child(_text)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	box.add_child(footer)
	_close_button = UIStyle.button("Close", close)
	footer.add_child(_close_button)
	footer.add_child(UIStyle.label("[PgUp/PgDn] or right stick: scroll", 14, DIM))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if not visible:
		return
	var dir := Input.get_axis("scroll_up", "scroll_down")
	if dir != 0.0:
		_scroll.scroll_vertical += int(dir * SCROLL_SPEED * delta)


func open() -> void:
	_text.clear()
	_text.append_text(format_entries(entries()))
	_scroll.scroll_vertical = 0
	visible = true
	_close_button.grab_focus.call_deferred()


## The journal for the current session.
static func entries() -> Array[Dictionary]:
	var p := GameState.player
	var density := GameState.region_qi_density() * Sects.cultivation_bonus(p, GameState.data)
	return Guidance.journal(p, GameState.data, GameState.world_flags, GameClock.total_days, GameState.world_events, GameState.npcs, density, GameState.current_region)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## BBCode for journal `entries`: a heading per section, a bullet per line.
static func format_entries(entries: Array) -> String:
	var out := PackedStringArray()
	var last := ""
	for e: Dictionary in entries:
		var section := String(e["section"])
		if section != last:
			if last != "":
				out.append("")
			out.append("[color=#%s]%s[/color]" % [UIStyle.ACCENT.to_html(false), section])
			last = section
		out.append("  - %s" % String(e["text"]).replace("[", "[lb]"))
	return "\n".join(out)
