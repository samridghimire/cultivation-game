class_name RainEaves
extends Node2D
## GFX-190: rain on the roofs. On a rain day every building in view drips from its eaves (3-6 short
## streaks that fall every ~0.6 s, seeded per building) and has a darker wet band along its base.
## None in snow or when it is not raining. Draw-only, seeded locally, never GameState.rng.

const DRIP_PERIOD := 0.6
const BAND_H := 3.0

var _items: Array[Dictionary] = []
var _clock := 0.0
var _reduce := false


## Per building {base: Rect2 (wet band), drips: Array of {x, y, phase}} for a region; empty unless raining.
static func layout(region: Dictionary, today: String, snowy: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if snowy or not Ambient.is_wet(today):
		return out
	for pl: Dictionary in region.get("places", []):
		if not String(pl.get("type", "")) in Npcs.BUILDING_TYPES:
			continue
		var sz: Array = pl.get("size", [64, 64])
		var pos: Array = pl.get("pos", [0, 0])
		var size := Vector2(float(sz[0]), float(sz[1])) * 1.3  # the drawn building (Npcs.building_footprint without clearance)
		var box := Rect2(Vector2(float(pos[0]), float(pos[1])) - size / 2.0, size)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s|eaves|%s" % [region.get("id", ""), pl.get("name", "")])
		var eave_y := box.position.y + box.size.y * 0.55
		var drips: Array[Dictionary] = []
		for i in 3 + rng.randi() % 4:
			drips.append({"x": box.position.x + box.size.x * (0.1 + 0.8 * rng.randf()), "y": eave_y, "phase": rng.randf() * DRIP_PERIOD})
		out.append({"base": Rect2(box.position.x + 2.0, box.end.y - BAND_H, box.size.x - 4.0, BAND_H), "drips": drips})
	return out


func setup(region: Dictionary, today: String, snowy: bool, reduce_motion: bool) -> void:
	_items = layout(region, today, snowy)
	_reduce = reduce_motion
	_clock = 0.0
	z_index = 2
	set_process(not _items.is_empty() and not reduce_motion)
	queue_redraw()


func item_count() -> int:
	return _items.size()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	for it in _items:
		draw_rect(it["base"] as Rect2, Color(0.04, 0.06, 0.1, 0.28))
		for d: Dictionary in it["drips"]:
			var k := 0.5 if _reduce else fposmod(_clock + float(d["phase"]), DRIP_PERIOD) / DRIP_PERIOD
			var y0 := float(d["y"]) + k * 7.0
			draw_line(Vector2(float(d["x"]), y0), Vector2(float(d["x"]), y0 + 4.0), Color(0.75, 0.86, 0.97, 0.75 * (1.0 - k * 0.6)), 1.0)
