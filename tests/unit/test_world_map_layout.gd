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


func test_route_labels_hit_no_node() -> void:
	var rects := _rects()
	var footprints: Array[Rect2] = []
	for r: Rect2 in rects.values():
		footprints.append(WorldMapScreen.node_footprint(r))
	var size := Vector2(40, 22)
	for region: Dictionary in data().regions.values():
		for route: Dictionary in region.get("routes", []):
			var to := String(route.get("to", ""))
			if not rects.has(to):
				continue
			var a: Vector2 = (rects[region["id"]] as Rect2).get_center()
			var b: Vector2 = (rects[to] as Rect2).get_center()
			var pos := WorldMapScreen.route_label_pos(a, b, size, footprints)
			assert_false(footprints.any(func(n: Rect2) -> bool: return n.intersects(Rect2(pos, size))), "%s->%s label hits a node" % [region["id"], to])


func test_route_label_slides_off_a_node_in_the_middle() -> void:
	var blocker: Array[Rect2] = [Rect2(95, 80, 10, 40)]
	var pos := WorldMapScreen.route_label_pos(Vector2(0, 100), Vector2(200, 100), Vector2(30, 20), blocker)
	assert_false(blocker[0].intersects(Rect2(pos, Vector2(30, 20))))
	assert_true(pos.y < 100.0)


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
