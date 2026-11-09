class_name SeasonCard
extends PanelContainer
## WU-495: one card for the turn of a season (replaces the recap and kickoff banners). A season strip on top
## (the region backdrop with the season's tint, snow in winter), a "Looking back" block (SEASON-012 lines) and a
## "Coming up" block (SEASON-013 lines), each line with a kind icon, and a Continue button that takes focus.
## Confirm/cancel also closes it. No motion.

signal closed

const WRAP_WIDTH := 560
const TINTS := {
	"Spring": Color(0.95, 0.7, 0.8, 0.12),
	"Summer": Color(1.0, 0.9, 0.4, 0.10),
	"Autumn": Color(0.9, 0.5, 0.2, 0.16),
	"Winter": Color(0.7, 0.85, 1.0, 0.18),
}

var _strip: EncounterScene
var _tint: ColorRect
var _title: Label
var _back_box: VBoxContainer
var _coming_box: VBoxContainer
var _back_lines := PackedStringArray()
var _coming_lines := PackedStringArray()
var _button: Button


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(WRAP_WIDTH, 0)
	add_child(box)
	_title = UIStyle.label("", 26, Color(0.95, 0.8, 0.35))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_strip = EncounterScene.new()
	_strip.custom_minimum_size = Vector2(WRAP_WIDTH, 96)
	_strip.size = _strip.custom_minimum_size
	box.add_child(_strip)
	_tint = ColorRect.new()
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_strip.add_child(_tint)
	_back_box = VBoxContainer.new()
	_back_box.add_theme_constant_override("separation", 4)
	box.add_child(_back_box)
	_coming_box = VBoxContainer.new()
	_coming_box.add_theme_constant_override("separation", 4)
	box.add_child(_coming_box)
	_button = UIStyle.button("Continue", close)
	box.add_child(_button)


## "season", "fight" or "other" by the line's words. Pure.
static func line_kind(line: String) -> String:
	var t := line.to_lower()
	if t.contains("fight") or t.contains("beast") or t.contains("duel") or t.contains("won ") or t.contains("defeat"):
		return "fight"
	if t.contains("season") or t.contains("task") or t.contains("spring") or t.contains("summer") or t.contains("autumn") or t.contains("winter") or t.contains("festival") or t.contains("harvest") or t.contains("herb"):
		return "season"
	return "other"


## "Spring of Year 1".
static func title_for(season: String, year: int) -> String:
	return "%s of Year %d" % [season, year]


## `back` may be empty (a new year's spring shows the kickoff only), and so may `coming`.
func open(season: String, year: int, back: PackedStringArray, coming: PackedStringArray) -> void:
	_back_lines = back
	_coming_lines = coming
	_title.text = title_for(season, year)
	_strip.show_encounter({"figure": "none"})
	_strip.set_snow(season == "Winter")
	_tint.color = TINTS.get(season, Color(0, 0, 0, 0))
	_fill(_back_box, "Looking back", back)
	_fill(_coming_box, "Coming up", coming)
	visible = true
	_button.grab_focus.call_deferred()


func _fill(box: VBoxContainer, head: String, lines: PackedStringArray) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.free()
	box.visible = not lines.is_empty()
	if lines.is_empty():
		return
	box.add_child(UIStyle.label(head, 18, Color(0.95, 0.8, 0.35)))
	for line in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = HudIcons.hint_glyph(line_kind(line))
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		row.add_child(icon)
		var l := UIStyle.label(line, 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(WRAP_WIDTH - 28, 0)
		row.add_child(l)
		box.add_child(row)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func button() -> Button:
	return _button


func title_text() -> String:
	return _title.text


func back_lines() -> PackedStringArray:
	return _back_lines


func coming_lines() -> PackedStringArray:
	return _coming_lines


func has_strip() -> bool:
	return _strip != null and _strip.is_inside_tree()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()
