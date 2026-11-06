class_name CritterLayer
extends Node2D
## GFX-086: draws a region's ambient critters (hens, ducks, butterflies) as tiny code-drawn pixel
## shapes. No collision, not an Interactable. Static under reduce_motion, culled offscreen.

var critters: Array[Dictionary] = []
var _time := 0.0
var _still := false


## Rebuilds from `Critters.today`; the layer hides itself when there is nothing to draw.
func setup(region: Dictionary, season: String, day: int, enabled: bool, reduce_motion: bool) -> void:
	critters = Critters.today(region, season, day, enabled)
	_still = reduce_motion
	z_index = 3
	visible = not critters.is_empty()
	set_process(visible and not _still)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect()
	view = (get_canvas_transform().affine_inverse() * view).grow(24.0)
	for c in critters:
		var p := Critters.position_at(c, _time, _still)
		if not view.has_point(p):
			continue
		match String(c["kind"]):
			"hen":
				_draw_hen(p, int(c["seed"]), _time, _still)
			"duck":
				_draw_duck(p)
			"butterfly":
				_draw_butterfly(p, _time, int(c["seed"]), _still)


func _draw_hen(p: Vector2, seed_value: int, t: float, still: bool) -> void:
	var peck := 0.0 if still else maxf(0.0, sin(t * 3.0 + float(seed_value % 10))) * 2.0
	draw_rect(Rect2(p + Vector2(-4, 2), Vector2(9, 3)), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(p + Vector2(-4, -3), Vector2(8, 6)), Color("e8dcc4"))
	draw_rect(Rect2(p + Vector2(-6, -5), Vector2(3, 4)), Color("c9b896"))  # tail
	draw_rect(Rect2(p + Vector2(3, -5 + peck), Vector2(3, 4)), Color("e8dcc4"))  # head
	draw_rect(Rect2(p + Vector2(4, -6 + peck), Vector2(2, 1)), Color("d9302f"))  # comb
	draw_rect(Rect2(p + Vector2(6, -4 + peck), Vector2(2, 1)), Color("e8a23c"))  # beak


func _draw_duck(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-5, 0), Vector2(12, 3)), Color(1, 1, 1, 0.25))  # wake
	draw_rect(Rect2(p + Vector2(-4, -3), Vector2(9, 5)), Color("f4f0e4"))
	draw_rect(Rect2(p + Vector2(-5, -4), Vector2(2, 2)), Color("d8d2c0"))  # tail
	draw_rect(Rect2(p + Vector2(3, -6), Vector2(4, 4)), Color("3f7a4a"))  # head
	draw_rect(Rect2(p + Vector2(7, -4), Vector2(2, 1)), Color("e8a23c"))  # bill


func _draw_butterfly(p: Vector2, t: float, seed_value: int, still: bool) -> void:
	var flap := 3.0 if still else 1.0 + absf(sin(t * 9.0 + float(seed_value % 7))) * 2.5
	var colour := Color("f2a7c3") if seed_value % 2 == 0 else Color("f6c44a")
	draw_rect(Rect2(p + Vector2(-flap - 1.0, -2), Vector2(flap, 3)), colour)
	draw_rect(Rect2(p + Vector2(1, -2), Vector2(flap, 3)), colour)
	draw_rect(Rect2(p + Vector2(-0.5, -2), Vector2(1, 4)), Color("3a2a22"))
