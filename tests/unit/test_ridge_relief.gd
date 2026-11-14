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


func test_terrace_band_outline_is_curved_and_widths_differ() -> void:
	var bands := Scenery.terrace_bands(Rect2(100, 200, 130, 100), 5)
	var widths: Array[float] = []
	for poly in bands:
		var half := poly.size() / 2
		var ys: Array[float] = []
		var minx := INF
		var maxx := -INF
		for q in poly:
			minx = minf(minx, q.x)
			maxx = maxf(maxx, q.x)
		for i in half:
			ys.append(poly[i].y)
		assert_true(ys.max() - ys.min() >= 4.0, "upper edge is not axis-aligned")
		widths.append(maxx - minx)
	assert_true((widths.max() - widths.min()) / widths.max() >= 0.08, "bands differ in width")


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
