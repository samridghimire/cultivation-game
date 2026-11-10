class_name CritterLayer
extends Node2D
## GFX-086: draws a region's ambient critters (hens, ducks, butterflies) as tiny code-drawn pixel
## shapes. No collision, not an Interactable. Static under reduce_motion, culled offscreen.

var critters: Array[Dictionary] = []
var _time := 0.0
var _still := false
## GFX-088: the player's world position (handed in by the world each frame) and each critter's
## current startle offset / whether it is still running away.
var player_pos := Vector2(-100000, -100000)
var _offsets: Array[Vector2] = []
var _fleeing: Array[bool] = []
const RUN_SECONDS := 0.4
const RETURN_SECONDS := 3.0


var _args: Array = []


## WU-490: rebuild with the same arguments (after the hens are fed).
func refresh() -> void:
	if not _args.is_empty():
		setup(_args[0], _args[1], _args[2], _args[3], _args[4])


## Rebuilds from `Critters.today`; the layer hides itself when there is nothing to draw.
func setup(region: Dictionary, season: String, day: int, enabled: bool, reduce_motion: bool) -> void:
	_args = [region, season, day, enabled, reduce_motion]
	critters = Critters.today(region, season, day, enabled, Critters.fed_today(GameState.world_flags, String(region.get("id", "")), day))
	_still = reduce_motion
	z_index = 3
	visible = not critters.is_empty()
	_offsets.clear()
	_fleeing.clear()
	for c in critters:
		_offsets.append(Vector2.ZERO)
		_fleeing.append(false)
	set_process(visible)
	add_to_group("critter_layer")
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var changed := _update_startle(delta)
	if not _still or changed:
		queue_redraw()


## Where critter `i` is drawn: its wander position plus the startle offset, ducks kept on the water.
func critter_pos(i: int) -> Vector2:
	var c: Dictionary = critters[i]
	var p := Critters.position_at(c, _time, _still) + _offsets[i]
	if c["kind"] == "duck":
		p = Critters.clamp_to_pond(p, c["home"])
	return p


## Moves each startle offset toward its target: out fast over RUN_SECONDS, back slowly over
## RETURN_SECONDS (at once under reduce_motion). True when any offset changed.
func _update_startle(delta: float) -> bool:
	var changed := false
	for i in critters.size():
		var c: Dictionary = critters[i]
		var base := Critters.position_at(c, _time, _still)
		var target := Critters.startle_offset(c, base, player_pos)
		var cur := _offsets[i]
		var reach := float(Critters.FLEE_DIST.get(c["kind"], 0.0))
		var next := cur
		if _still:
			next = target
			_fleeing[i] = false
		elif target.length() > cur.length() + 0.01:
			next = cur.move_toward(target, reach / RUN_SECONDS * delta)
			_fleeing[i] = true
		else:
			next = cur.move_toward(target, reach / RETURN_SECONDS * delta)
			_fleeing[i] = false
		if next != cur:
			_offsets[i] = next
			changed = true
	return changed


func _draw() -> void:
	var view := get_viewport_rect()
	view = (get_canvas_transform().affine_inverse() * view).grow(24.0)
	for i in critters.size():
		var c: Dictionary = critters[i]
		var p := critter_pos(i)
		if not view.has_point(p):
			continue
		match String(c["kind"]):
			"hen":
				_draw_hen(p, int(c["seed"]), _time, _still, _fleeing[i])
			"duck":
				_draw_duck(p)
			"butterfly":
				_draw_butterfly(p, _time, int(c["seed"]), _still)


func _draw_hen(p: Vector2, seed_value: int, t: float, still: bool, fleeing: bool = false) -> void:
	if fleeing and not still:  # WU-490: a hen hops away rather than gliding
		p.y -= absf(sin(t * 18.0)) * 4.0
	var peck := 0.0 if still else maxf(0.0, sin(t * 3.0 + float(seed_value % 10))) * 2.0
	draw_rect(Rect2(p + Vector2(-4, 2), Vector2(9, 3)), Color(0, 0, 0, 0.2))
	draw_rect(Rect2(p + Vector2(-4, -3), Vector2(8, 6)), Color("e8dcc4"))
	draw_rect(Rect2(p + Vector2(-6, -5), Vector2(3, 4)), Color("c9b896"))  # tail
	draw_rect(Rect2(p + Vector2(3, -5 + peck), Vector2(3, 4)), Color("e8dcc4"))  # head
	draw_rect(Rect2(p + Vector2(4, -6 + peck), Vector2(2, 1)), Color("d9302f"))  # comb
	draw_rect(Rect2(p + Vector2(6, -4 + peck), Vector2(2, 1)), Color("e8a23c"))  # beak
	if fleeing and not still:  # GFX-088: two raised wing pixels
		draw_rect(Rect2(p + Vector2(-2, -5), Vector2(1, 2)), Color("f4f0e4"))
		draw_rect(Rect2(p + Vector2(1, -5), Vector2(1, 2)), Color("f4f0e4"))


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
