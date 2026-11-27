class_name FriendAidCard
extends PanelContainer
## WU-637: a friend's request for aid (FOLK-054) on a card: both figures face to face, the friend seated at a
## bottleneck inside a dim ring, the line naming the item, and "I have it" (gives it; focused when you hold it) or
## "Later". Cancel means Later. `closed` fires once on close. No motion.

signal closed

const W := 480
const H := 150
const FRIEND_X := 330.0
const PLAYER_X := 150.0
const BASE := 130.0

var _stage: Control
var _line: Label
var _give: Button
var _later: Button
var _npc_id := ""
var _look_a: Dictionary = {}
var _look_b: Dictionary = {}


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(W, 0)
	add_child(box)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(W, H)
	_stage.draw.connect(_draw_stage)
	box.add_child(_stage)
	_line = UIStyle.label("", 18, Color(0.95, 0.8, 0.35))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_give = UIStyle.button("I have it", _on_give)
	_give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_give)
	_later = UIStyle.button("Later", close)
	_later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_later)


## Which button takes focus: "I have it" when the item is held, else "Later".
static func focus_give(held: bool) -> bool:
	return held


func open(npc_id: String, npc_name: String, item_name: String, held: bool) -> void:
	_npc_id = npc_id
	_look_a = PlayerLook.of(GameState.player, GameState.data) if GameState.player != null and GameState.data != null else {}
	_look_b = preload("res://src/world/interactables/npc.gd").look_of(npc_id, Color("9a8f7a"))
	_line.text = FriendAid.card_line(npc_name, item_name, held)
	_give.disabled = not held
	visible = true
	_stage.queue_redraw()
	(_give if focus_give(held) else _later).grab_focus.call_deferred()


func _on_give() -> void:
	var id := _npc_id
	close()
	GameState.give_friend_aid(id)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func give_button() -> Button:
	return _give


func later_button() -> Button:
	return _later


func line_text() -> String:
	return _line.text


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _draw_stage() -> void:
	_stage.draw_rect(Rect2(0, 0, W, H), Color(0.07, 0.07, 0.12))
	_stage.draw_rect(Rect2(0, 112, W, H - 112), Color(0.12, 0.11, 0.14))
	_figure(PLAYER_X, _look_a, "right")
	# The friend sits at the bottleneck: a dim ring on the ground around them.
	_stage.draw_arc(Vector2(FRIEND_X, BASE - 4), 44.0, 0.0, TAU, 40, Color(0.75, 0.7, 0.9, 0.35), 3.0)
	_stage.draw_arc(Vector2(FRIEND_X, BASE - 4), 34.0, 0.0, TAU, 32, Color(0.75, 0.7, 0.9, 0.2), 2.0)
	_figure(FRIEND_X, _look_b, "left")


func _figure(x: float, look: Dictionary, facing: String) -> void:
	var s := 3.0
	var tex := PixelFigure.frame(look if look.size() > 0 else {"robe": Color(0.8, 0.8, 0.75)}, facing, 0)
	_stage.draw_rect(Rect2(x - 28, BASE - 6, 56, 6), Color(0, 0, 0, 0.3))
	_stage.draw_texture_rect_region(tex, Rect2(x - 24, BASE - 15 * s - 3, 16 * s, 15 * s), Rect2(0, 0, 16, 15))
