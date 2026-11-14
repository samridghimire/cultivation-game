class_name CloudWisps
extends Node2D
## GFX-113: slow pale cloud wisps drifting along the top of a mountain region (map.high.wisps), over the cliffs.
## The layout is pure and seeded by region id; with reduce_motion the wisps stay put (no `_process`).

var _wisps: Array[Dictionary] = []
var _map_width := 1600.0
var _clock := 0.0


## [{y, h, w, x0, speed, alpha}] for `count` wisps in the top 150 px of a map (speed 6-12 px/s).
static func layout(region_id: String, count: int, map_size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([region_id, "cloud_wisps"])
	for i in clampi(count, 0, 8):
		var w := rng.randf_range(80.0, 160.0)
		out.append({
			"y": rng.randf_range(0.0, 130.0),
			"h": rng.randf_range(26.0, 48.0),
			"w": w,
			"x0": rng.randf_range(0.0, map_size.x + w),
			"speed": rng.randf_range(6.0, 12.0),
			"alpha": rng.randf_range(0.18, 0.32),
		})
	return out


## Left edge of a wisp after `t` seconds (drifts right, wraps from off the right edge to off the left).
static func wisp_x(wisp: Dictionary, t: float, map_width: float) -> float:
	var period := map_width + float(wisp["w"])
	return fposmod(float(wisp["x0"]) + float(wisp["speed"]) * t, period) - float(wisp["w"])


func setup(region: Dictionary, map_size: Vector2, animate: bool) -> void:
	_map_width = map_size.x
	var high: Variant = region.get("map", {}).get("high", null)
	var count := int(high.get("wisps", 0)) if high is Dictionary else 0
	_wisps = layout(String(region.get("id", "")), count, map_size)
	_clock = 0.0
	set_process(animate and not _wisps.is_empty())
	visible = not _wisps.is_empty()
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var tex := Ambient.soft_texture()
	for i in _wisps.size():
		var w: Dictionary = _wisps[i]
		var x := wisp_x(w, _clock, _map_width)
		var ww := float(w["w"])
		var hh := float(w["h"])
		for k in 4:  # GFX-145: 3-5 overlapping soft puffs of falling alpha, no hard edge
			var t := float(k) / 3.0
			var pw := ww * lerpf(0.5, 0.3, absf(t - 0.5) * 2.0 * 0.5 + 0.5 * float((i + k) % 2))
			var cx := x + ww * lerpf(0.2, 0.8, t)
			var ph := hh * (0.8 + 0.25 * float((i + k) % 3))
			draw_texture_rect(tex, Rect2(cx - pw / 2.0, float(w["y"]) + (hh - ph) / 2.0, pw, ph), false, Color(0.96, 0.98, 1.0, float(w["alpha"]) * lerpf(1.0, 0.55, absf(t - 0.5) * 2.0)))
