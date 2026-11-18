class_name RainPuddles
extends Node2D
## GFX-184: rain you can see on the ground. A wet day darkens the map ~8% and lays sky-tinted puddles
## on dirt paths and worn yards, with a ripple ring every ~1.5 s on random puddles. The day after rain
## keeps half the puddles, still. None in snow, on stone paving, on water or inside places.
## Draw-only: seeded from the region and day with a local rng, never GameState.rng.

const WET_DARKEN := 0.08
const RIPPLE_EVERY := 1.5
const RIPPLE_LIFE := 1.6
const REDRAW_EVERY := 0.125  ## PERF-012: ripples step at 8 Hz, redrawing only this small node
const PER_MILLION_PX := 9.0  ## puddles per 1000x1000 px (spec: 6-12)

var _puddles: Array[Dictionary] = []
var _size := Vector2.ZERO
var _wet := false  ## raining now: darker ground and ripples
var _reduce := false
var _clock := 0.0
var _next_ripple := 0.0
var _ripples: Array[Dictionary] = []
var _since_redraw := 0.0
var _rng := RandomNumberGenerator.new()


## Puddles {pos, rx, ry} for a region on a day. `phase` is "rain" (all), "after" (half) or "" (none).
static func layout(region: Dictionary, map_size: Vector2, day: int, phase: String, yards: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if phase == "":
		return out
	var map: Dictionary = region.get("map", {})
	if str(map.get("ground_style", "grass")) == "paved":
		return out
	var zones: Array[Rect2] = []
	for r in map.get("paths", []):
		zones.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	var polys: Array[PackedVector2Array] = []
	for y: Dictionary in yards.get("yards", []):
		polys.append(PackedVector2Array(y["outline"]))
	for f: Dictionary in yards.get("footpaths", []):
		zones.append(f["rect"] as Rect2)
	if zones.is_empty() and polys.is_empty():
		return out
	var avoid: Array[Rect2] = Scenery.landmark_rects(region)
	for pl: Dictionary in region.get("places", []):
		avoid.append(Npcs.place_keepout(pl).grow(6.0))
	var want := clampi(roundi(map_size.x * map_size.y / 1000000.0 * PER_MILLION_PX), 4, 14)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|puddles|%d" % [region.get("id", ""), day])
	var tries := 0
	while out.size() < want and tries < want * 40:
		tries += 1
		var p := Vector2(rng.randf() * map_size.x, rng.randf() * map_size.y)
		var rx := 5.0 + rng.randf() * 7.0
		var ry := rx * (0.4 + rng.randf() * 0.15)
		var ok := false
		var box := Rect2(p - Vector2(rx, ry), Vector2(rx, ry) * 2.0)
		for z in zones:
			if z.encloses(box):
				ok = true
				break
		if not ok:
			for poly in polys:
				if Geometry2D.is_point_in_polygon(p, poly) and Geometry2D.is_point_in_polygon(p + Vector2(rx, 0), poly) and Geometry2D.is_point_in_polygon(p - Vector2(rx, 0), poly):
					ok = true
					break
		if not ok:
			continue
		for a in avoid:
			if a.intersects(box):
				ok = false
				break
		if ok:
			out.append({"pos": p, "rx": rx, "ry": ry})
	if phase == "after":
		out = out.slice(0, out.size() / 2)
	return out


## "rain" on a wet day, "after" the day following one, else "" (also none in snowy ground).
static func phase_for(today: String, yesterday: String, snowy: bool) -> String:
	if snowy:
		return ""
	if Ambient.is_wet(today):
		return "rain"
	if Ambient.is_wet(yesterday):
		return "after"
	return ""


func setup(region: Dictionary, map_size: Vector2, day: int, today: String, yesterday: String, snowy: bool, yards: Dictionary, reduce_motion: bool) -> void:
	var phase := phase_for(today, yesterday, snowy)
	_size = map_size
	_wet = phase == "rain"
	_reduce = reduce_motion
	_puddles = layout(region, map_size, day, phase, yards)
	_ripples.clear()
	_clock = 0.0
	_next_ripple = 0.0
	_rng.seed = hash("%s|ripples|%d" % [region.get("id", ""), day])
	z_index = 0
	set_process(_wet and not reduce_motion and not _puddles.is_empty())
	queue_redraw()


func puddles() -> Array[Dictionary]:
	return _puddles


func ripple_count() -> int:
	return _ripples.size()


func advance(delta: float) -> void:
	if not _wet or _reduce or _puddles.is_empty():
		return
	_clock += delta
	for r in _ripples:
		r["t"] = float(r["t"]) + delta
	_ripples = _ripples.filter(func(r: Dictionary) -> bool: return float(r["t"]) < RIPPLE_LIFE)
	if _clock >= _next_ripple:
		_next_ripple = _clock + RIPPLE_EVERY
		_ripples.append({"i": _rng.randi() % _puddles.size(), "t": 0.0})
	_since_redraw += delta
	if _since_redraw >= REDRAW_EVERY:
		_since_redraw = 0.0
		queue_redraw()  # PERF-012: this node only, never the world


func _process(delta: float) -> void:
	advance(delta)


## GFX-190: the puddle bodies are painted by the world's own _draw between the paths and the props
## (see paint_puddles), so every prop, shadow and figure sits above them. This node only draws the
## wet-ground tint and (PERF-012) the ripple rings, so stepping them never re-records the world.
func _draw() -> void:
	if _wet:
		draw_rect(Rect2(Vector2.ZERO, _size), Color(0.0, 0.02, 0.06, WET_DARKEN))
	for r in _ripples:
		var pd: Dictionary = _puddles[int(r["i"])]
		var k := float(r["t"]) / RIPPLE_LIFE
		var pts := _oval_points(pd["pos"], float(pd["rx"]) * (0.3 + 0.6 * k), float(pd["ry"]) * (0.3 + 0.6 * k))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.92, 0.97, 1.0, 0.7 * (1.0 - k)), 1.0)


## GFX-190: paint the puddle bodies onto `ci` (the world, in its ground pass, above paths, below props).
func paint_puddles(ci: CanvasItem) -> void:
	for p in _puddles:
		var c: Vector2 = p["pos"]
		var rx := float(p["rx"])
		var ry := float(p["ry"])
		ci.draw_colored_polygon(_oval_points(c, rx + 1.0, ry + 1.0), Color(0.85, 0.93, 1.0, 0.45))
		ci.draw_colored_polygon(_oval_points(c, rx, ry), Color(0.45, 0.58, 0.72, 0.8))
		ci.draw_colored_polygon(_oval_points(c + Vector2(-rx * 0.15, -ry * 0.25), rx * 0.55, ry * 0.4), Color(0.7, 0.82, 0.92, 0.5))


func _oval_points(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
