extends TestCase
## GFX-145: irregular rocks, scree pebble clusters and the label margin on a mountain ridge.


func test_rock_polygon_bounds_and_determinism() -> void:
	for sd in 20:
		var c := Vector2(100, 50)
		var poly := Scenery.rock_polygon(c, 12.0, sd)
		assert_true(poly.size() >= 6 and poly.size() <= 9, "6-9 points")
		for q in poly:
			var d := q.distance_to(c)
			assert_true(d >= 12.0 * 0.75 - 0.001 and d <= 12.0 + 0.001, "radius within 0.75-1.0")
		assert_eq(poly, Scenery.rock_polygon(c, 12.0, sd), "same seed same rock")


func _ridge() -> Dictionary:
	return {"id": "ridge_t", "map": {"size": [1600, 1000], "ground_style": "scree"}}


func test_scree_clusters_clear_of_keepouts() -> void:
	var keep: Array[Rect2] = [Rect2(0, 440, 1600, 120), Rect2(600, 100, 200, 200)]
	var a := Scenery.scree_clusters(_ridge(), keep)
	assert_true(a.size() > 10, "some clusters")
	for c: Dictionary in a:
		for k in keep:
			assert_false(k.has_point(c["center"]), "cluster outside keepouts")
	assert_eq(a, Scenery.scree_clusters(_ridge(), keep), "deterministic")
	assert_eq(Scenery.scree_clusters({"id": "x", "map": {"size": [800, 600]}}, keep).size(), 0, "only scree maps")


func test_scree_bands_count() -> void:
	var b := Scenery.scree_bands(_ridge())
	assert_true(b.size() >= 2 and b.size() <= 4)


func test_person_label_keeps_margin_from_place_label() -> void:
	var place := Rect2(100, 100, 120, 18)
	var label := Rect2(150, 118.5, 60, 16)  # touching-ish: within 2 px of the place label
	var off := LabelLayout.person_offset(label, 140.0, [place])
	var moved := Rect2(label.position + off, label.size)
	assert_false(moved.intersects(place.grow(2.0)), "2 px margin")


## GFX-150: ledge silhouettes vary, wisps are soft blobs, terrace bands are curved, patches avoid keepouts.
func test_ledge_steps_vary_at_least_forty_percent() -> void:
	for sd in 40:
		var st := Scenery.ledge_steps(sd)
		var hs: Array = st["heights"]
		assert_true(hs.size() >= 3 and hs.size() <= 6, "3-6 steps")
		assert_true(float(hs.max()) - float(hs.min()) >= 0.4 - 0.001, "varies >= 40%")
		assert_true(float(hs.max()) <= 1.0 and float(hs.min()) >= 0.4 - 0.001)
		assert_eq(st, Scenery.ledge_steps(sd), "deterministic")


func test_wisp_puffs_never_thin_bars() -> void:
	for sd in 30:
		var puffs := Scenery.wisp_puffs(80.0 + float(sd), 26.0, sd)
		assert_true(puffs.size() >= 3 and puffs.size() <= 5)
		for p in puffs:
			assert_true(p.size.y >= 10.0 and p.size.x >= 16.0, "ellipse at least 10 px tall")


func test_terrace_band_edges_wobble_gently() -> void:
	var bands := Scenery.terrace_bands(Rect2(100, 200, 130, 100), 5)
	for poly in bands:
		var half := poly.size() / 2
		var ys: Array[float] = []
		for i in half:
			ys.append(poly[i].y)
		var span: float = ys.max() - ys.min()
		assert_true(span >= 2.0 and span <= 4.0, "upper edge wobbles 2-4 px, near straight")


func test_ridge_patches_clear_of_keepouts() -> void:
	var keep: Array[Rect2] = [Rect2(0, 440, 1600, 120), Rect2(600, 100, 200, 200)]
	var a := Scenery.ridge_patches(_ridge(), keep)
	assert_true(a.size() >= 4 and a.size() <= 8, "4-8 patches, got %d" % a.size())
	for pt: Dictionary in a:
		var c: Vector2 = pt["center"]
		var box := Rect2(c - Vector2(float(pt["rx"]), float(pt["ry"])), Vector2(float(pt["rx"]), float(pt["ry"])) * 2.0)
		for k in keep:
			assert_false(k.intersects(box), "patch clear of keepouts")
	assert_eq(a, Scenery.ridge_patches(_ridge(), keep))


## GFX-153: seasonal drifts, crag silhouettes and scree stone contrast.
func test_drift_look_per_season() -> void:
	var spring_shown := 0
	var autumn_shown := 0
	for sd in 60:
		assert_false(Scenery.drift_look("Summer", sd)["show"], "summer: no snow")
		var w := Scenery.drift_look("Winter", sd)
		assert_true(w["show"] and w["scale"] == Vector2.ONE and w["lumps"] == 1, "winter full drift")
		for season in ["Spring", "Autumn"]:
			var d := Scenery.drift_look(season, sd)
			assert_eq(d, Scenery.drift_look(season, sd), "deterministic")
			assert_true(d["scale"].x < 0.5 and d["lumps"] >= 2 and d["lumps"] <= 3, "smaller, 2-3 lumps")
			assert_true((d["color"] as Color) != Color("e8eef4"), "not snow white")
			if d["show"]:
				if season == "Spring":
					spring_shown += 1
				else:
					autumn_shown += 1
	assert_true(spring_shown > 15 and spring_shown < 45, "spring hides about half")
	assert_true(autumn_shown > 5 and autumn_shown < 35, "autumn hides about two thirds")


func test_drift_lumps_have_gaps() -> void:
	var r := Rect2(100, 100, 60, 12)
	for sd in 20:
		var l := Scenery.drift_lumps(r, 3, sd)
		assert_eq(l.size(), 3, "3 lumps")
		for i in 2:
			var gap := l[i + 1].position.x - l[i].end.x
			assert_true(gap >= 3.99 and gap <= 10.01, "4-10 px gaps")


func test_crag_outline_tapers() -> void:
	var r := Rect2(0, 0, 100, 50)
	for sd in 20:
		var o := Scenery.crag_outline(r, sd)
		assert_true(o.size() >= 8, "uneven top has several points")
		assert_eq(o, Scenery.crag_outline(r, sd), "deterministic")
		assert_true(o[1].x >= 6.0 - 0.001 and o[o.size() - 2].x <= 94.001, "sides slope in")
		var ys := {}
		for i in range(2, o.size() - 2):
			ys[snappedf(o[i].y, 0.01)] = true
		assert_true(ys.size() >= 2, "top varies")


func test_scree_stone_contrast() -> void:
	var ground := Color("4d5568")
	var base := Color("8a8fa0")
	var bed := Scenery.scree_bed_color(ground)
	assert_true(Scenery.scree_stone_base(base, ground).get_luminance() - bed.get_luminance() >= 0.12, "stones read on Myriad's dark bed")
	assert_true(Scenery.scree_stone_lit(base, ground).get_luminance() > Scenery.scree_stone_base(base, ground).get_luminance(), "lit top lighter")
	var light := Color("c8c4b8")
	assert_eq(Scenery.scree_stone_base(light, light), light, "a light bed keeps the old colour")


func test_scree_slope_shade_lighter_toward_top() -> void:
	var top := 0.0
	var bottom := 0.0
	for y in range(0, 200, 10):
		top += GroundTiles.scree_slope_shade("myriad_peaks_ridge", y, 1000)
	for y in range(800, 1000, 10):
		bottom += GroundTiles.scree_slope_shade("myriad_peaks_ridge", y, 1000)
	assert_true(top > bottom, "the top of the slope is lighter")
	assert_true(absf(GroundTiles.scree_slope_shade("x", 500, 1000)) < 0.2, "gentle tone shift")


## GFX-164: neighbouring slope bands always differ in tone level, so each band edge shows a step of at least 0.09.
func test_scree_band_levels_differ_between_neighbours() -> void:
	for rid in ["myriad_peaks_ridge", "x", "azure_peak"]:
		for band in range(1, 12):
			assert_true(GroundTiles.scree_band_level(rid, band) != GroundTiles.scree_band_level(rid, band - 1), "%s band %d" % [rid, band])
			var a := GroundTiles.scree_slope_shade(rid, band * 110, 1000)
			var b := GroundTiles.scree_slope_shade(rid, band * 110 - 1, 1000)
			assert_true(absf(a - b) >= 0.07, "%s edge %d steps" % [rid, band])


## GFX-164: speckle factor 0.33 keeps about a third of the blobs; 1.0 keeps all.
func test_speckle_keep_fraction() -> void:
	var kept := 0
	for i in 1000:
		assert_true(GroundTiles.speckle_keep(i * 4096 + 7, 1.0))
		if GroundTiles.speckle_keep(absi(hash("sp|%d" % i)), 0.33):
			kept += 1
	assert_true(kept > 250 and kept < 420, "about a third kept: %d" % kept)


func test_scree_verge_inside_road() -> void:
	var r := Rect2(0, 470, 1600, 60)
	assert_true(r.encloses(Scenery.scree_verge_rect(r)))


## GFX-166: flat stones are wider than tall and deterministic; foot stones stay inside the step.
func test_flat_stone_is_low() -> void:
	for sd in 20:
		var poly := Scenery.flat_stone(Vector2(100, 100), 12.0, sd)
		var bounds := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			bounds = bounds.expand(q)
		assert_true(bounds.size.y < bounds.size.x * 0.85, "stone %d is flat: %s" % [sd, bounds.size])
		assert_eq(poly, Scenery.flat_stone(Vector2(100, 100), 12.0, sd))


func test_ledge_foot_stones_inside_span() -> void:
	for sd in 30:
		var stones := Scenery.ledge_foot_stones(200.0, 300.0, 50.0, sd)
		assert_true(stones.size() >= 2 and stones.size() <= 4)
		for st in stones:
			assert_true(st["pos"].x >= 200.0 and st["pos"].x <= 300.0)


func test_terrace_earth_lighter_on_dark_ground() -> void:
	var slate := Color("2c333c")
	assert_true(Scenery.terrace_earth(slate, 0, false).get_luminance() > slate.get_luminance())


## GFX-167: a drift is a low mound: base on the bottom edge, domed top inside the rect, tallest near the middle.
func test_drift_mound_is_a_dome_inside_its_rect() -> void:
	for sd in 8:
		var r := Rect2(100, 50, 80, 14)
		var m := Scenery.drift_mound(r, sd)
		assert_eq(m, Scenery.drift_mound(r, sd), "deterministic")
		var top := INF
		var top_x := 0.0
		for q in m:
			assert_true(r.grow(0.01).has_point(q), "inside the rect")
			if q.y < top:
				top = q.y
				top_x = q.x
		assert_true(top < r.end.y - r.size.y * 0.8, "rises to nearly the full height")
		assert_true(top_x > r.position.x + r.size.x * 0.25 and top_x < r.end.x - r.size.x * 0.25, "peak near the middle")
		assert_eq(m[0].y, r.end.y)
		assert_eq(m[1].y, r.end.y)


## GFX-167: the trail edge polygon wobbles on both long edges (not a straight band), stays inside the rect, no corners at the sides.
func test_trail_edge_polygon_wobbles_inside_the_rect() -> void:
	for r: Rect2 in [Rect2(0, 380, 1600, 40), Rect2(300, 0, 40, 600)]:
		var pts := Scenery.trail_edge_polygon(r, 7, 4.0, 3.0)
		assert_eq(pts, Scenery.trail_edge_polygon(r, 7, 4.0, 3.0))
		assert_true(pts != Scenery.trail_edge_polygon(r, 8, 4.0, 3.0))
		var half := pts.size() / 2
		var along_x := r.size.x >= r.size.y
		for side in 2:
			var vals: Array[float] = []
			for i in half:
				var q := pts[i + side * half]
				assert_true(r.grow(0.01).has_point(q), "inside the rect")
				vals.append(q.y if along_x else q.x)
			assert_true(vals.max() - vals.min() >= 2.0, "edge wobbles by at least 2 px")
	var narrow := Scenery.trail_edge_polygon(Rect2(0, 0, 14, 300), 3, 4.0, 2.0)  # GFX-167: narrow roads keep their edges apart
	var nh := narrow.size() / 2
	for i in nh:
		assert_true(narrow[nh + (nh - 1 - i)].x > narrow[i].x + 1.0, "edges never cross")


func test_moss_patches_and_verge_tufts() -> void:  # GFX-170
	var r := Rect2(0, 470, 1600, 60)
	var m := Scenery.moss_patches(r, 5)
	assert_true(m.size() > 10)
	assert_eq(m, Scenery.moss_patches(r, 5))
	for p in m:
		assert_true(r.encloses(p), "moss stays on the bed")
	var t := Scenery.verge_tufts(r, 5)
	assert_true(t.size() > 20)
	assert_eq(t, Scenery.verge_tufts(r, 5))
	for d in t:
		assert_false(r.has_point(d["pos"]), "tufts sit outside the bed")


func test_stone_road_wanders_and_stays_inside() -> void:  # GFX-172
	var r := Rect2(0, 470, 1600, 60)
	for sd in [1, 7, 99]:
		var road := Scenery.stone_road(r, sd)
		assert_eq(road, Scenery.stone_road(r, sd))
		var bed: PackedVector2Array = road["bed"]
		var lo_min := 1e9
		var lo_max := -1e9
		for p in bed:
			assert_true(r.grow(0.01).has_point(p), "bed inside the rect")
			if p.y < 500.0:
				lo_min = minf(lo_min, p.y)
				lo_max = maxf(lo_max, p.y)
		assert_true(lo_max - lo_min >= 4.0, "top edge wanders at least 4 px (%s)" % (lo_max - lo_min))
		var stones: Array = road["stones"]
		assert_true(stones.size() > 40)
		var sizes := {}
		for st: Dictionary in stones:
			var poly: PackedVector2Array = st["poly"]
			assert_true(poly.size() >= 4 and poly.size() <= 6)
			sizes[poly.size()] = true
			for p in poly:
				assert_true(r.grow(0.01).has_point(p))
		assert_true(sizes.size() >= 2, "varied side counts")
	assert_true(Scenery.stone_road(r, 1)["bed"] != Scenery.stone_road(r, 2)["bed"])
	var v := Scenery.stone_road(Rect2(100, 0, 60, 800), 3)  # a north-south road works too
	for p in v["bed"]:
		assert_true(Rect2(100, 0, 60, 800).grow(0.01).has_point(p))
