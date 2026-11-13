## GFX-136: marsh pools, mud, bones and dead trees are seeded, counted and clear of roads, places, label bands and npc spots.
extends TestCase


func _bone_marsh() -> Dictionary:
	var f := FileAccess.open("res://data/regions.json", FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	for r: Dictionary in data["regions"]:
		if r["id"] == "withered_bone_marsh":
			return r
	return {}


func test_counts_in_range_and_deterministic() -> void:
	var region := _bone_marsh()
	assert_false(region.is_empty(), "region found")
	var keep := Scenery.marsh_keepouts(region)
	var size := Vector2(1600, 1000)
	var a := Scenery.marsh_features(hash("withered_bone_marsh|marsh"), size, keep)
	var b := Scenery.marsh_features(hash("withered_bone_marsh|marsh"), size, keep)
	assert_eq(a["pools"].size(), b["pools"].size(), "deterministic pools")
	assert_eq(a["mud"].size(), b["mud"].size(), "deterministic mud")
	assert_true(a["pools"].size() >= 10 and a["pools"].size() <= 16, "10-16 pools, got %d" % a["pools"].size())
	assert_true(a["mud"].size() >= 6 and a["mud"].size() <= 10, "6-10 mud, got %d" % a["mud"].size())
	assert_true(a["dead"].size() >= 6 and a["dead"].size() <= 10, "6-10 dead trees, got %d" % a["dead"].size())
	assert_true(a["bones"].size() >= 3, "some bones")


func test_nothing_overlaps_keepouts() -> void:
	var region := _bone_marsh()
	var keep := Scenery.marsh_keepouts(region)
	var f := Scenery.marsh_features(hash("withered_bone_marsh|marsh"), Vector2(1600, 1000), keep)
	for pool: Dictionary in f["pools"]:
		var r: Rect2 = pool["rect"]
		assert_true(r.size.x <= 110.0, "pool no wider than ~90 px plus margin")
		for k in keep:
			assert_false(k.intersects(r), "pool in a keepout")
	for m: Dictionary in f["mud"]:
		for k in keep:
			assert_false(k.intersects(m["rect"]), "mud in a keepout")
	for d: Dictionary in f["dead"]:
		for k in keep:
			assert_false(k.has_point(d["pos"]), "dead tree in a keepout")
	for b: Dictionary in f["bones"]:
		for k in keep:
			assert_false(k.has_point(b["pos"]), "bone in a keepout")


func test_boardwalk_has_missing_planks_and_reeds() -> void:
	var region := {"id": "m", "map": {"ground_style": "bog", "water": "murky", "landmarks": []}}
	var kinds := {}
	for t in Scenery.path_tiles(region, Rect2(0, 470, 1600, 60)):
		kinds[str(t["kind"]) + ":" + str(t["flag"])] = true
	assert_true(kinds.has("plank:missing"), "missing plank")
	assert_true(kinds.has("plank:dark"), "dark plank")
	assert_true(kinds.has("tuft:"), "reed tufts")
