class_name BeastArrow
extends Control
## GFX-075: while a great beast walks in this region and is off screen, a small arrow at the screen edge
## points at it, tinted with its danger colour, with its short name under it. Hidden once it is on screen,
## beaten or gone. The arrow keeps clear of the HUD panels. reduce_motion: no pulse.

const MARGIN := 36.0
const ARROW_SIZE := 14.0
const NAME_SIZE := Vector2(150, 20)

var _info := {"visible": false}
var _name := ""
var _color := Color.WHITE
var _pulse := 0.0
var hud: Node  ## set by the world: its occupied_rects() are kept clear


## Where the edge arrow goes. `target` and `view` share one space (screen pixels). Returns
## {visible, position (clamped inside view shrunk by margin), angle (radians, from view centre to target)}.
static func edge_arrow(target: Vector2, view: Rect2, margin: float) -> Dictionary:
	if view.has_point(target):
		return {"visible": false, "position": target, "angle": 0.0}
	var inner := view.grow(-margin)
	var pos := Vector2(clampf(target.x, inner.position.x, inner.end.x), clampf(target.y, inner.position.y, inner.end.y))
	return {"visible": true, "position": pos, "angle": (target - view.get_center()).angle()}


## Slides `rect` along the screen edge (in 24 px steps) until it clears every rect in `avoid`; unchanged when none fits.
static func clear_of(rect: Rect2, avoid: Array[Rect2], view: Rect2) -> Rect2:
	var horizontal := rect.position.y <= view.position.y + 1.0 or rect.end.y >= view.end.y - 1.0
	for i in 60:
		for sign: int in [1, -1]:
			var step := Vector2(i * 24.0 * sign, 0.0) if horizontal else Vector2(0.0, i * 24.0 * sign)
			var r := Rect2(rect.position + step, rect.size)
			if not view.encloses(r):
				continue
			var hit := false
			for a: Rect2 in avoid:
				if r.intersects(a):
					hit = true
					break
			if not hit:
				return r
	return rect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("beast_arrow")


func _process(delta: float) -> void:
	_pulse += delta
	var beast := _great_roamer()
	var was := bool(_info["visible"])
	_info = {"visible": false}
	if beast != null:
		var screen := get_viewport().get_visible_rect()
		var target: Vector2 = beast.get_global_transform_with_canvas().origin
		_info = edge_arrow(target, screen, MARGIN)
		if bool(_info["visible"]):
			var box := Rect2(_info["position"] - Vector2(NAME_SIZE.x / 2.0, ARROW_SIZE), Vector2(NAME_SIZE.x, ARROW_SIZE * 2.0 + NAME_SIZE.y))
			var avoid: Array[Rect2] = []
			if hud != null and hud.has_method("occupied_rects"):
				avoid = hud.occupied_rects()
			var placed := clear_of(box, avoid, screen)
			_info["position"] = placed.position + Vector2(NAME_SIZE.x / 2.0, ARROW_SIZE)
			_name = beast.short_name()
			_color = beast.danger_color()
	if bool(_info["visible"]) or was:
		queue_redraw()


func _great_roamer() -> Roamer:
	for n in get_tree().get_nodes_in_group("great_roamer"):
		var r := n as Roamer
		if r != null and not r.is_queued_for_deletion() and r.is_visible_in_tree():
			return r
	return null


func _draw() -> void:
	if not bool(_info["visible"]):
		return
	var p: Vector2 = _info["position"]
	var a: float = _info["angle"]
	var s := ARROW_SIZE * (1.0 if MotionFx.reduced() else 1.0 + 0.15 * sin(_pulse * 4.0))
	var tip := p + Vector2.from_angle(a) * s
	var l := p + Vector2.from_angle(a + 2.5) * s
	var r := p + Vector2.from_angle(a - 2.5) * s
	draw_colored_polygon(PackedVector2Array([tip + Vector2(1, 1), l + Vector2(1, 1), r + Vector2(1, 1)]), Color(0, 0, 0, 0.6))
	draw_colored_polygon(PackedVector2Array([tip, l, r]), _color)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
	var at := Vector2(p.x - w / 2.0, p.y + ARROW_SIZE + 16.0)
	draw_string(font, at + Vector2(1, 1), _name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
	draw_string(font, at, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _color)
