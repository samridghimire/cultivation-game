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


## WU-023: NPC name labels stay 90 px clear of place positions.
func test_npc_spots_are_90px_from_place_centers() -> void:
	for region: Dictionary in data().regions.values():
		var centers: Array[Vector2] = []
		for entry: Dictionary in region.get("places", []) + region.get("abodes", []):
			centers.append(Vector2(float(entry["pos"][0]), float(entry["pos"][1])))
		if region.has("family_home"):
			centers.append(Vector2(float(region["family_home"]["pos"][0]), float(region["family_home"]["pos"][1])))
		for spot: Array in region.get("npc_spots", []):
			var p := Vector2(float(spot[0]), float(spot[1]))
			for c in centers:
				assert_true(p.distance_to(c) >= Npcs.SPOT_CLEARANCE, "%s: NPC spot %s is within 90px of %s" % [region["id"], p, c])


## WU-205: at the spawn view (1280x720, camera on the spawn) the village's Workshop and Bounty Board
## stay clear of the HUD status panel (16,16 .. 340 wide, ~480 tall) and the log (bottom left).
func test_village_places_clear_of_hud_at_spawn() -> void:
	var region: Dictionary = data().regions["qingshi_village"]
	var spawn := Vector2(float(region["spawn"][0]), float(region["spawn"][1]))
	var view := Vector2(1280, 720)
	var cam := Vector2(clampf(spawn.x - view.x / 2.0, 0.0, 1600.0 - view.x), clampf(spawn.y - view.y / 2.0, 0.0, 1000.0 - view.y))
	var hud_rects: Array[Rect2] = [Rect2(16, 16, 340, 500), Rect2(16, 545, 520, 160)]
	for place: Dictionary in region["places"]:
		if not ["workshop", "bounty_board"].has(String(place["type"])):
			continue
		var r := _rect(place, [30, 30])
		r.position -= cam
		for h: Rect2 in hud_rects:
			assert_false(r.intersects(h), "%s sits under the HUD at %s" % [place["display_name"], r])
