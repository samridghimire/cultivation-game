class_name Footprints
extends Node2D
## GFX-212: walking leaves a trace. Every STEP px of travel the player drops a mark under the feet:
## snow -> a pair of grey-blue prints that fade over 6 s, rain + puddle -> a ring ripple,
## road or dry dirt -> a tan dust puff, grass -> nothing. Draw-only; marks live in a capped array.
## reduce_motion: prints stay (static), no dust or ripple.

const STEP := 14.0
const CAP := 40
const PRINT_LIFE := 6.0
const DUST_LIFE := 0.4
const RIPPLE_LIFE := 0.8
const REDRAW_EVERY := 0.0625

var _marks: Array[Dictionary] = []  ## {kind, pos, age, flip}
var _last := Vector2.INF
var _snowy := false
var _raining := false
var _reduce := false
var _road_rects: Array[Rect2] = []
var _puddles: Array[Dictionary] = []
var _since_redraw := 0.0
var _flip := false
var _step_count := 0
var _last_step_ms := 0


## "print", "ripple", "dust" or "" for the ground under the feet.
static func mark_kind(snowy: bool, raining: bool, in_puddle: bool, on_road: bool) -> String:
	if snowy:
		return "print"
	if raining and in_puddle:
		return "ripple"
	if on_road:
		return "dust"
	return ""


## True when `pos` is inside any rect (the region's paths and footpaths).
static func on_road(rects: Array[Rect2], pos: Vector2) -> bool:
	for r in rects:
		if r.has_point(pos):
			return true
	return false


static func in_puddle(puddles: Array[Dictionary], pos: Vector2) -> bool:
	for p in puddles:
		var c: Vector2 = p["pos"]
		var rx: float = p["rx"]
		var ry: float = p["ry"]
		var d := (pos - c) / Vector2(rx, ry)
		if d.length_squared() <= 1.0:
			return true
	return false


func setup(region: Dictionary, yards: Dictionary, snowy: bool, raining: bool, puddles: Array[Dictionary], reduce_motion: bool) -> void:
	_snowy = snowy
	_raining = raining
	_reduce = reduce_motion
	_puddles = puddles
	_road_rects.clear()
	for r in region.get("map", {}).get("paths", []):
		_road_rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	for f: Dictionary in yards.get("footpaths", []):
		_road_rects.append(f["rect"] as Rect2)
	_marks.clear()
	_last = Vector2.INF
	queue_redraw()


func mark_count() -> int:
	return _marks.size()


## Feed the player's position each frame; adds a mark after STEP px of travel.
func track(pos: Vector2) -> void:
	if _last == Vector2.INF:
		_last = pos
		return
	if _last.distance_to(pos) < STEP:
		return
	_last = pos
	var kind := mark_kind(_snowy, _raining, in_puddle(_puddles, pos + Vector2(0, 14)), on_road(_road_rects, pos + Vector2(0, 14)))
	if kind == "" or (_reduce and kind != "print"):
		return
	_flip = not _flip
	_step_sound(kind)
	_marks.append({"kind": kind, "pos": pos + Vector2(0, 14), "age": 0.0, "flip": _flip})
	while _marks.size() > CAP:
		_marks.pop_front()
	queue_redraw()


func _life(kind: String) -> float:
	return PRINT_LIFE if kind == "print" else (RIPPLE_LIFE if kind == "ripple" else DUST_LIFE)


## WU-573: a soft tick on every second snow print or road dust mark, at most 4 a second.
func _step_sound(kind: String) -> void:
	if kind != "print" and kind != "dust":
		return
	_step_count += 1
	var now := Time.get_ticks_msec()
	if _step_count % 2 == 0 and now - _last_step_ms >= 250:
		_last_step_ms = now
		var audio: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Audio")
		if audio != null:
			audio.call("play", "step_snow" if kind == "print" else "step_dirt")


func advance(delta: float) -> void:
	if _marks.is_empty() or _reduce:
		return
	for m in _marks:
		m["age"] = float(m["age"]) + delta
	var i := 0
	while i < _marks.size():
		if float(_marks[i]["age"]) >= _life(str(_marks[i]["kind"])):
			_marks.remove_at(i)
		else:
			i += 1
	_since_redraw += delta
	if _since_redraw >= REDRAW_EVERY:
		_since_redraw = 0.0
		queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	for m in _marks:
		var kind := str(m["kind"])
		var t := 0.0 if _reduce else clampf(float(m["age"]) / _life(kind), 0.0, 1.0)
		var p: Vector2 = m["pos"]
		match kind:
			"print":
				var col := Color(0.45, 0.52, 0.62, 0.65 * (1.0 - t) if not _reduce else 0.5)
				var s := 1.0 if bool(m["flip"]) else -1.0
				draw_rect(Rect2(p + Vector2(-4.0 * s - 1.5, 0), Vector2(3, 4)), col)
				draw_rect(Rect2(p + Vector2(4.0 * s - 1.5, 3), Vector2(3, 4)), col)
			"ripple":
				draw_arc(p, 3.0 + 6.0 * t, 0.0, TAU, 14, Color(0.8, 0.9, 1.0, 0.6 * (1.0 - t)), 1.0)
			"dust":
				var q := p + Vector2(0, -2.0 * t)
				var a := 0.55 * (1.0 - t)
				draw_rect(Rect2(q + Vector2(-2, -1), Vector2(3, 2)), Color(0.72, 0.6, 0.4, a))
				draw_rect(Rect2(q + Vector2(1, 0), Vector2(2, 2)), Color(0.72, 0.6, 0.4, a))
