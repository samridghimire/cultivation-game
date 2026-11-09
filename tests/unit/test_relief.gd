extends TestCase
## GFX-109: map.relief layout (ledges, boulders, drifts) and validation.


func _regions() -> Array[Dictionary]:
	var data := GameData.load_from_dir()
	return [data.regions["myriad_peaks_ridge"], data.regions["azure_peak"]]


func _near(rect: Rect2, c: Vector2) -> float:
	return Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y)).distance_to(c)


func test_deterministic_and_empty_without_relief() -> void:
	for region in _regions():
		var a := Scenery.relief_layout(region)
		var b := Scenery.relief_layout(region)
		assert_false(a.is_empty())
		assert_eq(a.size(), b.size())
		for i in a.size():
			assert_eq(a[i]["rect"], b[i]["rect"])
	assert_true(Scenery.relief_layout({"id": "x", "map": {}}).is_empty())


func test_relief_stays_clear() -> void:
	for region in _regions():
		var map: Dictionary = region["map"]
		var cfg: Dictionary = map["relief"]
		var counts := {"ledge": 0, "boulders": 0, "drift": 0}
		var items := Scenery.relief_layout(region)
		for i in items.size():
			var r: Rect2 = items[i]["rect"]
			counts[items[i]["kind"]] += 1
			assert_true(Rect2(Vector2(24, 24), Vector2(1552, 952)).encloses(r), "inside border")
			for p in map["paths"]:
				assert_false(Rect2(p[0], p[1], p[2], p[3]).grow(12.0).intersects(r), "path")
			for pl: Dictionary in region["places"]:
				var sz := Vector2(pl["size"][0], pl["size"][1])
				assert_false(Rect2(Vector2(pl["pos"][0], pl["pos"][1]) - sz / 2.0, sz).grow(16.0).intersects(r), "place " + String(pl["id"]) if pl.has("id") else "place")
			for lm in Scenery.landmark_rects(region):
				assert_false(lm.intersects(r), "landmark")
			assert_true(_near(r, Vector2(region["spawn"][0], region["spawn"][1])) >= 60.0, "spawn")
			for s in region.get("npc_spots", []):
				assert_true(_near(r, Vector2(s[0], s[1])) >= 24.0, "npc spot")
			for j in i:
				assert_false((items[j]["rect"] as Rect2).intersects(r), "no overlap")
		assert_true(counts["ledge"] <= int(cfg["ledges"]))
		assert_true(counts["boulders"] <= int(cfg["boulders"]))
		assert_true(counts["ledge"] > 0)


func test_validation_rejects_bad_relief() -> void:
	var data := GameData.load_from_dir()
	var map: Dictionary = data.regions["azure_peak"]["map"]
	var good: Dictionary = map["relief"]
	for bad in [{"ledges": 13}, {"snow": 1.5}, {"stone": 1}]:
		map["relief"] = bad
		assert_false(Scenery.validate(data).is_empty())
	map["relief"] = good
	assert_true(Scenery.validate(data).is_empty())
