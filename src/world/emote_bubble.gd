class_name EmoteBubble
extends Node2D
## WU-486: a 16x16 code-drawn speech bubble over a villager: a red heart (love), a yellow smile (happy), a blue sweat
## drop (sweat) or a "!" (lesson, persistent). Timed bubbles rise 4 px and fade over `lifetime` seconds, then free
## themselves; with reduce_motion they stay still and vanish at the end. Tests shorten `lifetime`.

const SIZE := 16
const RISE := 4.0
const KINDS: PackedStringArray = ["love", "happy", "sweat", "lesson"]

var kind := "love"
## Seconds the bubble shows; 0 or less = persistent (the "!" lesson bubble).
var lifetime := 1.6
var _age := 0.0
var _animate := true


static func make(bubble_kind: String, seconds: float = 1.6) -> EmoteBubble:
	var b := EmoteBubble.new()
	b.kind = bubble_kind
	b.lifetime = seconds
	return b


func _ready() -> void:
	_animate = not Settings.get_value("reduce_motion")
	z_index = 20
	position = base_position
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(lifetime > 0.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	if _animate:
		position.y = _base_y() - RISE * (_age / lifetime)
		modulate.a = clampf(2.0 * (1.0 - _age / lifetime), 0.0, 1.0)


## Where the bubble sits when not risen; set by the owner (npc.gd) before it is added.
var base_position := Vector2.ZERO


func _base_y() -> float:
	return base_position.y


func _draw() -> void:
	var o := Vector2(-SIZE / 2.0, -SIZE)
	var line := Color("2b2118")
	var white := Color("fbf8f0")
	draw_rect(Rect2(o + Vector2(2, 0), Vector2(12, 12)), line)
	draw_rect(Rect2(o + Vector2(0, 2), Vector2(16, 8)), line)
	draw_rect(Rect2(o + Vector2(2, 1), Vector2(12, 10)), white)
	draw_rect(Rect2(o + Vector2(1, 2), Vector2(14, 8)), white)
	draw_rect(Rect2(o + Vector2(6, 12), Vector2(4, 1)), line)  # tail
	draw_rect(Rect2(o + Vector2(7, 13), Vector2(2, 1)), line)
	draw_rect(Rect2(o + Vector2(7, 11), Vector2(2, 1)), white)
	match kind:
		"love":
			var red := Color("d8323c")
			draw_rect(Rect2(o + Vector2(4, 3), Vector2(3, 2)), red)
			draw_rect(Rect2(o + Vector2(9, 3), Vector2(3, 2)), red)
			draw_rect(Rect2(o + Vector2(4, 5), Vector2(8, 2)), red)
			draw_rect(Rect2(o + Vector2(5, 7), Vector2(6, 1)), red)
			draw_rect(Rect2(o + Vector2(6, 8), Vector2(4, 1)), red)
			draw_rect(Rect2(o + Vector2(7, 9), Vector2(2, 1)), red)
		"happy":
			var gold := Color("e9b824")
			draw_rect(Rect2(o + Vector2(5, 3), Vector2(1, 2)), gold)
			draw_rect(Rect2(o + Vector2(10, 3), Vector2(1, 2)), gold)
			draw_rect(Rect2(o + Vector2(4, 6), Vector2(1, 1)), gold)
			draw_rect(Rect2(o + Vector2(5, 7), Vector2(6, 1)), gold)
			draw_rect(Rect2(o + Vector2(11, 6), Vector2(1, 1)), gold)
		"sweat":
			var blue := Color("3d8fe0")
			draw_rect(Rect2(o + Vector2(7, 2), Vector2(2, 2)), blue)
			draw_rect(Rect2(o + Vector2(6, 4), Vector2(4, 4)), blue)
			draw_rect(Rect2(o + Vector2(7, 8), Vector2(2, 1)), blue)
			draw_rect(Rect2(o + Vector2(7, 4), Vector2(1, 1)), white)
		_:  # lesson: "!"
			var gold2 := Color("c9871a")
			draw_rect(Rect2(o + Vector2(7, 2), Vector2(2, 5)), gold2)
			draw_rect(Rect2(o + Vector2(7, 8), Vector2(2, 2)), gold2)
