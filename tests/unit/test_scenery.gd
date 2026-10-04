extends TestCase
## VIS-002: region scenery placement and map.decor validation.


func _region() -> Dictionary:
	return {
		"id": "test",
		"map": {"size": [800, 600], "paths": [[0, 280, 800, 40]], "decor": {"trees": 20, "rocks": 5, "grass": 0, "flowers": 3}},
		"places": [{"type": "meditation", "pos": [200, 150], "size": [100, 80]}],
		"npc_spots": [[600, 450]],
		"spawn": [400, 500],
	}


func test_counts_come_from_decor_with_defaults() -> void:
	var cfg := Scenery.settings({"map": {"decor": {"trees": 3}}})
	assert_eq(cfg["trees"], 3)
	assert_eq(cfg["rocks"], Scenery.DEFAULTS["rocks"])
	var placed := Scenery.place(_region(), seeded_rng())
	var counts := {}
	for d in placed:
		counts[d["kind"]] = int(counts.get(d["kind"], 0)) + 1
	assert_false(counts.has("grass"), "grass: 0 places none")
	assert_true(int(counts.get("tree", 0)) > 10, "most trees find a spot")
	assert_true(int(counts.get("tree", 0)) <= 20)


func test_decor_avoids_paths_places_spots_and_spawn() -> void:
	var region := _region()
	var blocked := Scenery.blocked_rects(region)
	for d in Scenery.place(region, seeded_rng(7)):
		var pos: Vector2 = d["pos"]
		for r in blocked:
			assert_false(r.has_point(pos), "%s on a blocked rect" % d["kind"])
		assert_gt(pos.distance_to(Vector2(600, 450)), Scenery.SPOT_RADIUS)
		assert_gt(pos.distance_to(Vector2(400, 500)), Scenery.SPOT_RADIUS)
		assert_true(Rect2(0, 0, 800, 600).has_point(pos))


func test_same_seed_same_scenery() -> void:
	var a := Scenery.place(_region(), seeded_rng(3))
	var b := Scenery.place(_region(), seeded_rng(3))
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i]["pos"], b[i]["pos"])


func test_every_region_has_scenery_and_valid_decor() -> void:
	assert_eq(Scenery.validate(data()).size(), 0)
	for region: Dictionary in data().regions.values():
		assert_gt(Scenery.place(region, seeded_rng()).size(), 0, region["id"])


func test_validate_flags_bad_decor() -> void:
	var d := GameData.new()
	d.regions = {"bad": {"id": "bad", "map": {"decor": {"trees": -1, "rock_color": "nope", "dragons": 2}}}}
	assert_eq(Scenery.validate(d).size(), 3)
