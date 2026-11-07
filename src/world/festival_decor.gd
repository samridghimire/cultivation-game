class_name FestivalDecor
extends Node2D
## GFX-093: festival decor around a region's festival_square while a festival runs: poles on a ring outside the
## crowd, strung with bunting or lanterns, one festival look per pole set. Code-drawn, no collision, gone the next day.

const RADIUS := 150.0
const SLOTS := 10
const CLEAR := 24.0
const EDGE := 160.0
const MIN_POLES := 4
const MAX_POLES := 6
const RED := Color("b83a2e")
const GOLD := Color("e0b84a")
const GREEN := Color("5f9f4a")
const POLE := Color("6b4a2e")
const OUTLINE := Color("2a2018")

var look := "lanterns"
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


func _draw() -> void:
	var n := poles.size()
	for i in n:
		var a := poles[i] + Vector2(0, -34)
		draw_line(poles[i], a, POLE, 3.0)
		if i + 1 < n or n > 2:
			var b := poles[(i + 1) % n] + Vector2(0, -34)
			if a.distance_to(b) < RADIUS * 1.2:
				_string(a, b, i)
	if n > 0 and look != "lanterns" and look != "moon":
		FestivalStall.draw_look(self, look, poles[0] + Vector2(0, 6), _phase)


func _string(a: Vector2, b: Vector2, index: int) -> void:
	var mid := (a + b) / 2.0 + Vector2(0, 12)
	var prev := a
	for s in range(1, 9):
		var t := float(s) / 8.0
		var q: Vector2 = (1.0 - t) * (1.0 - t) * a + 2.0 * (1.0 - t) * t * mid + t * t * b
		draw_line(prev, q, OUTLINE, 1.0)
		if s % 2 == 0 and s < 8:
			var c := q + Vector2(0, 7)
			if glows(look):
				draw_circle(c, 10.0, Color(1.0, 0.8, 0.4, 0.14 + 0.04 * _phase))
				draw_circle(c, 5.0, RED.lightened(0.1))
				draw_circle(c, 5.0, GOLD, false, 1.0)
			else:
				var col := [RED, GOLD, GREEN][(index + s / 2) % 3] as Color
				draw_colored_polygon(PackedVector2Array([q + Vector2(-4, 0), q + Vector2(4, 0), q + Vector2(0, 9)]), col)
		prev = q
