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
		var cap := 20 if region["id"] == "fallen_star_market" else (16 if region["id"] == "azure_peak" else 13)  # GFX-054: a lantern-lined main street; GFX-079: steps + clouds
		assert_true(rects.size() < cap, "%s has too many landmarks" % region["id"])
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
			assert_true(rect.grow(80.0).has_point(Vector2(lm["pos"][0], lm["pos"][1])), "%s: the place stays at the jetty's foot" % region["id"])
	assert_true(checked >= 3, "several jetties sit on ponds")
	# No pond near: the landmark keeps its own rect.
	var lone := {"map": {"landmarks": [{"kind": "jetty", "pos": [100, 100], "size": [88, 28]}]}}
	var lay2 := Scenery.jetty_layout(lone, lone["map"]["landmarks"][0])
	assert_false(bool(lay2["on_water"]))
	assert_eq(lay2["rect"], Rect2(56, 86, 88, 28))


## RV-019: every jetty within 200 px of a pond lays out on the water (no bare posts on grass).
func test_near_pond_jetties_are_on_water() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var checked := 0
	for region: Dictionary in gs.data.regions.values():
		var lms: Array = region.get("map", {}).get("landmarks", [])
		for lm: Dictionary in lms:
			if lm["kind"] != "jetty":
				continue
			var pos := Vector2(lm["pos"][0], lm["pos"][1])
			for other: Dictionary in lms:
				if other["kind"] == "pond" and pos.distance_to(Vector2(other["pos"][0], other["pos"][1])) <= 200.0:
					checked += 1
					assert_true(bool(Scenery.jetty_layout(region, lm)["on_water"]), "%s: jetty near a pond is on_water" % region["id"])
					break
	assert_true(checked >= 3, "several jetties checked")


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


## GFX-049: a jetty stops short of a path below the pond rim, and no real jetty crosses any path.
func test_jetty_never_crosses_a_path() -> void:
	var region := {"map": {
		"landmarks": [
			{"kind": "pond", "pos": [200, 100], "size": [120, 80]},
			{"kind": "jetty", "pos": [200, 160], "size": [20, 60]},
		],
		"paths": [[0, 170, 400, 30]],
	}}
	var lm: Dictionary = region["map"]["landmarks"][1]
	var r: Rect2 = Scenery.jetty_layout(region, lm)["rect"]
	assert_true(r.end.y <= 170.0 - Scenery.JETTY_PATH_GAP + 0.01, "jetty ends above the path (end %f)" % r.end.y)
	assert_true(r.size.y >= Scenery.JETTY_MIN_LEN)
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	for region2: Dictionary in gs.data.regions.values():
		for lm2: Dictionary in region2.get("map", {}).get("landmarks", []):
			if lm2["kind"] != "jetty":
				continue
			var jr: Rect2 = Scenery.jetty_layout(region2, lm2)["rect"]
			for pr: Array in region2.get("map", {}).get("paths", []):
				assert_false(Rect2(pr[0], pr[1], pr[2], pr[3]).intersects(jr), "%s: jetty %s crosses a path" % [region2["id"], str(lm2["pos"])])


## GFX-053: rock groups of several sizes, validated 0..12.
func test_rock_clusters_group_rocks_in_sizes_and_validate() -> void:
	var region := _region()
	region["map"]["decor"] = {"trees": 0, "rocks": 40, "rock_clusters": 4, "grass": 0, "flowers": 0}
	var rocks: Array[Dictionary] = []
	for d in Scenery.place(region, seeded_rng(3)):
		if d["kind"] == "rock":
			rocks.append(d)
	assert_eq(rocks.size(), 40)
	var scales := {}
	for d in rocks:
		scales[snappedf(float(d["scale"]), 0.01)] = true
	assert_true(scales.size() >= 3, "rocks come in several sizes")
	var bad := GameData.new()
	bad.regions = {"bad": {"id": "bad", "map": {"decor": {"rock_clusters": 13}}}, "ok": {"id": "ok", "map": {"decor": {"rock_clusters": 6}}}}
	assert_eq(Scenery.validate(bad).size(), 1)


## GFX-053: no decor within 12 px of a path or 20 px of a place / npc spot, and no pine landmark on a road.
func test_no_decor_or_pine_on_roads_or_spots_in_any_region() -> void:
	for region: Dictionary in data().regions.values():
		var paths: Array[Rect2] = []
		for r in region.get("map", {}).get("paths", []):
			paths.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if lm["kind"] == "pine":
				var rect := Rect2(Vector2(float(lm["pos"][0]), float(lm["pos"][1])) - Vector2(float(lm["size"][0]), float(lm["size"][1])) / 2.0, Vector2(float(lm["size"][0]), float(lm["size"][1])))
				for p in paths:
					assert_false(p.intersects(rect), "%s: pine landmark at %s on a path" % [region["id"], lm["pos"]])
		var spots: Array = region.get("npc_spots", [])
		for d in Scenery.place(region, seeded_rng(11)):
			var pos: Vector2 = d["pos"]
			for p in paths:
				assert_false(p.grow(12.0).has_point(pos), "%s: %s within 12 px of a path" % [region["id"], d["kind"]])
			for s in spots:
				assert_gt(pos.distance_to(Vector2(float(s[0]), float(s[1]))), 20.0, "%s: %s on an npc spot" % [region["id"], d["kind"]])


## GFX-079: steps and clouds are valid, never solid; scree_density is validated and thins the speckle.
func test_steps_and_clouds_are_walkable_landmarks() -> void:
	for kind in ["steps", "clouds"]:
		assert_true(Scenery.LANDMARK_KINDS.has(kind), kind)
		assert_false(Scenery.SOLID_LANDMARKS.has(kind), kind)
	var d := GameData.new()
	d.regions = {"ok": {"id": "ok", "map": {"scree_density": 0.4, "landmarks": [{"kind": "steps", "pos": [1, 2], "size": [3, 4]}]}},
		"bad": {"id": "bad", "map": {"scree_density": 2.0}}}
	assert_eq(Scenery.validate(d).size(), 1)


func test_azure_peak_has_steps_clouds_and_more_trees() -> void:
	var data := GameData.load_from_dir()
	var map: Dictionary = data.regions["azure_peak"]["map"]
	var kinds: Array = map["landmarks"].map(func(l: Dictionary) -> String: return l["kind"])
	assert_true(kinds.has("steps") and kinds.has("clouds"))
	assert_true(int(map["decor"]["trees"]) >= 25)
	assert_true(float(map["scree_density"]) <= 0.5)


func test_scree_density_thins_the_speckle() -> void:
	var base := Color("5f7a74")
	var full := GroundTiles.ground_texture(base, "dens_t", Vector2i(160, 160), false, "", "scree", [], 1.0).get_image()
	var thin := GroundTiles.ground_texture(base, "dens_t", Vector2i(160, 160), false, "", "scree", [], 0.4).get_image()
	var diff := 0
	var diff_thin := 0
	for y in 160:
		for x in 160:
			if full.get_pixel(x, y) != base:
				diff += 1
			if thin.get_pixel(x, y) != base:
				diff_thin += 1
	assert_true(diff_thin < diff)


func test_ground_variants_have_matching_luminance() -> void:
	var base := Color("7a8c74")
	var lums: Array[float] = []
	for v in 4:
		var img := GroundTiles.make_variant(base, "azure_peak", v, true).get_image()
		var total := 0.0
		for y in img.get_height():
			for x in img.get_width():
				total += img.get_pixel(x, y).get_luminance()
		lums.append(total / float(img.get_width() * img.get_height()))
	for a in lums:
		for b in lums:
			assert_true(absf(a - b) <= base.get_luminance() * 0.03, "variants differ by more than 3%% (%s vs %s)" % [a, b])


func test_no_decor_near_gates_or_travel_places() -> void:
	var gd := GameData.load_from_dir()
	for rid: String in gd.regions:
		var region: Dictionary = gd.regions[rid]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(rid)
		var decor := SectCourt.filter_decor(region, Scenery.place(region, rng))
		var rects: Array[Rect2] = []
		var g := SectCourt.gate(region)
		if not g.is_empty():
			rects.append(SectCourt.gate_rect(g))
		for p: Dictionary in region.get("places", []):
			if String(p.get("type", "")) == "travel":
				var sz: Array = p.get("size", [64, 64])
				var size := Vector2(float(sz[0]), float(sz[1]))
				rects.append(Rect2(Vector2(float(p["pos"][0]), float(p["pos"][1])) - size / 2.0, size))
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if String(lm.get("kind", "")) == "pine":  # landmark trees are data, so check them too
				decor.append({"kind": "pine landmark", "pos": Vector2(float(lm["pos"][0]), float(lm["pos"][1]))})
		for d in decor:
			for r in rects:
				assert_true(r.grow(SectCourt.DECOR_KEEP - 1.0).has_point(d["pos"]) == false, "%s: %s at %s within 40 px of a gate or travel place" % [rid, d["kind"], d["pos"]])


func test_edge_belt_validation() -> void:
	var d := GameData.new()
	d.regions = {"bad": {"id": "bad", "map": {"decor": {"edge_belt": 4}}}, "ok": {"id": "ok", "map": {"decor": {"edge_belt": 3}}}}
	assert_eq(Scenery.validate(d).size(), 1)


func test_edge_belt_hugs_edges_and_leaves_path_gaps() -> void:
	var region := _region()
	region["map"]["decor"] = {"trees": 0, "rocks": 0, "grass": 0, "flowers": 0, "edge_belt": 2}
	var blocked := Scenery.blocked_rects(region)
	var near_edge := 0
	for d in Scenery.place(region, seeded_rng(2)):
		var pos: Vector2 = d["pos"]
		for r in blocked:
			assert_false(r.has_point(pos), "belt tree on a blocked rect")
		if pos.x < 70.0 or pos.y < 70.0 or pos.x > 730.0 or pos.y > 530.0:
			near_edge += 1
	assert_gt(near_edge, 40, "a dense belt")


func test_misty_forest_is_denser_than_qingshi_and_clear_of_places() -> void:
	var misty: Dictionary = data().regions["misty_forest"]
	var trees := 0
	var blocked := Scenery.blocked_rects(misty)
	for d in Scenery.place(misty, seeded_rng(1)):
		if d["kind"] != "tree":
			continue
		trees += 1
		for r in blocked:
			assert_false(r.has_point(d["pos"]), "tree on a path or place")
	var qingshi := 0
	for d in Scenery.place(data().regions["qingshi_village"], seeded_rng(1)):
		if d["kind"] == "tree":
			qingshi += 1
	assert_gt(trees, qingshi * 3)


func test_field_look_follows_the_season() -> void:
	assert_eq(Scenery.field_look("Spring", 5)["style"], "sprout")
	assert_eq(Scenery.field_look("Summer", 5)["style"], "tall")
	assert_eq(Scenery.field_look("Autumn", 5)["style"], "golden")
	assert_true(Scenery.field_look("Autumn", 5)["sheaves"])
	var w := Scenery.field_look("Winter", 5)
	assert_eq(w["style"], "bare")
	assert_true(w["snow"])
	assert_false(Scenery.field_look("Winter", 5, true)["snow"])
	assert_true(Scenery.field_look("Summer", 1)["vertical"] and not Scenery.field_look("Summer", 0)["vertical"])


## WU-500: at every project stage every jetty post stands in the water or within 6 px of the pond's rim.
func test_jetty_posts_stand_in_the_water() -> void:
	var region: Dictionary = (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data.regions["qingshi_village"]
	var ponds: Array[Rect2] = []
	for lm: Dictionary in region["map"]["landmarks"]:
		if lm["kind"] == "pond":
			var sz := Vector2(lm["size"][0], lm["size"][1])
			ponds.append(Rect2(Vector2(lm["pos"][0], lm["pos"][1]) - sz / 2.0, sz))
	for lm: Dictionary in region["map"]["landmarks"]:
		if lm["kind"] != "jetty":
			continue
		for stage in 4:
			var posts := Scenery.jetty_posts(region, lm, stage)
			assert_true(posts.size() >= 2, "stage %d keeps a pair of posts" % stage)
			for post in posts:
				var ok := false
				for pond in ponds:
					if pond.grow(6.0).intersects(post):
						ok = true
				assert_true(ok, "stage %d post %s stands on dry grass" % [stage, post])


## WU-502: the Herb Slope's terrace look grows by stage: edging, then two rows, then three rows with herbs and a channel.
func test_terrace_look_by_stage() -> void:
	var rows: Array[int] = []
	for st in range(-1, 5):
		rows.append(int(Scenery.terrace_look(st)["rows"]))
	assert_eq(rows, [0, 0, 0, 2, 3, 3])
	assert_false(bool(Scenery.terrace_look(0)["edging"]))
	assert_true(bool(Scenery.terrace_look(1)["edging"]))
	assert_false(bool(Scenery.terrace_look(2)["channel"]))
	assert_true(bool(Scenery.terrace_look(3)["channel"]) and bool(Scenery.terrace_look(3)["herbs"]))


## WU-502: the Village Herb Slope place carries the "terraces" tag the world and its label key on.
func test_herb_slope_has_terraces_tag() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var found := false
	for p: Dictionary in gs.data.regions["qingshi_village"]["places"]:
		if String(p.get("display_name", "")) == "Village Herb Slope":
			found = (p.get("tags", []) as Array).has("terraces")
	assert_true(found)


## GFX-114: winter trees get a flat foot shadow, summer leafy trees keep the round one.
func test_tree_shadow_by_season() -> void:
	for bare in [true, false]:
		assert_eq(Scenery.tree_shadow("Winter", bare), "foot")
	assert_eq(Scenery.tree_shadow("Summer", false), "round")
	assert_eq(Scenery.tree_shadow("Summer", true), "foot")


## GFX-114: every jetty on a pond has its ice hole inside the pond rect.
func test_ice_hole_inside_pond() -> void:
	var checked := 0
	for region: Dictionary in data().regions.values():
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if lm.get("kind", "") != "jetty":
				continue
			var pt := Scenery.ice_hole_point(region, lm)
			if pt == Vector2.INF:
				continue
			var inside := false
			for other: Dictionary in region["map"]["landmarks"]:
				if other.get("kind", "") == "pond":
					var c := Vector2(float(other["pos"][0]), float(other["pos"][1]))
					if Rect2(c - Vector2(float(other["size"][0]), float(other["size"][1])) / 2.0, Vector2(float(other["size"][0]), float(other["size"][1]))).has_point(pt):
						inside = true
			assert_true(inside, "ice hole of %s jetty lies in a pond" % region["id"])
			checked += 1
	assert_true(checked >= 4, "several regions have a jetty on a pond")


## GFX-116: a jetty runs from its shore point (within 6 px of the pond rim) out over the water; its water end lies inside the pond ellipse.
func test_jetty_runs_out_over_water() -> void:
	var checked := 0
	for region: Dictionary in data().regions.values():
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if lm.get("kind", "") != "jetty":
				continue
			var lay := Scenery.jetty_layout(region, lm)
			if not bool(lay["on_water"]):
				continue
			var r: Rect2 = lay["rect"]
			var vertical := bool(lay["vertical"])
			var toward := int(lay["toward_water"])
			var water_end: Vector2
			var shore_end: Vector2
			var c := r.get_center()
			if vertical:
				water_end = Vector2(c.x, r.position.y if toward < 0 else r.end.y)
				shore_end = Vector2(c.x, r.end.y if toward < 0 else r.position.y)
			else:
				water_end = Vector2(r.position.x if toward < 0 else r.end.x, c.y)
				shore_end = Vector2(r.end.x if toward < 0 else r.position.x, c.y)
			var best_in := false
			var best_rim := INF
			for other: Dictionary in region["map"]["landmarks"]:
				if other.get("kind", "") != "pond":
					continue
				var pc := Vector2(float(other["pos"][0]), float(other["pos"][1]))
				var half := Vector2(float(other["size"][0]), float(other["size"][1])) / 2.0
				if ((water_end - pc) / half).length() < 1.0:
					best_in = true
				var q := ((shore_end - pc) / half).length()
				best_rim = minf(best_rim, absf(q - 1.0) * minf(half.x, half.y))
			assert_true(best_in, "%s: jetty water end is inside its pond" % region["id"])
			assert_true(best_rim <= 6.0, "%s: jetty shore end within 6 px of the rim (%.1f)" % [region["id"], best_rim])
			checked += 1
	assert_true(checked >= 4, "several jetties checked")
