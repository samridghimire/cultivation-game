class_name JournalScreen
extends PanelContainer
## Read-only journal (WU-007): "what can I do now?" Renders Guidance.journal
## grouped by section. Gamepad: right stick scrolls, B closes.

signal closed
## WU-414: the "Village book" button at the end of the Around the village card.
signal book_requested

const SCROLL_SPEED := 900.0
const DIM := Color(0.6, 0.6, 0.6)

var _scroll: ScrollContainer
var _cards: VBoxContainer
## Every card's text joined, for tests and search.
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
	_text.visible = false
	add_child(_text)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", 8)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cards)
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
	var list := entries()
	_text.clear()
	_text.append_text(format_entries(list))
	_build_cards(list)
	_scroll.scroll_vertical = 0
	visible = true
	_close_button.grab_focus.call_deferred()


## The journal for the current session.
static func entries() -> Array[Dictionary]:
	return GameState.journal_entries()


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
		var line := "  - %s" % String(e["text"]).replace("[", "[lb]")
		match String(e.get("tone", "normal")):
			"warning":
				line = "[color=#%s]%s[/color]" % [(UIStyle.CATEGORY_COLORS["warning"] as Color).to_html(false), line]
			"dim":
				line = "[color=#%s]%s[/color]" % [DIM.to_html(false), line]
		out.append(line)
	return "\n".join(out)


## Entries grouped by section, in order: [{section, entries: [...]}].
static func group_sections(entries: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		if out.is_empty() or out[-1]["section"] != String(e["section"]):
			out.append({"section": String(e["section"]), "entries": []})
		(out[-1]["entries"] as Array).append(e)
	return out


## A goal line is "[x] text" or "[ ] text": returns {done, text}, or {} for a plain line.
static func parse_goal(text: String) -> Dictionary:
	if text.begins_with("[x] "):
		return {"done": true, "text": text.substr(4)}
	if text.begins_with("[ ] "):
		return {"done": false, "text": text.substr(4)}
	return {}


func _build_cards(list: Array) -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	for sec in group_sections(list):
		var card := UIStyle.panel()
		card.name = "card_" + String(sec["section"]).validate_node_name()
		card.set_meta("title", sec["section"])
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		card.add_child(inner)
		inner.add_child(UIStyle.label(sec["section"], 18, UIStyle.ACCENT))
		for e: Dictionary in sec["entries"]:
			inner.add_child(_row(e))
		if sec["section"] == "Around the village":
			var book := UIStyle.button("Village book", func() -> void: book_requested.emit())
			book.name = "VillageBookButton"
			book.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			inner.add_child(book)
		_cards.add_child(card)


func _row(e: Dictionary) -> Control:
	var tone := String(e.get("tone", "normal"))
	var color := Color.WHITE
	if tone == "warning":
		color = UIStyle.CATEGORY_COLORS["warning"]
	elif tone == "dim":
		color = DIM
	var goal := parse_goal(String(e["text"]))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var mark: Control
	if goal.is_empty():
		mark = UIStyle.label("-", 15, color)
	else:
		mark = CheckBox_pixel.new(goal["done"])
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mark)
	var text := RichTextLabel.new()
	text.bbcode_enabled = false
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_color_override("default_color", color)
	text.text = String(goal["text"]) if not goal.is_empty() else String(e["text"])
	row.add_child(text)
	return row


## A 14 px pixel box, ticked when done.
class CheckBox_pixel extends Control:
	var done := false

	func _init(is_done: bool) -> void:
		done = is_done
		custom_minimum_size = Vector2(16, 20)

	func _draw() -> void:
		var r := Rect2(1, 3, 14, 14)
		draw_rect(r, Color(0.12, 0.12, 0.14))
		draw_rect(r, UIStyle.ACCENT.darkened(0.2), false, 2.0)
		if done:
			var ok := Color("7fd36b")
			draw_rect(Rect2(4, 9, 3, 3), ok)
			draw_rect(Rect2(7, 11, 3, 3), ok)
			draw_rect(Rect2(10, 6, 3, 5), ok)
