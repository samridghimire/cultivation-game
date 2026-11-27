class_name LetterCard
extends PanelContainer
## WU-643: a friend's letter on paper: parchment-toned panel, the writer's figure and name, the letter text and, for a
## request letter, one line with the item and the days left. "Read later" / "Continue" both close it (the journal keeps
## the text); focus is on Continue, cancel closes. Unless `reduce_motion` is on the paper slides up SLIDE_PX over
## SLIDE_SECONDS. `closed` fires once.

signal closed

const W := 460
const SLIDE_PX := 12.0
const SLIDE_SECONDS := 0.2
const PAPER := Color(0.86, 0.78, 0.6)
const INK := Color(0.2, 0.14, 0.08)

var _title: Label
var _figure: TextureRect
var _text: Label
var _ask: Label
var _later: Button
var _continue: Button


func _init() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = Color(0.45, 0.32, 0.16)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(W, 0)
	add_child(box)
	_title = UIStyle.label("", 22, INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_figure = TextureRect.new()
	_figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_figure.custom_minimum_size = Vector2(0, 15 * 3 + 6)
	box.add_child(_figure)
	_text = UIStyle.label("", 17, INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_ask = UIStyle.label("", 16, Color(0.5, 0.18, 0.1))
	_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ask)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_later = UIStyle.button("Read later", close)
	_later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_later)
	_continue = UIStyle.button("Continue", close)
	_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_continue)


## "Wants 2 Qi Gathering Pill within 12 days." (or "...within 1 day.").
static func ask_line(item_name: String, count: int, days_left: int) -> String:
	return "Hopes for %s within %d %s." % [GiftLeftCard.item_text(item_name, count), days_left, "day" if days_left == 1 else "days"]


## True when the paper should slide in (false under reduce_motion).
static func slides() -> bool:
	return Settings.get_value("reduce_motion") != true


## `request` is {} or {item, count, until} (a Letters request); `today` the current day.
func open(npc_id: String, npc_name: String, text: String, request: Dictionary = {}, today: int = 0) -> void:
	_title.text = "A letter from %s" % npc_name
	var look: Dictionary = preload("res://src/world/interactables/npc.gd").look_of(npc_id, Color("9a8f7a"))
	_figure.texture = PixelFigure.frame(look if look.size() > 0 else {"robe": Color(0.8, 0.8, 0.75)}, "down", 0)
	_text.text = text
	var data: GameData = GameState.data
	_ask.visible = not request.is_empty()
	if not request.is_empty():
		var iid := String(request.get("item", ""))
		var nm := String(data.items[iid].get("name", iid)) if data != null and data.items.has(iid) else iid
		_ask.text = ask_line(nm, int(request.get("count", 1)), maxi(0, int(request.get("until", today)) - today))
	visible = true
	_continue.grab_focus.call_deferred()
	if slides():
		var tw := create_tween()
		position.y += SLIDE_PX
		tw.tween_property(self, "position:y", position.y - SLIDE_PX, SLIDE_SECONDS)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func continue_button() -> Button:
	return _continue


func later_button() -> Button:
	return _later


func text_value() -> String:
	return _text.text


func ask_text() -> String:
	return _ask.text if _ask.visible else ""


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
