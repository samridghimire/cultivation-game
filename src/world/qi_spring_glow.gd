class_name QiSpringGlow
extends Node2D
## GFX-215: where the qi pools. A meditation place or abode with qi_density > 1 gets 3-8 pale motes
## rising from its footprint and a 2 px ground ring that breathes over 4 s. Draw-only; no redraw
## while off screen; frozen under reduce_motion; the world skips it when Ambient effects is off.

const MIN_MOTES := 3
const MAX_MOTES := 8
const HIGH_DENSITY := 2.5
const BREATH_SECONDS := 4.0
const RISE := 34.0
const RISE_SECONDS := 5.0
const MOTE_COLOR := Color(0.82, 0.96, 1.0)
const REDRAW_EVERY := 0.0625

var footprint := Vector2(64, 64)  ## the place's size; the node sits at the place centre
var density := 1.0
var reduce_motion := false
var _clock := 0.0
var _since_redraw := 0.0


## 0 when the place has no extra qi; else 3 at just above x1.0 up to 8 at x2.5 and more.
static func mote_count(qi_density: float) -> int:
	if qi_density <= 1.0:
		return 0
	var t := clampf((qi_density - 1.0) / (HIGH_DENSITY - 1.0), 0.0, 1.0)
	return clampi(MIN_MOTES + int(round(t * float(MAX_MOTES - MIN_MOTES))), MIN_MOTES, MAX_MOTES)


## Offset (from the place centre) of mote `i` of `n` at time `t` seconds: it rises from the
## footprint's base and fades at the top. Returns {pos, alpha}.
static func mote_at(i: int, n: int, t: float, size: Vector2, frozen: bool) -> Dictionary:
	var phase := fposmod(float(i) / float(maxi(n, 1)) + (0.0 if frozen else t / RISE_SECONDS), 1.0)
	var x := (fposmod(float(i) * 0.618, 1.0) - 0.5) * size.x * 0.8
	var sway := 0.0 if frozen else sin(t * 0.9 + float(i)) * 3.0
	var y := size.y / 2.0 - phase * RISE
	var alpha := sin(phase * PI) * 0.85
	return {"pos": Vector2(x + sway, y), "alpha": alpha}


## Ring brightness 0..1 at time `t` (breathes over BREATH_SECONDS; steady when frozen).
static func breath(t: float, frozen: bool) -> float:
	if frozen:
		return 0.6
	return 0.5 + 0.5 * sin(TAU * t / BREATH_SECONDS)


func setup(place_size: Vector2, qi_density: float, reduce: bool) -> void:
	footprint = place_size
	density = qi_density
	reduce_motion = reduce
	queue_redraw()


func motes() -> int:
	return mote_count(density)


func _on_screen() -> bool:
	if not is_inside_tree():
		return false
	var vr := get_viewport().get_visible_rect()
	var r := get_global_transform_with_canvas() * Rect2(-footprint / 2.0 - Vector2(8, RISE), footprint + Vector2(16, RISE + 8))
	return vr.intersects(r)


func _process(delta: float) -> void:
	if reduce_motion or motes() == 0 or not visible:
		return
	_clock += delta
	_since_redraw += delta
	if _since_redraw >= REDRAW_EVERY:
		_since_redraw = 0.0
		if _on_screen():
			queue_redraw()


func _draw() -> void:
	var n := motes()
	if n == 0:
		return
	var b := breath(_clock, reduce_motion)
	var ring := Rect2(Vector2(-footprint.x * 0.55, footprint.y / 2.0 - 8.0), Vector2(footprint.x * 1.1, 14.0))
	var c := MOTE_COLOR
	c.a = 0.10 + 0.14 * b
	draw_arc(ring.get_center(), ring.size.x / 2.0, 0.0, TAU, 40, c, 2.0)
	for i in n:
		var m := mote_at(i, n, _clock, footprint, reduce_motion)
		var col := MOTE_COLOR
		col.a = float(m["alpha"])
		var p: Vector2 = m["pos"]
		draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), col)
