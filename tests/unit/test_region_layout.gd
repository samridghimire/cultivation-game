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


## C-219: a meditation place's "(Nx qi)" label is the total (region x spot) multiplier.
func test_meditation_labels_state_total_qi() -> void:
	var rx := RegEx.new()
	rx.compile("\\(([0-9.]+)x qi\\)")
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			if place["type"] != "meditation":
				continue
			var m := rx.search(String(place.get("display_name", "")))
			if m == null:
				continue
			var total: float = float(region.get("qi_density", 1.0)) * float(place.get("qi_density", 1.0))
			assert_true(absf(float(m.get_string(1)) - total) <= 0.1, "%s: label %s but total qi is %.2f" % [region["id"], place["display_name"], total])


## WU-324: no two name labels in a region overlap before the runtime spread (so the lift is a fallback,
## not the layout). Rects come from Interactable.label_rect, the font width the world uses.
func test_place_labels_do_not_overlap() -> void:
	for region: Dictionary in data().regions.values():
		var rects: Array = []
		var entries: Array = []
		for place: Dictionary in region.get("places", []):
			entries.append([String(place.get("display_name", place["type"])), place, [30, 30]])
		for abode: Dictionary in region.get("abodes", []):
			entries.append([String(abode.get("display_name", abode["id"])), abode, [80, 60]])
		if region.has("family_home"):
			entries.append(["Family Home", region["family_home"], [90, 64]])
		for e: Array in entries:
			var node := Interactable.new()
			var pos: Array = e[1]["pos"]
			var sz: Array = e[1].get("size", e[2])
			node.position = Vector2(float(pos[0]), float(pos[1]))
			node.size = Vector2(float(sz[0]), float(sz[1]))
			rects.append([e[0], node.label_rect(e[0])])
			node.free()
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				assert_false((rects[i][1] as Rect2).intersects(rects[j][1]), "%s: label %s overlaps label %s" % [region["id"], rects[i][0], rects[j][0]])


## WU-325: no region's npc_spots entry puts an NPC label on a place label. NPC label width: the longest named NPC
## in the region (data/npcs.json), or 18 characters when it has none; NPC size 28 like the world's NPCs.
func test_npc_spot_labels_do_not_overlap_place_labels() -> void:
	var longest := {}
	var named: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json")) as Dictionary)["npcs"]
	for n: Dictionary in named:
		var r := String(n.get("region", ""))
		if String(n["name"]).length() > String(longest.get(r, "")).length():
			longest[r] = String(n["name"])
	for region: Dictionary in data().regions.values():
		var places: Array = []
		for place: Dictionary in region.get("places", []):
			places.append([String(place.get("display_name", place["type"])), place, [30, 30]])
		for abode: Dictionary in region.get("abodes", []):
			places.append([String(abode.get("display_name", abode["id"])), abode, [80, 60]])
		if region.has("family_home"):
			places.append(["Family Home", region["family_home"], [90, 64]])
		var place_rects: Array = []
		for e: Array in places:
			var node := Interactable.new()
			var pos: Array = e[1]["pos"]
			var sz: Array = e[1].get("size", e[2])
			node.position = Vector2(float(pos[0]), float(pos[1]))
			node.size = Vector2(float(sz[0]), float(sz[1]))
			place_rects.append([e[0], node.label_rect(e[0])])
			node.free()
		var npc_text: String = String(longest.get(region["id"], "n".repeat(18)))
		for spot: Array in region.get("npc_spots", []):
			var npc := Interactable.new()
			npc.position = Vector2(float(spot[0]), float(spot[1]))
			npc.size = Vector2(28, 28)
			var rect := npc.label_rect(npc_text)
			npc.free()
			for pr: Array in place_rects:
				assert_false(rect.intersects(pr[1]), "%s: npc spot %s label (%s) overlaps %s" % [region["id"], spot, npc_text, pr[0]])
		for n: Dictionary in named:  # placed named NPCs (fixed pos) too
			if String(n.get("region", "")) != String(region["id"]) or not n.has("pos"):
				continue
			var npc := Interactable.new()
			npc.position = Vector2(float(n["pos"][0]), float(n["pos"][1]))
			npc.size = Vector2(28, 28)
			var rect := npc.label_rect(String(n["name"]))
			npc.free()
			for pr: Array in place_rects:
				assert_false(rect.intersects(pr[1]), "%s: %s label overlaps %s" % [region["id"], n["name"], pr[0]])
