class_name TitleBackdrop
extends Control
## Painted title-screen backdrop drawn in code: a night sky, a pale moon, layered
## ink-wash mountain ridges and slowly drifting mist bands. No binary assets.

const RIDGES: Array[Dictionary] = [
	{"base": 0.52, "amp": 0.10, "freq": 1.3, "phase": 0.4, "color": Color(0.20, 0.25, 0.36)},
	{"base": 0.62, "amp": 0.09, "freq": 1.9, "phase": 2.1, "color": Color(0.14, 0.18, 0.28)},
	{"base": 0.72, "amp": 0.08, "freq": 2.4, "phase": 4.0, "color": Color(0.10, 0.13, 0.21)},
	{"base": 0.84, "amp": 0.06, "freq": 3.1, "phase": 5.3, "color": Color(0.06, 0.08, 0.14)},
]
const MIST_BANDS := 4
const SKY_TOP := Color(0.05, 0.07, 0.14)
const SKY_BOTTOM := Color(0.22, 0.28, 0.40)
const MOON := Color(0.93, 0.94, 0.88)

var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Height (0..1 of the screen) of ridge `index` at horizontal position x (0..1).
static func ridge_height(index: int, x: float) -> float:
	var r: Dictionary = RIDGES[index]
	var f: float = r["freq"]
	var p: float = r["phase"]
	var wave: float = sin(x * TAU * f + p) * 0.6 + sin(x * TAU * f * 2.3 + p * 1.7) * 0.4
	return float(r["base"]) - float(r["amp"]) * wave


func _draw() -> void:
	var s := size
	var steps := 8
	for i in steps:
		var t0 := float(i) / steps
		draw_rect(Rect2(0, s.y * t0, s.x, s.y / steps + 1), SKY_TOP.lerp(SKY_BOTTOM, t0))
	var moon_pos := Vector2(s.x * 0.76, s.y * 0.2)
	var radius := s.y * 0.07
	for g in 4:
		draw_circle(moon_pos, radius * (2.6 - g * 0.5), Color(MOON, 0.04 + g * 0.02))
	draw_circle(moon_pos, radius, MOON)
	for i in RIDGES.size():
		var pts := PackedVector2Array()
		for k in 41:
			var x := float(k) / 40.0
			pts.append(Vector2(s.x * x, s.y * ridge_height(i, x)))
		pts.append(Vector2(s.x, s.y))
		pts.append(Vector2(0, s.y))
		draw_colored_polygon(pts, RIDGES[i]["color"])
		_draw_mist(i, s)


func _draw_mist(layer: int, s: Vector2) -> void:
	if layer >= MIST_BANDS:
		return
	var y := s.y * (RIDGES[layer]["base"] as float) + s.y * 0.07
	var drift := sin(_time * 0.12 + layer * 1.9) * s.x * 0.06
	for b in 3:
		var cx := s.x * (0.2 + 0.3 * b) + drift * (1.0 + 0.4 * b)
		var w := s.x * 0.34
		var h := s.y * 0.028
		var c := Color(0.75, 0.82, 0.9, 0.07)
		draw_rect(Rect2(cx - w / 2, y + b * 6, w, h), c)
		draw_rect(Rect2(cx - w * 0.35, y + b * 6 - h * 0.5, w * 0.7, h * 2), Color(c, 0.04))
