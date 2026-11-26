class_name FriendMeditationCard
extends PanelContainer
## WU-635: the short moment before "Meditate with <friend>" skips time: both figures seated on mats side by side under
## a night sky, qi motes in both roots' colours drifting between them, and one line of text. Skippable with
## confirm/cancel (the Begin button has focus). With `reduce_motion` the motes sit still. `done` fires once on close.

signal done

const W := 480
const H := 150
const MOTES := 14
const SEAT_L := 160.0
const SEAT_R := 320.0
const BASE := 130.0

var _stage: Control
var _line: Label
var _button: Button
var _look_a: Dictionary = {}
var _look_b: Dictionary = {}
var _colors: Array[Color] = [Color(0.95, 0.85, 0.5)]
var _phase := 0.0
var _reduce := false


func _init() -> void:
	var style_source := UIStyle.panel()
	add_theme_stylebox_override("panel", style_source.get_theme_stylebox("panel"))
	style_source.free()
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(W, H)
	_stage.draw.connect(_draw_stage)
	box.add_child(_stage)
	_line = UIStyle.label("", 18, Color(0.95, 0.8, 0.35))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_line)
	_button = UIStyle.button("Begin", close)
	box.add_child(_button)


## The sentence under the picture.
static func line_for(npc_name: String) -> String:
	return "You and %s sit together in quiet cultivation." % npc_name


## True when the motes should drift (false under reduce_motion).
static func motes_move(reduce_motion: bool) -> bool:
	return not reduce_motion


## Mote `i` at `phase`: drifts along a lazy loop between the two seats; still at phase 0.
static func mote_pos(i: int, phase: float) -> Vector2:
	var t := fposmod(float(i) / float(MOTES) + phase * 0.12, 1.0)
	var x := lerpf(SEAT_L, SEAT_R, t)
	var y := 90.0 - sin(t * PI) * 30.0 - float(i % 4) * 7.0 + sin(phase * 1.3 + float(i)) * 3.0
	return Vector2(x, y)


## Colour of mote `i`: the two figures' root colours alternate.
func mote_color(i: int) -> Color:
	return _colors[i % _colors.size()]


func open(npc_id: String, npc_name: String) -> void:
	var p := GameState.player
	var data := GameState.data
	_look_a = PlayerLook.of(p, data)
	var npc: CharacterData = GameState.npcs.get(npc_id)
	_look_b = preload("res://src/world/interactables/npc.gd").look_of(npc_id, Color("9a8f7a"))
	_colors = QiMotes.colors_for(p, data)
	if npc != null:
		for c in QiMotes.colors_for(npc, data):
			if not _colors.has(c):
				_colors.append(c)
	_line.text = line_for(npc_name)
	_reduce = MotionFx.reduced()
	_phase = 0.0
	visible = true
	_stage.queue_redraw()
	_button.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	done.emit()


func button() -> Button:
	return _button


func line_text() -> String:
	return _line.text


func _process(delta: float) -> void:
	if visible and motes_move(_reduce):
		_phase += delta
		_stage.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		close()


func _draw_stage() -> void:
	_stage.draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.06, 0.13))
	for i in 20:
		_stage.draw_rect(Rect2(float((i * 97 + 31) % W), float((i * 53 + 7) % 60), 2, 2), Color(0.8, 0.85, 1.0, 0.45 + 0.35 * float(i % 3) / 2.0))
	_stage.draw_rect(Rect2(0, 112, W, H - 112), Color(0.09, 0.09, 0.14))
	_seat(SEAT_L, _look_a, "right")
	_seat(SEAT_R, _look_b, "left")
	for i in MOTES:
		var p := mote_pos(i, _phase)
		_stage.draw_rect(Rect2(p.x, p.y, 4, 4), Color(mote_color(i), 0.85))


func _seat(x: float, look: Dictionary, facing: String) -> void:
	var s := 3.0
	var tex := PixelFigure.frame(look if look.size() > 0 else {"robe": Color(0.8, 0.8, 0.75)}, facing, 0)
	_stage.draw_rect(Rect2(x - 34, BASE - 6, 68, 10), Color(0.55, 0.2, 0.18))
	_stage.draw_rect(Rect2(x - 34, BASE - 6, 68, 3), Color(0.7, 0.35, 0.25))
	_stage.draw_texture_rect_region(tex, Rect2(x - 24, BASE - 15 * s - 3, 16 * s, 15 * s), Rect2(0, 0, 16, 15))
	_stage.draw_rect(Rect2(x - 28, BASE - 12, 56, 6), Color(0, 0, 0, 0.3))
