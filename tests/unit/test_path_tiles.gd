## GFX-112: Scenery.path_tiles lays road pieces deterministically inside the path rect, none on a bridge.
extends TestCase


func _region(style: String, water: String = "clear") -> Dictionary:
	return {"id": "r", "map": {"ground_style": style, "water": water, "landmarks": [{"kind": "stream", "pos": [400, 500], "size": [30, 1000]}]}}


func test_deterministic_and_inside() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	for style in ["grass", "scree", "paved", "bog", "litter"]:
		var a := Scenery.path_tiles(_region(style), rect)
		assert_true(a.size() > 5, style + " has tiles")
		assert_eq(a, Scenery.path_tiles(_region(style), rect), style + " deterministic")
		for t in a:
			assert_true(rect.grow(0.01).encloses(t["rect"]), style + " tile inside the path")


func test_kinds_by_style() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	assert_eq(Scenery.path_tiles(_region("scree"), rect)[0]["kind"], "slab")
	assert_eq(Scenery.path_tiles(_region("bog", "murky"), rect)[0]["kind"], "plank")
	var kinds := {}
	for t in Scenery.path_tiles(_region("bog"), rect):
		kinds[t["kind"]] = true
	assert_true(kinds.has("puddle") and kinds.has("rut"), "muddy track")


func test_nothing_on_bridge() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	var bridge := Rect2(385, 0, 30, 1000)
	for style in ["grass", "scree", "bog"]:
		for t in Scenery.path_tiles(_region(style), rect):
			assert_false(bridge.intersects(t["rect"]), style + " tile on bridge")
