extends TestCase
## GFX-205: PeakDressing layout of Azure Peak: deterministic, draw-only, clear of places, paths and labels.


func _azure() -> Dictionary:
	return GameData.load_from_dir().regions["azure_peak"]


func test_only_peak_regions_are_dressed() -> void:
	var data := GameData.load_from_dir()
	assert_true(PeakDressing.enabled(data.regions["azure_peak"]))
	assert_false(PeakDressing.enabled(data.regions["qingshi_village"]))
	assert_true((PeakDressing.layout(data.regions["qingshi_village"])["cliffs"] as Array).is_empty())


func test_layout_deterministic_with_cliffs_on_top_and_right() -> void:
	var r := _azure()
	var a := PeakDressing.layout(r)
	assert_eq(a, PeakDressing.layout(r))
	var sides := {}
	for c: Dictionary in a["cliffs"]:
		sides[c["side"]] = true
	assert_true(sides.has("top") and sides.has("right"))
	assert_true((a["pines"] as Array).size() >= 3, "pine clusters placed")
	assert_true((a["terraces"] as Array).size() >= 1, "terraces placed")


func test_props_clear_of_places_paths_and_labels() -> void:
	var r := _azure()
	var a := PeakDressing.layout(r)
	var blocked := Scenery.blocked_rects(r)
	var props: Array[Rect2] = []
	props.append_array(a["terraces"])
	props.append_array(a["stairs"])
	for p: Dictionary in a["pines"]:
		props.append(Rect2(p["pos"] - Vector2(10.0, 30.0), Vector2(20.0, 30.0)))
	for pr in props:
		for b in blocked:
			assert_false(b.intersects(pr), "prop %s inside blocked %s" % [pr, b])
		for pl: Dictionary in r["places"]:
			var c := Vector2(float(pl["pos"][0]), float(pl["pos"][1]))
			var label := Rect2(c.x - 70.0, c.y - float((pl.get("size", [64, 64]) as Array)[1]) / 2.0 - 40.0, 140.0, 24.0)
			assert_false(label.intersects(pr), "prop %s under the label of %s" % [pr, pl.get("name", "?")])


func test_validate_rejects_non_bool_peak() -> void:
	var data := GameData.load_from_dir()
	data.regions["azure_peak"]["map"]["high"]["peak"] = 3
	assert_eq(Scenery.validate(data).size(), 1)
