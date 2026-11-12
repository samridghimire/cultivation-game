extends TestCase
## GFX-113: a sect on a mountain: map.high validation, leaning pines, cloud wisps, court rail.


func _region() -> Dictionary:
	return {
		"id": "peak", "places": [],
		"map": {"size": [1600, 1000], "paths": [[0, 470, 1600, 60]], "high": {"rail": true, "wisps": 5, "lean_pines": 3},
			"landmarks": [{"kind": "cliff", "pos": [240, 30], "size": [460, 60]}, {"kind": "cliff", "pos": [1330, 30], "size": [500, 60]}]},
	}


func test_azure_peak_has_high_and_validates() -> void:
	var data := GameData.load_from_dir()
	assert_true(data.regions["azure_peak"]["map"].has("high"))
	assert_eq(Scenery.validate(data).size(), 0, "regions validate")


func test_validate_rejects_bad_high() -> void:
	var data := GameData.load_from_dir()
	data.regions["azure_peak"]["map"]["high"] = {"wisps": 99, "bogus": 1, "rail": 3}
	assert_eq(Scenery.validate(data).size(), 3)


func test_high_pines_deterministic_clear_and_capped() -> void:
	var r := _region()
	var a := Scenery.high_pines(r)
	assert_eq(a, Scenery.high_pines(r))
	assert_true(a.size() >= 1 and a.size() <= 3)
	var blocked := Scenery.blocked_rects(r)
	for p in a:
		assert_true(p["pos"].y < 500.0, "on the top half")
		for b in blocked:
			assert_false(b.has_point(p["pos"]), "foot not inside a blocked rect")
	r["map"].erase("high")
	assert_true(Scenery.high_pines(r).is_empty())


func test_wisps_layout_and_wrap() -> void:
	var w := CloudWisps.layout("peak", 5, Vector2(1600, 1000))
	assert_eq(w.size(), 5)
	assert_eq(w, CloudWisps.layout("peak", 5, Vector2(1600, 1000)))
	for x in w:
		assert_true(float(x["y"]) <= 130.0)
		var px := CloudWisps.wisp_x(x, 100000.0, 1600.0)
		assert_true(px >= -float(x["w"]) and px < 1600.0)
	assert_true(CloudWisps.layout("peak", 0, Vector2(1600, 1000)).is_empty())


func test_rail_parts_leave_a_gap_on_the_south_side() -> void:
	var court := Rect2(100, 100, 300, 200)
	var parts := SectCourt.rail_parts(court)
	assert_true(parts["posts"].size() > 8)
	var cx := court.get_center().x
	for p: Rect2 in parts["posts"]:
		if p.position.y > court.end.y - 14.0:
			assert_true(absf(p.get_center().x - cx) > 20.0, "gap at the centre")
		assert_true(court.grow(2.0).encloses(p), "posts stay inside the court")


func test_high_crags_clear_deterministic_and_capped() -> void:
	var data := GameData.load_from_dir()
	assert_eq(Scenery.validate(data).size(), 0, "regions validate")
	for id in ["myriad_peaks_ridge", "azure_peak"]:
		var region: Dictionary = data.regions[id]
		var cfg: Dictionary = region["map"]["high"]
		var items := Scenery.high_crags(region)
		assert_eq(items, Scenery.high_crags(region))
		var crags := 0
		var drifts := 0
		var relief := Scenery.relief_layout(region)
		for it in items:
			var r: Rect2 = it["rect"]
			if it["kind"] == "crag":
				crags += 1
				assert_true(r.size.x >= 60.0 and r.size.x <= 140.0, "crag width")
			else:
				drifts += 1
			for p in region["map"]["paths"]:
				assert_false(Rect2(p[0], p[1], p[2], p[3]).intersects(r), "path")
			for pl: Dictionary in region["places"]:
				var sz := Vector2(pl["size"][0], pl["size"][1])
				assert_false(Rect2(Vector2(pl["pos"][0], pl["pos"][1]) - sz / 2.0, sz).intersects(r), "place")
			for lm in Scenery.landmark_rects(region):
				assert_false(lm.intersects(r), "landmark")
			for rl in relief:
				assert_false((rl["rect"] as Rect2).intersects(r), "relief")
		assert_true(crags <= int(cfg.get("crags", 0)))
		assert_true(drifts <= int(cfg.get("drifts", 0)))
		assert_true(crags >= 1, id + " has crags")
	var r2 := _region()
	r2["map"].erase("high")
	assert_true(Scenery.high_crags(r2).is_empty())


func test_validate_rejects_bad_crags() -> void:
	var data := GameData.load_from_dir()
	data.regions["azure_peak"]["map"]["high"] = {"crags": 9, "drifts": 13}
	assert_eq(Scenery.validate(data).size(), 2)
