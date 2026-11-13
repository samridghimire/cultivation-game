extends TestCase
## GFX-059: the world map's nodes and route labels never overlap.


func _rects() -> Dictionary:
	var out := {}
	var layout := WorldMapScreen.layout(data())
	for id: String in layout:
		var label := "* " + Exploration.region_name(data(), id)
		out[id] = WorldMapScreen.node_rect(label, WorldMapScreen.center_of(layout[id]), ThemeDB.fallback_font, 14)
	return out


func test_every_region_has_a_map_pos() -> void:
	for region: Dictionary in data().regions.values():
		assert_eq((region.get("map_pos", []) as Array).size(), 2, "%s has no map_pos" % region["id"])


func test_node_footprints_do_not_overlap_and_stay_on_canvas() -> void:
	var rects := _rects()
	var ids := rects.keys()
	for i in ids.size():
		var a: Rect2 = WorldMapScreen.node_footprint(rects[ids[i]])
		assert_true(Rect2(Vector2.ZERO, WorldMapScreen.CANVAS_SIZE).encloses(a), "%s leaves the canvas" % ids[i])
		for j in range(i + 1, ids.size()):
			assert_false(a.intersects(WorldMapScreen.node_footprint(rects[ids[j]])), "%s overlaps %s" % [ids[i], ids[j]])


func test_node_rect_fits_the_whole_name() -> void:
	var r := WorldMapScreen.node_rect("Withered Bone Marsh", Vector2(300, 200), ThemeDB.fallback_font, 14)
	assert_true(r.size.x >= ThemeDB.fallback_font.get_string_size("Withered Bone Marsh", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0)
	assert_eq(WorldMapScreen.node_rect("Hi", Vector2.ZERO, ThemeDB.fallback_font, 14).size.x, 110.0)


func test_node_colors_are_opaque_and_readable() -> void:
	for unexplored: bool in [false, true]:
		var c := WorldMapScreen.node_colors(unexplored)
		assert_true((c["bg"] as Color).a >= 0.94, "backing is opaque")
		assert_true(WorldMapScreen.contrast_ratio(c["text"], c["bg"]) >= 4.5, "text contrast (unexplored=%s)" % unexplored)


func test_clip_to_rects_leaves_both_nodes() -> void:
	var rects := _rects()
	var feet := {}
	for id: String in rects:
		feet[id] = WorldMapScreen.node_footprint(rects[id])
	for region: Dictionary in data().regions.values():
		for route: Dictionary in region.get("routes", []):
			var to := String(route.get("to", ""))
			if not rects.has(to):
				continue
			var ra: Rect2 = feet[region["id"]]
			var rb: Rect2 = feet[to]
			var seg := WorldMapScreen.clip_to_rects((rects[region["id"]] as Rect2).get_center(), (rects[to] as Rect2).get_center(), ra, rb)
			for p in seg:
				assert_false(ra.has_point(p) or rb.has_point(p), "%s->%s point inside a node" % [region["id"], to])


func test_terrain_kind_from_encounter_tags() -> void:
	assert_eq(WorldMapScreen.terrain_kind({"encounter_tags": ["village"]}), "village")
	assert_eq(WorldMapScreen.terrain_kind({"encounter_tags": ["mountain", "wild"]}), "peaks")
	assert_eq(WorldMapScreen.terrain_kind({"encounter_tags": ["marsh", "wild"]}), "marsh")
	assert_eq(WorldMapScreen.terrain_kind({"encounter_tags": ["city"]}), "market")
	assert_eq(WorldMapScreen.terrain_kind({"encounter_tags": ["forest", "wild"]}), "forest")
	assert_eq(WorldMapScreen.terrain_kind({}), "hills")


func test_day_label_pos_midpoint_then_slides() -> void:
	var none: Array[Rect2] = []
	assert_eq(WorldMapScreen.day_label_pos(Vector2(0, 100), Vector2(200, 100), none, none), Vector2(100, 100))
	var box: Array[Rect2] = [Rect2(80, 80, 40, 40)]
	var c := WorldMapScreen.day_label_pos(Vector2(0, 100), Vector2(200, 100), box, none)
	assert_true(c != Vector2(100, 100))
	assert_false(box[0].intersects(Rect2(c - Vector2(18, 11), Vector2(36, 22))))
	var taken: Array[Rect2] = [Rect2(82, 89, 36, 22)]
	var d := WorldMapScreen.day_label_pos(Vector2(0, 100), Vector2(200, 100), none, taken)
	assert_false(taken[0].intersects(Rect2(d - Vector2(18, 11), Vector2(36, 22))))


func test_ui_block_has_heading_and_body() -> void:
	var b := UIStyle.block("Shops", PackedStringArray(["a", "b"]))
	assert_eq((b.get_child(0) as Label).text, "Shops")
	assert_eq((b.get_child(1) as Label).text, "a\nb")
	b.free()
