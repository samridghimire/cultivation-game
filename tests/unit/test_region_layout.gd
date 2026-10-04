extends TestCase
## Region layout guard: places and generated-NPC spots do not sit on top of
## each other (labels and click targets stay readable).


func _rect(entry: Dictionary, default_size: Array) -> Rect2:
	var pos: Array = entry.get("pos", [0, 0])
	var size: Array = entry.get("size", default_size)
	return Rect2(Vector2(float(pos[0]) - float(size[0]) / 2.0, float(pos[1]) - float(size[1]) / 2.0), Vector2(float(size[0]), float(size[1])))


func test_places_do_not_overlap() -> void:
	for region: Dictionary in data().regions.values():
		var rects: Array = []
		for place: Dictionary in region.get("places", []):
			rects.append([String(place.get("display_name", place["type"])), _rect(place, [30, 30])])
		for abode: Dictionary in region.get("abodes", []):
			rects.append([String(abode.get("display_name", abode["id"])), _rect(abode, [80, 60])])
		if region.has("family_home"):
			rects.append(["Family Home", _rect(region["family_home"], [90, 64])])
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				assert_false((rects[i][1] as Rect2).intersects(rects[j][1]), "%s: %s overlaps %s" % [region["id"], rects[i][0], rects[j][0]])


func test_npc_spots_keep_clear_of_places() -> void:
	for region: Dictionary in data().regions.values():
		var spots: Array = region.get("npc_spots", [])
		assert_true(spots.size() >= 10, "%s needs room for its generated NPCs" % region["id"])
		for spot: Array in spots:
			var p := Vector2(float(spot[0]), float(spot[1]))
			for place: Dictionary in region.get("places", []):
				assert_false(_rect(place, [30, 30]).grow(20.0).has_point(p), "%s: NPC spot %s stands on %s" % [region["id"], p, place.get("display_name", place["type"])])
			if region.has("family_home"):
				assert_false(_rect(region["family_home"], [90, 64]).grow(20.0).has_point(p), "%s: NPC spot %s stands on the Family Home" % [region["id"], p])
