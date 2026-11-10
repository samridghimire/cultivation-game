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
