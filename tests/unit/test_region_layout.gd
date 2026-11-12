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


## GFX-054: Fallen Star Market: every place but the City Gate stays 60 px inside the map, and at the arrival camera
## (1280x800 on the spawn) no place, stall or NPC spot sits under the vitals card or the Next steps card.
func test_market_town_layout() -> void:
	var region: Dictionary = data().regions["fallen_star_market"]
	var map: Dictionary = region["map"]
	var inner := Rect2(Vector2.ZERO, Vector2(float(map["size"][0]), float(map["size"][1]))).grow(-60.0)
	var spawn := Vector2(float(region["spawn"][0]), float(region["spawn"][1]))
	var cam := Vector2(clampf(spawn.x - 640.0, 0.0, float(map["size"][0]) - 1280.0), clampf(spawn.y - 400.0, 0.0, float(map["size"][1]) - 800.0))
	var cards: Array[Rect2] = [Rect2(16, 16, 330, 175), Rect2(910, 16, 360, 170)]
	var rects: Array = []
	for place: Dictionary in region["places"]:
		if place["type"] != "travel":
			assert_true(inner.encloses(_rect(place, [30, 30])), "%s is within 60 px of the map edge" % place.get("display_name", place["type"]))
		rects.append([String(place.get("display_name", place["type"])), _rect(place, [30, 30])])
	for lm: Dictionary in map["landmarks"]:
		if lm["kind"] == "stall":
			rects.append(["stall at %s" % [lm["pos"]], _rect(lm, [80, 50])])
	for spot: Array in region["npc_spots"]:
		rects.append(["NPC spot %s" % [spot], Rect2(float(spot[0]) - 14.0, float(spot[1]) - 14.0, 28.0, 28.0)])
	for e: Array in rects:
		var r: Rect2 = e[1]
		r.position -= cam
		for c in cards:
			assert_false(r.intersects(c), "%s sits under a HUD card at the arrival camera" % e[0])


## WU-434: nothing important hides under the HUD cards at the arrival camera, in any region.
func test_nothing_under_hud_cards_on_arrival() -> void:
	var cards: Array[Rect2] = [Rect2(16, 16, 330, 175), Rect2(910, 16, 360, 170), Rect2(16, 735, 410, 55)]
	var kinds: Array[String] = ["pond", "jetty", "house", "field", "well", "stall"]
	for region: Dictionary in data().regions.values():
		var map: Dictionary = region["map"]
		var spawn := Vector2(float(region["spawn"][0]), float(region["spawn"][1]))
		var cam := Vector2(clampf(spawn.x - 640.0, 0.0, float(map["size"][0]) - 1280.0), clampf(spawn.y - 400.0, 0.0, float(map["size"][1]) - 800.0))
		var rects: Array = []
		for place: Dictionary in region["places"]:
			if place["type"] != "travel":
				var pname := String(place.get("display_name", place["type"]))
				rects.append([pname, _rect(place, [30, 30])])
				# WU-435: the name label too (approx. 7 px per char + 16 wide, 20 high, centred above the place).
				var body := _rect(place, [30, 30])
				var lw := 7.0 * pname.length() + 16.0
				rects.append(["label of " + pname, Rect2(body.get_center().x - lw / 2.0, body.position.y - 30.0, lw, 20.0)])
		for lm: Dictionary in map["landmarks"]:
			if String(lm["kind"]) in kinds:
				rects.append(["%s at %s" % [lm["kind"], lm["pos"]], _rect(lm, [80, 50])])
		for spot: Array in region["npc_spots"]:
			rects.append(["NPC spot %s" % [spot], Rect2(float(spot[0]) - 14.0, float(spot[1]) - 14.0, 28.0, 28.0)])
		for e: Array in rects:
			var r: Rect2 = e[1]
			r.position -= cam
			for c in cards:
				assert_false(r.intersects(c), "%s: %s sits under a HUD card at the arrival camera" % [region["id"], e[0]])


## GFX-054: a paved map gets flagstones only along its streets and in its plaza.
func test_paved_zones_follow_the_streets() -> void:
	var map: Dictionary = data().regions["fallen_star_market"]["map"]
	var zones := Scenery.paved_zones(map, 1.0)
	assert_eq(zones.size(), 3)
	assert_true(GroundTiles.in_paved_zone(zones, "x", 800, 500), "street crossing is paved")
	assert_false(GroundTiles.in_paved_zone(zones, "x", 150, 900), "a far corner is packed earth")
	assert_true(Scenery.paved_zones({"ground_style": "grass", "paths": [[0, 0, 10, 10]]}, 1.0).is_empty())
	assert_true(Scenery.paved_zones({"ground_style": "paved"}, 1.0).is_empty())


## GFX-056: no two place name labels overlap once LabelLayout has run (approximate width 7 px per char + 16).
func test_place_labels_do_not_overlap_after_layout() -> void:
	for region: Dictionary in data().regions.values():
		var rects: Array[Rect2] = []
		var anchors: Array[Vector2] = []
		var names: Array[String] = []
		for place: Dictionary in region["places"]:
			var n := String(place.get("display_name", place["type"]))
			var pos := Vector2(float(place["pos"][0]), float(place["pos"][1]))
			var sz: Array = place.get("size", [30, 30])
			var w := 7.0 * n.length() + 16.0
			rects.append(Rect2(pos.x - w / 2.0, pos.y - float(sz[1]) / 2.0 - 30.0, w, 20.0))
			anchors.append(pos)
			names.append(n)
		var offs := LabelLayout.offsets(rects, anchors)
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				var a := Rect2(rects[i].position + offs[i], rects[i].size)
				var b := Rect2(rects[j].position + offs[j], rects[j].size)
				assert_false(a.intersects(b), "%s: labels '%s' and '%s' overlap" % [region["id"], names[i], names[j]])


## RV-017: every sect's home region has a sect_hall place, so the mission board is reachable where the core says it is.
func test_every_sect_home_region_has_a_hall() -> void:
	for sect: SectDef in data().sects.values():
		if sect.home_region == "":
			continue
		var has_hall := false
		for place: Dictionary in data().regions[sect.home_region]["places"]:
			has_hall = has_hall or String(place["type"]) == "sect_hall"
		assert_true(has_hall, "%s has no sect_hall in %s" % [sect.id, sect.home_region])


## GFX-062: a roamer never spawns within 90 px of a place (the bog-king toad used to stand between labels).
func test_roamers_spawn_clear_of_places() -> void:
	for region: Dictionary in data().regions.values():
		var map_size := Vector2(float(region["map"]["size"][0]), float(region["map"]["size"][1]))
		var zones := Roamer.keep_clear_zones(region)
		var none: Array[Rect2] = []
		var avoid: Array[Vector2] = []
		for day in 14:
			for slot in 3:
				var spot := Roamer.pick_spot(String(region["id"]), day, slot, map_size, none, avoid, zones["rects"], zones["points"])
				for place: Dictionary in region["places"]:
					assert_false(_rect(place, [30, 30]).grow(90.0 - 1.0).has_point(spot), "%s day %d slot %d spawns by %s" % [region["id"], day, slot, place.get("display_name", "?")])


## GFX-062: the marsh ground carries about half the old speckle.
func test_bog_ground_is_calmer() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var base := Color("384330")
	img.fill(base)
	GroundTiles._apply_style(img, base, "withered_bone_marsh", "bog")
	var changed := 0
	for y in 256:
		for x in 256:
			if img.get_pixel(x, y) != base:
				changed += 1
	assert_true(changed < 256 * 256 / 4, "marsh tiles still speckled: %d px" % changed)


## REVIEW (GFX-062): with the world's real blocked rects, a roamer never stands inside a solid landmark (house, wall...);
## the keep-clear fallback used to ignore them (about 1 beast in 14 in Qingshi was inside a building).
func test_roamers_never_spawn_inside_solid_landmarks() -> void:
	for region: Dictionary in data().regions.values():
		var map_size := Vector2(float(region["map"]["size"][0]), float(region["map"]["size"][1]))
		var zones := Roamer.keep_clear_zones(region)
		var solid: Array[Rect2] = Scenery.landmark_rects(region)
		var blocked: Array[Rect2] = Scenery.landmark_rects(region)
		for place: Dictionary in region.get("places", []):
			blocked.append(_rect(place, [64, 64]))
		for p: Array in region["map"].get("paths", []):
			blocked.append(Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
		for day in 60:
			var spawn: Array = region.get("spawn", [map_size.x / 2.0, map_size.y / 2.0])
			var avoid: Array[Vector2] = [Vector2(float(spawn[0]), float(spawn[1]))]
			for slot in 5:
				var spot := Roamer.pick_spot(String(region["id"]), day, slot, map_size, blocked, avoid, zones["rects"], zones["points"])
				avoid.append(spot)
				for r in solid:
					assert_false(r.has_point(spot), "%s day %d slot %d inside a landmark %s" % [region["id"], day, slot, r])


## GFX-068: the mountain ground carries about half the old speckle (old: about 12% of pixels, now about 6%).
func test_scree_ground_is_calmer() -> void:
	var base := Color("627889")
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(base)
	GroundTiles._apply_style(img, base, "azure_peak", "scree")
	var patches := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	patches.fill(base)
	GroundTiles._scree_patches(patches, base, "azure_peak")
	var speckled := 0
	for y in 256:
		for x in 256:
			if img.get_pixel(x, y) != patches.get_pixel(x, y):
				speckled += 1
	assert_true(speckled < 256 * 256 / 10, "mountain tiles still speckled: %d px" % speckled)


## GFX-068: both sect halls get a court inside the map, clear of paths and other places, and the region a gate.
func test_sect_courts_and_gates() -> void:
	var seen := 0
	for region: Dictionary in data().regions.values():
		var g := SectCourt.gate(region)
		var has_sect_hall := false
		for place: Dictionary in region["places"]:
			if not SectCourt.is_sect_hall(place):
				continue
			has_sect_hall = true
			seen += 1
			var court := SectCourt.court_rect(place, region)
			var hall := _rect(place, [64, 64])
			assert_true(court.encloses(hall), "%s court covers its hall" % place["display_name"])
			# GFX-071: a hall hemmed in by neighbours (the marsh hall above the Pure Lotus Isle) keeps the plain hall rect.
			if region["id"] == "azure_peak":
				assert_true(court.size.x > hall.size.x * 1.3, "%s court is a real court" % place["display_name"])
			if court.size.y > hall.size.y * 1.4:
				assert_true(hall.get_center().y < court.get_center().y, "%s hall stands in the court's north half" % place["display_name"])
				assert_true(hall.position.y - court.position.y >= SectCourt.TOP_MARGIN - 0.5, "%s grass above the hall for its label" % place["display_name"])
			assert_true(Rect2(Vector2.ZERO, Vector2(float(region["map"]["size"][0]), float(region["map"]["size"][1]))).encloses(court), "%s court inside map" % place["display_name"])
			for p in region["map"]["paths"]:
				assert_false(court.intersects(Rect2(p[0], p[1], p[2], p[3])), "%s court on a path" % place["display_name"])
			for other: Dictionary in region["places"]:
				if other != place:
					assert_false(court.intersects(SectCourt.place_footprint(other)), "%s court over %s (drawn footprint+label)" % [place["display_name"], other.get("display_name", "?")])
		if not g.is_empty():
			var gr := SectCourt.gate_rect(g)
			assert_true(gr.size.y >= 90.0, "%s gate is tall (roofed)" % region["id"])
			var parts := SectCourt.gate_parts(g)
			var roof: Rect2 = parts["roof"]
			assert_true(absf(roof.get_center().x - float(g["x"])) <= 24.0 and roof.size.x <= 48.0, "%s roof spans the road, not the map" % region["id"])
			assert_true(gr.encloses(parts["stele"]), "%s gate rect holds the board" % region["id"])
			for post: Rect2 in parts["posts"]:
				assert_true(gr.encloses(post), "%s gate rect holds both posts" % region["id"])
			assert_true(roof.position.y <= (parts["posts"][0] as Rect2).position.y and roof.end.y >= (parts["posts"][1] as Rect2).position.y, "%s roof runs post to post" % region["id"])
			assert_false((parts["stele"] as Rect2).intersects(parts["posts"][0]), "%s board clear of the north post" % region["id"])
			for lm: Dictionary in region["map"].get("landmarks", []):  # GFX-120: the name board keeps 16 px from every landmark
				if str(lm["kind"]) in ["pine", "house", "well", "wall", "lantern", "stall", "field", "fence", "cliff", "steps"]:
					assert_false((parts["stele"] as Rect2).grow(16.0).intersects(_rect(lm, [40, 40])), "%s name board within 16 px of a %s" % [region["id"], lm["kind"]])
			# GFX-076: both posts stay visible (neither is hidden inside the roof) and stand on the road verges.
			for post: Rect2 in parts["posts"]:
				assert_false(roof.encloses(post), "%s a post is hidden under the roof" % region["id"])
			assert_true((parts["posts"][0] as Rect2).end.y - SectCourt.POST_BASE <= (g["path"] as Rect2).position.y, "%s north post on the north verge" % region["id"])
			assert_true((parts["posts"][1] as Rect2).end.y - SectCourt.POST_BASE >= (g["path"] as Rect2).end.y, "%s south post on the south verge" % region["id"])
			assert_true(roof.size.y >= (g["path"] as Rect2).size.y, "%s roof spans the road" % region["id"])
			assert_true(Rect2(Vector2.ZERO, Vector2(float(region["map"]["size"][0]), float(region["map"]["size"][1]))).encloses(gr), "%s gate inside map" % region["id"])
			# GFX-074: both pillars well clear of the edge-exit post, and no place sprite inside the court.
			for place: Dictionary in region["places"]:
				if String(place.get("type", "")) == "travel":
					for post: Rect2 in parts["posts"]:
						assert_true(post.position.x >= float(place["pos"][0]) + SectCourt.EXIT_CLEAR, "%s pillars clear of the exit post" % region["id"])
					assert_false((parts["stele"] as Rect2).intersects(_rect(place, [64, 64]).grow(30.0)), "%s name board clear of the exit" % region["id"])
			for place: Dictionary in region["places"]:
				if SectCourt.is_sect_hall(place):
					var court := SectCourt.court_rect(place, region)
					for other: Dictionary in region["places"]:
						if other != place:
							assert_false(court.intersects(_rect(other, [64, 64])), "%s: %s sprite inside the court" % [region["id"], other.get("display_name", "?")])
					assert_false(court.intersects(parts["stele"]), "%s court clear of the board" % region["id"])
					for abode: Dictionary in region.get("abodes", []):  # GFX-076: the drawn abode (1.3x) stays off the court
						var ar := _rect(abode, [100, 70])
						assert_false(court.intersects(Rect2(ar.get_center() - ar.size * 0.65, ar.size * 1.3)), "%s: abode sprite inside the court" % region["id"])
					if region["id"] == "withered_bone_marsh":
						assert_true(court.size.x > _rect(place, [64, 64]).size.x + 30.0, "marsh hall has a real court")
						assert_eq(SectCourt.court_style(region), "marsh")
		assert_eq(not g.is_empty(), has_sect_hall, "%s gate only with a sect hall" % region["id"])
	assert_true(seen >= 2, "azure peak and the marsh both have sect halls")


## GFX-076: idle villagers keep 24 px off the gate (decor is filtered against the same zone in world.gd).
func test_gate_keep_out() -> void:
	for region: Dictionary in data().regions.values():
		var g := SectCourt.gate(region)
		if g.is_empty():
			continue
		var keep := SectCourt.gate_rect(g).grow(SectCourt.GATE_KEEP)
		var out := SectCourt.nudge_off_gate(SectCourt.gate_rect(g).get_center(), g)
		assert_false(keep.has_point(out), "%s nudged villager leaves the gate" % region["id"])
		assert_eq(SectCourt.nudge_off_gate(Vector2(5, 5), g), Vector2(5, 5))
		for spot: Array in region.get("npc_spots", []):
			assert_false(keep.has_point(Vector2(float(spot[0]), float(spot[1]))), "%s npc spot in the gate" % region["id"])


## GFX-103: every region name fits its gate board (width, then smaller type, then two lines).
func test_gate_board_fits_every_region_name() -> void:
	var font := ThemeDB.fallback_font
	for region: Dictionary in data().regions.values():
		var name := String(region.get("name", ""))
		var fit := SectCourt.board_layout(name, font)
		assert_true(float(fit["w"]) <= SectCourt.STELE_MAX_W and float(fit["w"]) >= SectCourt.STELE_W, name + " width")
		for line: String in fit["lines"]:
			assert_true(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fit["size"])).x <= float(fit["w"]), "%s line '%s' fits" % [name, line])
	var long := SectCourt.board_layout("The Extremely Long Name Of A Faraway Mountain Region", font)
	assert_eq((long["lines"] as Array).size(), 2)
	var marsh := SectCourt.board_layout("Withered Bone Marsh", font)
	assert_eq((marsh["lines"] as Array).size(), 1)


func test_map_water_kinds() -> void:
	for kind: String in PlaceLooks.WATER_KINDS + ["lava"]:
		var d := GameData.load_from_dir()
		d.regions["qingshi_village"]["map"]["water"] = kind
		d.load_errors.clear()
		d._validate_world()
		assert_eq("\n".join(d.load_errors).contains("unknown map.water"), kind == "lava", kind)
	var tex: Array = []
	for kind: String in PlaceLooks.WATER_KINDS:
		tex.append("".join(PixelLandmark._rows_of(PixelLandmark._pond(60, 40, true, kind))))
	assert_eq(tex.size(), 3)
	assert_true(tex[0] != tex[1] and tex[1] != tex[2] and tex[0] != tex[2], "each water kind is its own picture")


## WU-499: no place's name label lies on another place's drawn footprint (per region that passes today).
## Qingshi's remaining label/footprint pairs are spread at runtime (LabelLayout); these pairs are fixed in the layout.
const LABEL_FOOTPRINT_REGIONS: Array[String] = ["qingshi_village"]
const LABEL_FOOTPRINT_PAIRS: Array = [["Blossom Crack in the Hill", "Village Workshop"], ["Old Shrine", "Founder's Old Well"]]


func test_place_labels_clear_of_other_footprints() -> void:
	for region: Dictionary in data().regions.values():
		if not LABEL_FOOTPRINT_REGIONS.has(String(region["id"])):
			continue
		var places: Array = region.get("places", [])
		for place: Dictionary in places:
			var node := Interactable.new()
			var pos: Array = place["pos"]
			var sz: Array = place.get("size", [30, 30])
			node.position = Vector2(float(pos[0]), float(pos[1]))
			node.size = Vector2(float(sz[0]), float(sz[1]))
			var lr := node.label_rect(String(place.get("display_name", place["type"])))
			node.free()
			for other: Dictionary in places:
				if other == place or not LABEL_FOOTPRINT_PAIRS.any(func(pr: Array) -> bool: return pr[0] == place.get("display_name") and pr[1] == other.get("display_name")):
					continue
				var osz: Array = other.get("size", [64, 64])
				var ocen := Vector2(float(other["pos"][0]), float(other["pos"][1]))
				var body := Rect2(ocen - Vector2(float(osz[0]), float(osz[1])) * 0.65, Vector2(float(osz[0]), float(osz[1])) * 1.3)  # the drawn building (1.3x its rect)
				assert_false(lr.intersects(body), "%s: label of %s lies on %s" % [region["id"], place.get("display_name", "?"), other.get("display_name", "?")])


## WU-500: strict check: no Qingshi place label (world font size) lies on another place's drawn body (1.3x its rect).
func _qingshi_label_hits() -> PackedStringArray:
	var hits := PackedStringArray()
	var region: Dictionary = data().regions["qingshi_village"]
	var places: Array = region.get("places", [])
	for place: Dictionary in places:
		var node := Interactable.new()
		var pos: Array = place["pos"]
		var sz: Array = place.get("size", [30, 30])
		node.position = Vector2(float(pos[0]), float(pos[1]))
		node.size = Vector2(float(sz[0]), float(sz[1]))
		var lr := node.label_rect(String(place.get("display_name", place["type"])))
		node.free()
		for other: Dictionary in places:
			if other == place:
				continue
			var osz: Array = other.get("size", [64, 64])
			var ocen := Vector2(float(other["pos"][0]), float(other["pos"][1]))
			if lr.intersects(Rect2(ocen - Vector2(float(osz[0]), float(osz[1])) * 0.65, Vector2(float(osz[0]), float(osz[1])) * 1.3)):
				hits.append("%s on %s [%s]" % [place.get("display_name", "?"), other.get("display_name", "?"), lr])
	return hits


func test_qingshi_labels_clear_of_footprints() -> void:
	var hits := _qingshi_label_hits()
	assert_eq(hits.size(), 0, "label overlaps: " + "; ".join(hits))


## WU-505: strict check for every region: no place label (world font) lies on another place's drawn body (1.3x its
## rect) or on an NPC spot's name rect (longest named NPC of the region, else 18 chars). Roamers move: not tested.
func _label_hits(region: Dictionary) -> PackedStringArray:
	var hits := PackedStringArray()
	var longest := ""
	for n: Dictionary in (JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json")) as Dictionary)["npcs"]:
		if String(n.get("region", "")) == String(region["id"]) and String(n["name"]).length() > longest.length():
			longest = String(n["name"])
	if longest == "":
		longest = "n".repeat(18)
	var items: Array = []  # [name, pos, size]
	for place: Dictionary in region.get("places", []):
		items.append([String(place.get("display_name", place["type"])), place["pos"], place.get("size", [30, 30])])
	for abode: Dictionary in region.get("abodes", []):
		items.append([String(abode.get("display_name", abode["id"])), abode["pos"], abode.get("size", [80, 60])])
	var npc_rects: Array = []
	for spot: Array in region.get("npc_spots", []):
		var npc := Interactable.new()
		npc.position = Vector2(float(spot[0]), float(spot[1]))
		npc.size = Vector2(28, 28)
		npc_rects.append(npc.label_rect(longest))
		npc.free()
	for e: Array in items:
		var node := Interactable.new()
		node.position = Vector2(float(e[1][0]), float(e[1][1]))
		node.size = Vector2(float(e[2][0]), float(e[2][1]))
		var lr := node.label_rect(String(e[0]))
		node.free()
		for o: Array in items:
			if o == e:
				continue
			var osz := Vector2(float(o[2][0]), float(o[2][1]))
			var body := Rect2(Vector2(float(o[1][0]), float(o[1][1])) - osz * 0.65, osz * 1.3)
			if lr.intersects(body):
				hits.append("%s on %s" % [e[0], o[0]])
		for nr: Rect2 in npc_rects:
			if lr.intersects(nr):
				hits.append("%s on npc name at %s" % [e[0], nr.position])
	return hits


func test_all_regions_labels_clear_of_footprints_and_npcs() -> void:
	for region: Dictionary in data().regions.values():
		var hits := _label_hits(region)
		assert_eq(hits.size(), 0, "%s: %s" % [region["id"], "; ".join(hits)])


## WU-511: for every region, a person at a day spot (label at its normal place) ends clear of every place label.
func test_person_labels_clear_of_place_labels_after_layout() -> void:
	for region: Dictionary in data().regions.values():
		var places: Array[Rect2] = []
		for place: Dictionary in region["places"]:
			var n := String(place.get("display_name", place["type"]))
			var pos := Vector2(float(place["pos"][0]), float(place["pos"][1]))
			var sz: Array = place.get("size", [30, 30])
			var w := 7.0 * n.length() + 16.0
			places.append(Rect2(pos.x - w / 2.0, pos.y - float(sz[1]) / 2.0 - 30.0, w, 20.0))
		for s: Array in region.get("npc_spots", []):
			var pos := Vector2(float(s[0]), float(s[1]))
			var w := 7.0 * 18.0 + 16.0  # a typical "Name (Title)" label
			var label := Rect2(pos.x - w / 2.0, pos.y - 15.0 - 8.0 - 18.0, w, 22.0)
			var d := LabelLayout.person_offset(label, pos.y + 15.0, places)
			var moved := Rect2(label.position + d, label.size)
			for p in places:
				assert_false(moved.intersects(p), "%s: person label at %s still on a place label" % [region["id"], pos])
