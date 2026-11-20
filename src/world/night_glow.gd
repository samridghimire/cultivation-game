class_name NightGlow
extends Node2D
## GFX-217: warm glows over lantern landmarks and house windows while a day cycle is at night.
## Additive blending, so the CanvasModulate night tint does not hide them.

var _spots: Array[Vector3] = []  ## x, y, radius
var strength: float = 0.0:
	set(v):
		strength = v
		visible = v > 0.01
		queue_redraw()


func _init() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	visible = false
	z_index = 50


const MAX_SPOTS := 40
## GFX-218: place types that are roofed buildings (one lit window/door each); merchants are stalls (one lantern).
const GLOW_KINDS: Array[String] = ["workshop", "clinic", "orphanage", "family_home", "auction", "sect_hall", "shrine"]
const STALL_KIND := "merchant"


## Collects glow spots from a region's map.landmarks and its places (capped at MAX_SPOTS).
func setup(landmarks: Array, places: Array = []) -> void:
	_spots.clear()
	for lm: Dictionary in landmarks:
		var pos: Array = lm.get("pos", [0, 0])
		var size: Array = lm.get("size", [0, 0])
		var c := Vector2(float(pos[0]), float(pos[1]))
		var s := Vector2(float(size[0]), float(size[1]))
		match String(lm.get("kind", "")):
			"lantern":
				var p := c - Vector2(0, s.y * 0.3)
				_spots.append(Vector3(p.x, p.y, 16.0))
			"house":
				_spots.append(Vector3(c.x - s.x * 0.22, c.y + s.y * 0.1, 10.0))
				_spots.append(Vector3(c.x + s.x * 0.22, c.y + s.y * 0.1, 10.0))
	for place: Dictionary in places:
		var t := String(place.get("type", ""))
		var is_stall := t == STALL_KIND
		if not is_stall and not GLOW_KINDS.has(t):
			continue
		var pp: Array = place.get("pos", [0, 0])
		var ps: Array = place.get("size", [0, 0])
		var pc := Vector2(float(pp[0]), float(pp[1]))
		var psz := Vector2(float(ps[0]), float(ps[1]))
		if is_stall:
			_spots.append(Vector3(pc.x - psz.x * 0.4, pc.y - psz.y * 0.1, 10.0))
		else:
			_spots.append(Vector3(pc.x, pc.y + psz.y * 0.25, 12.0))
	if _spots.size() > MAX_SPOTS:
		_spots.resize(MAX_SPOTS)
	queue_redraw()


func spot_count() -> int:
	return _spots.size()


func _draw() -> void:
	if strength <= 0.01:
		return
	var view := get_viewport_rect()
	var cam := get_viewport().get_canvas_transform().affine_inverse()
	var visible_rect: Rect2 = (cam * view).grow(40.0)
	for s in _spots:
		if not visible_rect.has_point(Vector2(s.x, s.y)):
			continue
		for i in 3:
			var r := s.z * (1.0 - 0.3 * i)
			draw_circle(Vector2(s.x, s.y), r, Color(0.55, 0.35, 0.12, 0.5 * strength))
