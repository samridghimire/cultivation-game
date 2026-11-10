class_name MistBands
extends Node2D
## GFX-091: long, soft, low-alpha mist bands that drift sideways over a misty region's ground
## (map.mist >= MIN_MIST), under figures and labels. The layout is pure and seeded by region id so
## bands never jump on rebuild. With reduce_motion the bands stay put (no `_process`).

const MIN_MIST := 0.5
const MIN_BANDS := 3
const MAX_BANDS := 5
const MIN_SPEED := 8.0
const MAX_SPEED := 15.0
const ALPHA_MIN := 0.08
const ALPHA_MAX := 0.15

var _bands: Array[Dictionary] = []
var _map_size := Vector2(1600, 1000)
var _clock := 0.0


## Whether a region with this map.mist draws bands at all.
static func enabled(mist: float) -> bool:
	return mist >= MIN_MIST


## Band layout: [{y, h, w, x0, speed, alpha}], 3-5 bands. alpha is 0.08-0.15 x mist; speed 8-15 px/s.
static func layout(region_id: String, mist: float, map_size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not enabled(mist):
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([region_id, "mist_bands"])
	var count := rng.randi_range(MIN_BANDS, MAX_BANDS)
	for i in count:
		var w := rng.randf_range(0.5, 0.8) * map_size.x
		out.append({
			"y": (float(i) + rng.randf_range(0.2, 0.8)) / count * map_size.y,
			"h": rng.randf_range(60.0, 110.0),
			"w": w,
			"x0": rng.randf_range(0.0, map_size.x + w),
			"speed": rng.randf_range(MIN_SPEED, MAX_SPEED),
			"alpha": rng.randf_range(ALPHA_MIN, ALPHA_MAX) * mist,
		})
	return out


## Left edge of a band after `t` seconds: it drifts right and wraps from the map's right edge
## (band fully off-screen) back to just left of the map.
static func band_x(band: Dictionary, t: float, map_width: float) -> float:
	var period := map_width + float(band["w"])
	return fposmod(float(band["x0"]) + float(band["speed"]) * t, period) - float(band["w"])


func setup(region_id: String, mist: float, map_size: Vector2, animate: bool) -> void:
	_map_size = map_size
	_bands = layout(region_id, mist, map_size)
	_clock = 0.0
	set_process(animate and not _bands.is_empty())
	visible = not _bands.is_empty()
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var tex := Ambient.soft_texture()
	for b in _bands:
		var x := band_x(b, _clock, _map_size.x)
		draw_texture_rect(tex, Rect2(x, float(b["y"]), float(b["w"]), float(b["h"])), false, Color(0.85, 0.9, 0.9, float(b["alpha"])))
