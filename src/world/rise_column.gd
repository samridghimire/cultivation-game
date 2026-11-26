class_name RiseColumn
extends Node2D
## GFX-262: a friend breaks through in sight: a tall soft light column over their figure with rising motes and a
## "<Name>: <realm>!" label, about 2.5 s, then it fades. Motes are a pure function of the phase (no rng).

const LIFETIME := 2.5
const HEIGHT := 150.0
const MOTES := 10

var _t := 0.0
var _color := Color(1.0, 0.9, 0.55)
var _label: Label


## "Xiao Ling: Qi Refining!"
static func text_for(npc_name: String, realm: String) -> String:
	return "%s: %s!" % [npc_name, realm] if realm != "" else "%s rises!" % npc_name


## Column alpha at `t` seconds: swells in over the first 0.4 s, holds, fades over the last 0.8 s.
static func alpha_at(t: float) -> float:
	if t < 0.0 or t >= LIFETIME:
		return 0.0
	return minf(t / 0.4, 1.0) * minf((LIFETIME - t) / 0.8, 1.0)


## Mote `i` position relative to the figure's feet at `t`: drifts upward and loops.
static func mote_pos(i: int, t: float) -> Vector2:
	var rise := fposmod(t * (40.0 + 6.0 * float(i % 3)) + float(i) * 17.0, HEIGHT)
	return Vector2(sin(float(i) * 2.1 + t * 1.5) * 9.0, -rise)


## Plays the effect on `parent` at `feet` (world space). Returns the node.
static func spawn(parent: Node, feet: Vector2, npc_name: String, realm: String) -> RiseColumn:
	var col := RiseColumn.new()
	col.position = feet
	col.z_index = 18
	col._label = Label.new()
	col._label.text = text_for(npc_name, realm)
	col._label.add_theme_font_size_override("font_size", 14)
	col._label.add_theme_color_override("font_color", UIStyle.ACCENT)
	col._label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	col._label.add_theme_constant_override("outline_size", 3)
	col._label.custom_minimum_size.x = 160.0
	col._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col._label.position = Vector2(-80, -HEIGHT - 22)
	col.add_child(col._label)
	parent.add_child(col)
	return col


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	_label.modulate.a = alpha_at(_t)
	queue_redraw()


func _draw() -> void:
	var a := alpha_at(_t)
	for k in 3:  # three nested bands make the soft edge
		var w := 14.0 - 4.0 * float(k)
		draw_rect(Rect2(-w, -HEIGHT, w * 2.0, HEIGHT), Color(_color.r, _color.g, _color.b, 0.10 * a))
	for i in MOTES:
		var p := mote_pos(i, _t)
		draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Color(1, 0.97, 0.8, 0.9 * a))
