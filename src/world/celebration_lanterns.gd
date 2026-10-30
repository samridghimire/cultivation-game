class_name CelebrationLanterns
extends Node2D
## GFX-023: a string of pixel lanterns between two posts, drawn while a village celebration is open.
## Red lanterns for a wedding, white for a funeral. They sway gently unless `reduce_motion` is on.

const SPAN := 150.0
const LANTERNS := 5
const POST_HEIGHT := 64.0

var lantern_color := Color("e03030")
var _time := 0.0


func _process(delta: float) -> void:
	if MotionFx.reduced():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s := float(Sprites.scale())
	var wood := Color("6e5636")
	var left := Vector2(-SPAN / 2.0, 0)
	var right := Vector2(SPAN / 2.0, 0)
	for post in [left, right]:
		draw_rect(Rect2(post.x - s, -POST_HEIGHT, s * 2.0, POST_HEIGHT), wood)
	var top := -POST_HEIGHT + 2.0
	var sway := 0.0 if MotionFx.reduced() else sin(_time * 1.6) * 1.5
	var prev := Vector2(left.x, top)
	for i in LANTERNS + 1:
		var t := float(i) / LANTERNS
		var pt := Vector2(lerpf(left.x, right.x, t), top + sin(t * PI) * 10.0)
		draw_line(prev, pt, Color("2b2118"), 1.0)
		prev = pt
		if i > 0 and i < LANTERNS + 1:
			var lp := pt + Vector2(sway * sin(t * PI), 0)
			draw_rect(Rect2(lp.x - s * 2.0, lp.y, s * 4.0, s * 6.0), lantern_color)
			draw_rect(Rect2(lp.x - s * 2.0, lp.y, s * 4.0, s), lantern_color.darkened(0.35))
			draw_rect(Rect2(lp.x - s * 0.5, lp.y + s * 2.0, s, s * 3.0), lantern_color.lightened(0.5))
