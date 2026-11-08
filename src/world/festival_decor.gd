class_name FestivalDecor
extends Node2D
## GFX-093: festival decor around a region's festival_square while a festival runs: poles on a ring outside the
## crowd, strung with bunting or lanterns, one festival look per pole set. Code-drawn, no collision, gone the next day.

const RADIUS := 150.0
const SLOTS := 12
const CLEAR := 24.0
const EDGE := 160.0
const MIN_POLES := 6
const MAX_POLES := 8
const RED := Color("b83a2e")
const GOLD := Color("e0b84a")
const GREEN := Color("5f9f4a")
const POLE := Color("6b4a2e")
const OUTLINE := Color("2a2018")

var look := "lanterns"
var colors: Array[Color] = [RED, GOLD, GREEN]
var poles: Array[Vector2] = []
## Pole positions relative to this node (which sits on the square).
var _t := 0.0
var _phase := 0.0


## Pure layout: 4-6 pole spots on a ring around `center`, each 24 px clear of every blocker rect and at least
## 160 px from the map edge. Seeded by the festival id, so it does not jump on rebuild.
static func layout(center: Vector2, festival_id: String, blockers: Array[Rect2], map_size: Vector2) -> Array[Vector2]:
	var want := MIN_POLES + int(absi(festival_id.hash()) % (MAX_POLES - MIN_POLES + 1))
	var offset := float(absi(festival_id.hash() / 7) % SLOTS) / float(SLOTS)
	var out: Array[Vector2] = []
	var chosen: Array[int] = []
	for k in SLOTS:
		var pos := center + Vector2.from_angle(TAU * (float(k) + offset) / float(SLOTS)) * RADIUS
		if pos.x < EDGE or pos.y < EDGE or pos.x > map_size.x - EDGE or pos.y > map_size.y - EDGE:
			continue
		var ok := true
		for b in blockers:
			if b.grow(CLEAR).has_point(pos):
				ok = false
				break
		if ok:
			chosen.append(k)
	# Spread the poles evenly over the usable slots.
	if chosen.size() <= want:
		for k in chosen:
			out.append(center + Vector2.from_angle(TAU * (float(k) + offset) / float(SLOTS)) * RADIUS)
		return out
	for i in want:
		var k := chosen[int(float(i) * float(chosen.size()) / float(want))]
		out.append(center + Vector2.from_angle(TAU * (float(k) + offset) / float(SLOTS)) * RADIUS)
	return out


## Whether a look's lanterns glow (Mid-Autumn and the Lantern Festival).
static func glows(decor_look: String) -> bool:
	return decor_look == "lanterns" or decor_look == "moon"


func setup(festival_id: String, center: Vector2, blockers: Array[Rect2], map_size: Vector2) -> void:
	look = FestivalStall.decor_for(festival_id)
	colors = FestivalStall.colors_for(festival_id)
	position = center
	poles.clear()
	for p in layout(center, festival_id, blockers, map_size):
		poles.append(p - center)
	queue_redraw()


func _process(delta: float) -> void:
	if MotionFx.reduced() or not visible or not glows(look):
		return
	_t += delta
	var p := snappedf(sin(_t * 1.6), 0.25)
	if not is_equal_approx(p, _phase):
		_phase = p
		queue_redraw()


## GFX-097: pennants hang every 14 px along a string.
const FLAG_STEP := 14.0


func _draw() -> void:
	var n := poles.size()
	_draw_cloth()
	for i in n:
		var a := poles[i] + Vector2(0, -38)
		draw_line(poles[i], a, OUTLINE, 6.0)
		draw_line(poles[i], a, POLE, 4.0)
		draw_circle(a, 4.0, GOLD)
		if i + 1 < n or n > 2:
			var b := poles[(i + 1) % n] + Vector2(0, -38)
			if a.distance_to(b) < RADIUS * 1.2:
				_string(a, b, i)
	if n > 0 and look != "lanterns" and look != "moon":
		FestivalStall.draw_look(self, look, poles[0] + Vector2(0, 6), _phase)


## GFX-097: a swept flagstone disc with a red and gold border under the square, so it reads from across the village.
func _draw_cloth() -> void:
	var r := RADIUS - 14.0
	draw_circle(Vector2.ZERO, r, Color(0.72, 0.62, 0.48, 0.32))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(RED, 0.75), 6.0)
	draw_arc(Vector2.ZERO, r - 5.0, 0.0, TAU, 48, Color(GOLD, 0.8), 2.0)


func _string(a: Vector2, b: Vector2, index: int) -> void:
	var mid := (a + b) / 2.0 + Vector2(0, 14)
	var steps := maxi(8, int(a.distance_to(b) / 7.0))
	var prev := a
	var since := FLAG_STEP / 2.0
	var k := 0
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		var q: Vector2 = (1.0 - t) * (1.0 - t) * a + 2.0 * (1.0 - t) * t * mid + t * t * b
		draw_line(prev, q, OUTLINE, 2.0)
		since += prev.distance_to(q)
		if since >= FLAG_STEP and s < steps:
			since = 0.0
			if glows(look):
				draw_circle(q + Vector2(0, 9), 13.0, Color(1.0, 0.8, 0.4, 0.14 + 0.04 * _phase))
				draw_circle(q + Vector2(0, 9), 7.0, RED.lightened(0.1))
				draw_circle(q + Vector2(0, 9), 7.0, GOLD, false, 2.0)
			else:
				var col: Color = colors[(index + k) % colors.size()]
				var tri := PackedVector2Array([q + Vector2(-5, 0), q + Vector2(5, 0), q + Vector2(0, 12)])
				draw_colored_polygon(tri, col)
				draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), OUTLINE, 1.0)
			k += 1
		prev = q
