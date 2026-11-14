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
