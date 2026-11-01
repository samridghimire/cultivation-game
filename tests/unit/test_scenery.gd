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


func test_abodes_are_kept_clear() -> void:
	var region := _region()
	region["abodes"] = [{"id": "a", "pos": [600, 150], "size": [120, 90]}]
	var abode := Rect2(Vector2(600, 150) - Vector2(60, 45), Vector2(120, 90)).grow(Scenery.CLEARANCE)
	assert_true(Scenery.blocked_rects(region).has(abode))
	for d in Scenery.place(region, seeded_rng(5)):
		assert_false(abode.has_point(d["pos"]), "%s inside the abode" % d["kind"])


func test_validate_flags_bad_landmarks() -> void:
	var d := GameData.new()
	d.regions = {"bad": {"id": "bad", "map": {"landmarks": [{"kind": "castle", "pos": [1, 2], "size": [3, 4]}, {"kind": "house", "pos": ["a", 2], "size": [3, 4]}, {"kind": "house", "pos": [1, 2], "size": [0, 4]}]}}}
	assert_eq(Scenery.validate(d).size(), 3)


func test_decor_avoids_landmarks() -> void:
	var region := _region()
	region["map"]["landmarks"] = [{"kind": "pond", "pos": [600, 100], "size": [200, 120]}]
	var rect := Scenery.landmark_rects(region)[0]
	for d in Scenery.place(region, seeded_rng(3)):
		assert_false(rect.has_point(d["pos"]), "%s inside the pond" % d["kind"])


func test_solid_landmarks_keep_places_spots_and_spawn_reachable() -> void:
	for region: Dictionary in data().regions.values():
		var solid := Scenery.landmark_rects(region, true)
		var points: Array[Vector2] = []
		for s: Array in region.get("npc_spots", []):
			points.append(Vector2(float(s[0]), float(s[1])))
		for p: Dictionary in region.get("places", []):
			points.append(Vector2(float(p["pos"][0]), float(p["pos"][1])))
		if region.has("spawn"):
			points.append(Vector2(float(region["spawn"][0]), float(region["spawn"][1])))
		for r in solid:
			for pt in points:
				assert_false(r.grow(16.0).has_point(pt), "%s: solid landmark covers %s" % [region["id"], pt])
			for path: Array in region["map"].get("paths", []):
				assert_false(r.intersects(Rect2(float(path[0]), float(path[1]), float(path[2]), float(path[3]))), "%s: landmark on a path" % region["id"])


func test_every_region_has_landmarks_inside_the_map() -> void:
	for region: Dictionary in data().regions.values():
		var size: Array = region["map"]["size"]
		var map_rect := Rect2(0, 0, float(size[0]), float(size[1]))
		var rects := Scenery.landmark_rects(region)
		assert_gt(rects.size(), 5, "%s needs landmarks" % region["id"])
		assert_true(rects.size() < 13, "%s has too many landmarks" % region["id"])
		for r in rects:
			assert_true(map_rect.encloses(r), "%s: landmark %s leaves the map" % [region["id"], r])


func test_solid_landmarks_clear_place_rects_homes_and_abodes_everywhere() -> void:
	for region: Dictionary in data().regions.values():
		var keep: Array[Rect2] = []
		for p: Dictionary in region.get("places", []) + region.get("abodes", []):
			var sz: Array = p.get("size", [64, 64])
			keep.append(Rect2(Vector2(float(p["pos"][0]), float(p["pos"][1])) - Vector2(float(sz[0]), float(sz[1])) / 2.0, Vector2(float(sz[0]), float(sz[1]))))
		if region.has("family_home"):
			var home: Dictionary = region["family_home"]
			var hs := Vector2(float(home["size"][0]), float(home["size"][1]))
			keep.append(Rect2(Vector2(float(home["pos"][0]), float(home["pos"][1])) - hs / 2.0, hs))
		for r in Scenery.landmark_rects(region, true):
			for k in keep:
				assert_false(r.intersects(k), "%s: solid landmark %s overlaps %s" % [region["id"], r, k])


func test_new_landmark_kinds_validate_and_are_solid_where_expected() -> void:
	for kind in ["wall", "cliff", "stream", "lantern", "pine", "stall"]:
		assert_true(Scenery.LANDMARK_KINDS.has(kind), kind)
	assert_false(Scenery.SOLID_LANDMARKS.has("stream"))
	assert_true(Scenery.SOLID_LANDMARKS.has("wall"))
	var d := GameData.new()
	d.regions = {"bad": {"id": "bad", "map": {"landmarks": [{"kind": "pond", "pos": [1, 2], "size": [3, 4], "color": "nope"}, {"kind": "stream", "pos": [1, 2], "size": [3, 4], "color": "3b4a2e"}]}}}
	assert_eq(Scenery.validate(d).size(), 1)


func _kinds_region(kinds: Variant, extra: Dictionary = {}) -> Dictionary:
	var r := _region()
	r["map"]["decor"] = {"trees": 30, "rocks": 0, "grass": 0, "flowers": 0}
	if kinds != null:
		r["map"]["decor"]["tree_kinds"] = kinds
	r["map"]["decor"].merge(extra, true)
	return r


func _trees(placed: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in placed:
		if d["kind"] == "tree":
			out.append(d)
	return out


func test_tree_kinds_pick_and_default() -> void:
	for d in _trees(Scenery.place(_kinds_region({"pine": 1}), seeded_rng())):
		assert_eq(d["tree_kind"], "pine")
	var plain := _trees(Scenery.place(_kinds_region(null), seeded_rng()))
	assert_true(plain.size() > 0)
	for d in plain:
		assert_eq(d["tree_kind"], "round")


func test_tree_kinds_deterministic() -> void:
	var a := _trees(Scenery.place(_kinds_region({"pine": 2, "dead": 1}), seeded_rng()))
	var b := _trees(Scenery.place(_kinds_region({"pine": 2, "dead": 1}), seeded_rng()))
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i]["tree_kind"], b[i]["tree_kind"])
		assert_eq(a[i]["pos"], b[i]["pos"])


func test_tree_look_by_kind() -> void:
	var base := Color("2e5a2a")
	assert_eq(int(Scenery.tree_look("Spring", 5, base, "pine")["blossoms"]), 0)
	assert_true(int(Scenery.tree_look("Spring", 5, base, "round")["blossoms"]) > 0)
	assert_eq(int(Scenery.tree_look("Spring", 5, base, "round", false)["blossoms"]), 0)
	assert_true(Scenery.tree_look("Summer", 5, base, "dead")["bare"])
	assert_false(Scenery.tree_look("Winter", 5, base, "pine")["bare"])
	assert_true(Scenery.tree_look("Winter", 5, base, "willow")["bare"])


func test_clusters_make_clumps_and_respect_blocked() -> void:
	var region := _kinds_region({"round": 1}, {"trees": 60, "clusters": 3})
	var trees := _trees(Scenery.place(region, seeded_rng()))
	var blocked := Scenery.blocked_rects(region)
	for d in trees:
		for r in blocked:
			assert_false(r.has_point(d["pos"]), "tree inside blocked rect")
	var dense := 0
	for d in trees:
		var near := 0
		for e in trees:
			if d["pos"].distance_to(e["pos"]) <= 60.0:
				near += 1
		if near >= 4:
			dense += 1
	assert_true(dense >= 12, "three clumps of 4+ trees (got %d dense trees)" % dense)


func test_tree_kind_validation() -> void:
	var data := GameData.new()
	data.regions = {
		"a": {"id": "a", "map": {"decor": {"tree_kinds": {"oak": 1}}}},
		"b": {"id": "b", "map": {"decor": {"tree_kinds": {"pine": 0}}}},
		"c": {"id": "c", "map": {"decor": {"clusters": 20}}},
		"d": {"id": "d", "map": {"decor": {"tree_kinds": {"pine": 1}, "blossoms": false, "clusters": 3}}},
	}
	var errors := Scenery.validate(data)
	assert_eq(errors.size(), 3, str(errors))
func test_winter_tint_brighter_than_autumn() -> void:
	var w := Calendar.season_tint("Winter")
	var a := Calendar.season_tint("Autumn")
	assert_true(w.get_luminance() > a.get_luminance())


func test_frozen_pond_differs_from_summer() -> void:
	var size := Vector2(160, 100)
	var summer := PixelLandmark.texture("pond", size)
	var ice := PixelLandmark.texture("pond", size, Color("3f7fa8"), true)
	assert_true(summer.get_image().get_data() != ice.get_image().get_data())
	assert_eq(summer.get_size(), ice.get_size())


func test_winter_ground_is_bright_snow() -> void:
	var tex := GroundTiles.ground_texture(Color("4d6b3c"), "qingshi_village", Vector2i(40, 40), false, "Winter")
	var img := tex.get_image()
	var sum := 0.0
	for y in img.get_height():
		for x in img.get_width():
			sum += img.get_pixel(x, y).get_luminance()
	var mean := sum / float(img.get_width() * img.get_height())
	assert_true(mean * Calendar.season_tint("Winter").get_luminance() > 0.6, "mean %f" % mean)


func test_footprints_cap_at_twelve() -> void:
	var prints: Array = []
	for i in 30:
		prints = Scenery.add_footprint(prints, Vector2(i, 0))
	assert_eq(prints.size(), 12)
	assert_eq(prints[11], Vector2(29, 0))


func test_marsh_spawns_dead_trees() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var dead := 0
	for d in _trees(Scenery.place(gs.data.regions["withered_bone_marsh"], seeded_rng())):
		if d["tree_kind"] == "dead":
			dead += 1
	assert_true(dead >= 1, "marsh has dead trees")


## GFX-045: the jetty is a valid landmark kind with a texture; ponds have a darker rim than their centre.
func test_jetty_landmark_and_pond_rim() -> void:
	assert_true(Scenery.LANDMARK_KINDS.has("jetty"))
	assert_true(PixelLandmark.supports("jetty"))
	var jt := PixelLandmark.texture("jetty", Vector2(88, 28))
	assert_true(jt.get_width() > 0 and jt.get_height() > 0)
	var size := Vector2(200, 120)
	var img := PixelLandmark.texture("pond", size).get_image()
	var rim := img.get_pixel(img.get_width() / 2, 1)
	var centre := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	assert_true(rim.get_luminance() < centre.get_luminance(), "rim darker than the water")


## GFX-046: a jetty near a pond is laid from the pond's rim and overlaps the water; the fishing place stays on it.
func test_jetty_meets_the_pond() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var checked := 0
	for region: Dictionary in gs.data.regions.values():
		var ponds: Array[Rect2] = []
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if lm["kind"] == "pond":
				ponds.append(Rect2(Vector2(lm["pos"][0], lm["pos"][1]) - Vector2(lm["size"][0], lm["size"][1]) / 2.0, Vector2(lm["size"][0], lm["size"][1])))
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if lm["kind"] != "jetty":
				continue
			var lay := Scenery.jetty_layout(region, lm)
			if not bool(lay["on_water"]):
				continue
			checked += 1
			var rect: Rect2 = lay["rect"]
			var overlap := false
			for p in ponds:
				var i := p.intersection(rect)
				if i.size.x >= 4.0 and i.size.y >= 4.0:
					overlap = true
			assert_true(overlap, "%s: jetty overlaps its pond by 4+ px" % region["id"])
			assert_true(rect.grow(10.0).has_point(Vector2(lm["pos"][0], lm["pos"][1])), "%s: the place stays at the jetty" % region["id"])
	assert_true(checked >= 3, "several jetties sit on ponds")
	# No pond near: the landmark keeps its own rect.
	var lone := {"map": {"landmarks": [{"kind": "jetty", "pos": [100, 100], "size": [88, 28]}]}}
	var lay2 := Scenery.jetty_layout(lone, lone["map"]["landmarks"][0])
	assert_false(bool(lay2["on_water"]))
	assert_eq(lay2["rect"], Rect2(56, 86, 88, 28))


## GFX-046: a landmark tree_kind must be a known kind and only goes on a pine.
func test_landmark_tree_kind_validation() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	assert_eq(Scenery.validate(gs.data).size(), 0)
	var saved: Array = gs.data.regions["withered_bone_marsh"]["map"]["landmarks"]
	var bad := saved.duplicate(true)
	for lm: Dictionary in bad:
		if lm["kind"] == "pine":
			lm["tree_kind"] = "oak"
			break
	gs.data.regions["withered_bone_marsh"]["map"]["landmarks"] = bad
	var errors := Scenery.validate(gs.data)
	gs.data.regions["withered_bone_marsh"]["map"]["landmarks"] = saved
	assert_eq(errors.size(), 1)
	var on_pond := saved.duplicate(true)
	for lm: Dictionary in on_pond:
		if lm["kind"] == "pond":
			lm["tree_kind"] = "dead"
			break
	gs.data.regions["withered_bone_marsh"]["map"]["landmarks"] = on_pond
	var errors2 := Scenery.validate(gs.data)
	gs.data.regions["withered_bone_marsh"]["map"]["landmarks"] = saved
	assert_eq(errors2.size(), 1)


## GFX-046: the marsh's arrival view (spawn +- 640x400) holds at least 3 dead trees, decor or landmark.
func test_marsh_arrival_view_has_dead_trees() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var region: Dictionary = gs.data.regions["withered_bone_marsh"]
	var sp := Vector2(float(region["spawn"][0]), float(region["spawn"][1]))
	var view := Rect2(sp - Vector2(640, 400), Vector2(1280, 800))
	var dead := 0
	for d in Scenery.place(region, seeded_rng()):
		if d["kind"] == "tree" and d["tree_kind"] == "dead" and view.has_point(d["pos"]):
			dead += 1
	for lm: Dictionary in region["map"]["landmarks"]:
		if lm["kind"] == "pine" and lm.get("tree_kind", "") == "dead" and view.has_point(Vector2(lm["pos"][0], lm["pos"][1])):
			dead += 1
	assert_true(dead >= 3, "dead trees in the marsh arrival view: %d" % dead)
