class_name ConfettiPuff
extends Node2D
## GFX-027: a short puff of paper confetti when the player attends a celebration. Frees itself.

const PIECES := 18
const LIFETIME := 1.4
const COLORS: Array[Color] = [Color("e03030"), Color("f0c040"), Color("f4f0e6"), Color("e0709a")]

var _time := 0.0


## Where piece `i` is `t` seconds in (0..LIFETIME): bursts up and out, then drifts down. Pure, deterministic.
static func piece_offset(i: int, t: float) -> Vector2:
	var angle := (float(i) / PIECES) * TAU + float(i % 3) * 0.4
	var speed := 40.0 + float((i * 7) % 5) * 12.0
	return Vector2(cos(angle) * speed * t, sin(angle) * speed * 0.6 * t - 60.0 * t + 70.0 * t * t)


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var s := float(Sprites.scale())
	var fade := clampf(1.0 - _time / LIFETIME, 0.0, 1.0)
	for i in PIECES:
		var c: Color = COLORS[i % COLORS.size()]
		c.a = fade
		draw_rect(Rect2(piece_offset(i, _time), Vector2(s, s * 1.5)), c)
