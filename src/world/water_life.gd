class_name WaterLife
extends Node2D
## GFX-047: calm, moving water. Stream highlight dashes scroll slowly downstream (right / down),
## pond highlight arcs shimmer between two alphas, and on rain days ring ripples spread at random
## spots on each pond (a local rng, never GameState.rng). Frozen ponds do nothing; with
## reduce_motion nothing moves (offset stays 0, no ripples) and `_process` is off.

const FLOW_SPEED := 12.0
const DASH_LEN := 8.0
const DASH_GAP := 22.0
const ROW_GAP := 9.0
const SHIMMER_PERIOD := 4.0
const SHIMMER_LOW := 0.0
const SHIMMER_HIGH := 0.3
const RIPPLE_LIFE := 1.8
const MAX_RIPPLES := 5
const MIN_RIPPLES := 3

var flow_offset := 0.0
var _streams: Array[Rect2] = []
var _ponds: Array[Rect2] = []
var _jetties: Array[Rect2] = []  ## WU-431: planks lie over the water; highlights and ripples skip them
var _paths: Array[Rect2] = []
var _rain := false
var _reduce := false
var _clock := 0.0
var _ripples: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


## Ripple count wanted on rain days for `pond_count` ponds (3-5 per pond).
static func ripple_cap(pond_count: int) -> int:
	return pond_count * MAX_RIPPLES


## Shimmer alpha at `t` seconds: a smooth sweep between SHIMMER_LOW and SHIMMER_HIGH.
static func shimmer_alpha(t: float) -> float:
	return lerpf(SHIMMER_LOW, SHIMMER_HIGH, 0.5 - 0.5 * cos(TAU * t / SHIMMER_PERIOD))


## Rebuilds from a region: `rain` for rain/storm days, `frozen` for snowy seasons.
func setup(region: Dictionary, rain: bool, frozen: bool, reduce_motion: bool) -> void:
	_streams.clear()
	_ponds.clear()
	_jetties.clear()
	_paths.clear()
	_ripples.clear()
	flow_offset = 0.0
	_clock = 0.0
	_rain = rain and not frozen and not reduce_motion
	_reduce = reduce_motion
	z_index = 0  # WU-429: with the ground layer; the world moves this node below the figures
	var map: Dictionary = region.get("map", {})
	for pr: Array in map.get("paths", []):
		_paths.append(Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3])))
	for lm: Dictionary in map.get("landmarks", []):
		var size := Vector2(float(lm["size"][0]), float(lm["size"][1]))
		var rect := Rect2(Vector2(float(lm["pos"][0]), float(lm["pos"][1])) - size / 2.0, size)
		match String(lm.get("kind", "")):
			"stream":
				if not frozen:
					_streams.append(rect)
			"pond":
				if not frozen:
					_ponds.append(rect)
			"jetty":
				_jetties.append(Scenery.jetty_layout(region, lm)["rect"] as Rect2)
	_rng.seed = hash(str(region.get("id", "")))
	set_process(not reduce_motion and (not _streams.is_empty() or not _ponds.is_empty()))
	queue_redraw()


## True if `p` lies on a jetty's planks (WU-431).
func on_jetty(p: Vector2) -> bool:
	for j in _jetties:
		if j.has_point(p):
			return true
	return false


func ripple_count() -> int:
	return _ripples.size()


## Advances the animation by `delta` seconds (called by _process; tests call it directly).
func advance(delta: float) -> void:
	if _reduce:
		return
	_clock += delta
	flow_offset = fposmod(flow_offset + FLOW_SPEED * delta, DASH_LEN + DASH_GAP)
	if _rain and not _ponds.is_empty():
		for r in _ripples:
			r["t"] = float(r["t"]) + delta
		_ripples = _ripples.filter(func(r: Dictionary) -> bool: return float(r["t"]) < RIPPLE_LIFE)
		var want := MIN_RIPPLES * _ponds.size()
		while _ripples.size() < mini(want + 1, ripple_cap(_ponds.size())) and _rng.randf() < delta * 2.0 + 0.001:
			var pond := _ponds[_rng.randi() % _ponds.size()]
			var spot := VillageLife.point_in(pond, _rng.randi(), _rng.randi())
			if not on_jetty(spot):
				_ripples.append({"pos": spot, "t": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	var dash := Color(0.78, 0.92, 1.0, 0.45)
	for s in _streams:
		_draw_flow(s, dash)
	var a := shimmer_alpha(_clock)
	for p in _ponds:
		var c := p.get_center()
		var pts := PackedVector2Array()
		for i in 15:
			var ang := PI * (1.15 + 0.7 * float(i) / 14.0)
			var pt := c + Vector2(cos(ang) * (p.size.x / 2.0 - 8.0), sin(ang) * (p.size.y / 2.0 - 8.0))
			if on_jetty(pt):  # WU-431: draw the arc in pieces around the planks
				if pts.size() >= 2:
					draw_polyline(pts, Color(1, 1, 1, a), 2.0)
				pts = PackedVector2Array()
			else:
				pts.append(pt)
		if pts.size() >= 2:
			draw_polyline(pts, Color(1, 1, 1, a), 2.0)
	for r in _ripples:
		var t := float(r["t"]) / RIPPLE_LIFE
		var rad := 2.0 + t * 12.0
		var pos: Vector2 = r["pos"]
		var pts := PackedVector2Array()
		for i in 17:
			var ang := TAU * float(i) / 16.0
			pts.append(pos + Vector2(cos(ang) * rad, sin(ang) * rad * 0.55))
		draw_polyline(pts, Color(1, 1, 1, 0.55 * (1.0 - t)), 1.0)


func _draw_flow(s: Rect2, col: Color) -> void:
	var horizontal := s.size.x >= s.size.y
	var length := s.size.x if horizontal else s.size.y
	var width := s.size.y if horizontal else s.size.x
	var row := 6.0
	var n := 0
	while row < width - 5.0:
		var start := fposmod(flow_offset + float(n * 7), DASH_LEN + DASH_GAP) - (DASH_LEN + DASH_GAP)
		var pos := start
		while pos < length:
			var a := maxf(pos, 0.0)
			var b := minf(pos + DASH_LEN, length)
			if b > a:
				var seg := Rect2(s.position.x + a, s.position.y + row, b - a, 1.0) if horizontal \
					else Rect2(s.position.x + row, s.position.y + a, 1.0, b - a)
				if not _on_path(seg):
					draw_rect(seg, col)
			pos += DASH_LEN + DASH_GAP
		row += ROW_GAP
		n += 1


func _on_path(seg: Rect2) -> bool:
	for p in _paths:
		if p.grow(4.0).intersects(seg):
			return true
	return false
