extends TestCase
## GFX-110: map.edge props along the outer map edge, and validation.


func test_every_region_has_a_valid_edge() -> void:
	var data := GameData.load_from_dir()
	assert_eq(Scenery.validate(data).size(), 0)
	for region: Dictionary in data.regions.values():
		if region["map"].has("edge"):
			assert_false(Scenery.edge_props(region, Vector2(1600, 1000)).is_empty(), region["id"])


func test_props_hug_the_edge_and_leave_paths_clear() -> void:
	var data := GameData.load_from_dir()
	for region: Dictionary in data.regions.values():
		var map: Dictionary = region["map"]
		var size := Vector2(float(map["size"][0]), float(map["size"][1]))
		var inner := Rect2(Vector2.ZERO, size).grow(-24.0)
		for it: Dictionary in Scenery.edge_props(region, size):
			var r: Rect2 = it["rect"]
			assert_false(inner.intersects(r), "%s prop reaches more than 24 px into the map" % region["id"])
			for p in map.get("paths", []):
				var pr := Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
				assert_false(pr.intersects(r), "%s prop on a path" % region["id"])


func test_deterministic_and_empty_by_default() -> void:
	var data := GameData.load_from_dir()
	var region: Dictionary = data.regions["fallen_star_market"]
	var a := Scenery.edge_props(region, Vector2(1600, 1000))
	var b := Scenery.edge_props(region, Vector2(1600, 1000))
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i]["rect"], b[i]["rect"])
	assert_true(Scenery.edge_props({"id": "x", "map": {}}, Vector2(1600, 1000)).is_empty())


func test_bad_edge_is_rejected() -> void:
	var data := GameData.load_from_dir()
	data.regions["qingshi_village"]["map"]["edge"] = "moat"
	assert_true(Scenery.validate(data).size() > 0)


func test_jagged_outline() -> void:
	var rect := Rect2(10, 20, 100, 30)
	var a := Scenery.jagged_outline(rect, 7, 12, 6.0)
	assert_eq(a, Scenery.jagged_outline(rect, 7, 12, 6.0), "deterministic")
	assert_eq(a.size(), 12)
	assert_eq(a[0], Vector2(10, 50), "starts bottom-left")
	assert_eq(a[a.size() - 1], Vector2(110, 50), "ends bottom-right")
	for p in a:
		assert_true(rect.grow(6.0).has_point(p), "inside grown rect")


func test_cliff_props_have_height_jitter() -> void:
	var props := Scenery.edge_props({"id": "azure_peak", "map": {"edge": "cliff", "paths": []}}, Vector2(1600, 1000))
	assert_false(props.is_empty())
	for it: Dictionary in props:
		assert_true(float(it["h"]) >= 0.65 and float(it["h"]) <= 1.0)
