extends TestCase
## GFX-135: ragged pond shorelines, jetties/lilies still on water, meandering streams that stay straight at bridges.


func _regions() -> Array:
	return data().regions.values()


func test_mask_deterministic_in_range_and_seeded() -> void:
	var differs := false
	for i in 40:
		var a := float(i) * 0.37
		var m := Scenery.pond_mask_radius(a, 123, 0.12)
		assert_true(m >= 0.88 - 0.0001 and m <= 1.12 + 0.0001, "within 1 +/- amp")
		assert_eq(m, Scenery.pond_mask_radius(a, 123, 0.12))
		if absf(m - Scenery.pond_mask_radius(a, 999, 0.12)) > 0.001:
			differs = true
		var e := Scenery.pond_edge(a, 123)
		assert_true(e >= 0.72 - 0.0001 and e <= 1.0 + 0.0001, "edge within [0.72, 1]")
	assert_true(differs, "two seeds give two shapes")


func test_jetties_and_lilies_stay_on_water() -> void:
	var checked := 0
	for region: Dictionary in _regions():
		var lms: Array = region.get("map", {}).get("landmarks", [])
		for lm: Dictionary in lms:
			if lm.get("kind", "") == "jetty":
				var lay := Scenery.jetty_layout(region, lm)
				if not bool(lay["on_water"]):
					continue
				var r: Rect2 = lay["rect"]
				var toward: int = int(lay["toward_water"])
				var tip: Vector2
				if bool(lay["vertical"]):
					tip = Vector2(r.get_center().x, r.position.y if toward == -1 else r.end.y)
				else:
					tip = Vector2(r.position.x if toward == -1 else r.end.x, r.get_center().y)
				var ok := false
				for other: Dictionary in lms:
					if other.get("kind", "") == "pond" and Scenery.pond_water_contains(other, tip):
						ok = true
				assert_true(ok, "%s: jetty at %s reaches water" % [region["id"], lm["pos"]])
				checked += 1
			elif lm.get("kind", "") == "pond":
				var sz := Vector2(float(lm["size"][0]), float(lm["size"][1]))
				var c := Vector2(float(lm["pos"][0]), float(lm["pos"][1]))
				for pad: Dictionary in Scenery.pond_lilies(Rect2(c - sz / 2.0, sz), hash(str(lm["pos"])), 4):
					assert_true(Scenery.pond_water_contains(lm, pad["pos"]), "%s: lily pad on water" % region["id"])
	assert_true(checked > 0, "some jetty was checked")


func test_stream_offset_zero_at_crossings() -> void:
	var n := 0
	for region: Dictionary in _regions():
		for lm: Dictionary in region.get("map", {}).get("landmarks", []):
			if lm.get("kind", "") != "stream":
				continue
			var spans := Scenery.stream_spans(region, lm)
			var seed := hash(str(lm["pos"]))
			for sp in spans:
				var a: float = sp.x - 24.0
				while a <= sp.y + 24.0:
					assert_eq(Scenery.stream_offset(a, seed, spans), 0.0, "%s: straight at the bridge" % region["id"])
					a += 3.0
				n += 1
			var peak := 0.0
			for i in 400:
				var o := Scenery.stream_offset(float(i) * 5.0, seed, [] as Array[Vector2])
				peak = maxf(peak, absf(o))
				assert_true(absf(o) <= Scenery.STREAM_AMP + 0.001)
			assert_true(peak > 1.0, "the stream wobbles")
	assert_true(n > 0, "some stream crosses a path")


func test_pond_edge_has_coves_and_range() -> void:
	for s in 20:
		var lo := 9.0
		var hi := 0.0
		for d in 360:
			var e := Scenery.pond_edge(deg_to_rad(float(d)), s * 977 + 5)
			assert_true(e >= 0.72 - 0.0001 and e <= 1.0 + 0.0001, "edge in range")
			lo = minf(lo, e)
			hi = maxf(hi, e)
		assert_true(hi - lo >= 0.18, "seed %d spans >= 0.18 (%f)" % [s, hi - lo])


func test_frozen_bank_not_periodic_and_seeded() -> void:
	var a := PixelLandmark.pond_image(Vector2i(80, 50), Color("3f7fa8"), true, "pond", 11)
	var b := PixelLandmark.pond_image(Vector2i(80, 50), Color("3f7fa8"), true, "pond", 12)
	assert_true(a.get_data() != b.get_data(), "two seeds give different frozen banks")
	var counts: Array[int] = []
	for x in range(0, 70, 7):
		var n := 0
		for xx in 7:
			if a.get_pixel(x + xx, 25).r > 0.95:
				n += 1
		counts.append(n)
	assert_true(counts.size() > 1)


func test_places_use_blob_bases_and_platform_not_rect() -> void:
	var src := FileAccess.get_file_as_string("res://src/world/pixel_place.gd")
	for fn in ["_meditation", "_gather_crater", "_gather_crystal", "_gather_frost", "_cave", "_gather_terrace"]:
		var i := src.find("static func %s()" % fn)
		var body := src.substr(i, 260)
		assert_true(body.contains("blob("), "%s base is a blob" % fn)
	var court := Rect2(100, 100, 200, 80)
	var o := SectCourt.reed_hall_outline(court)
	assert_true(o.size() >= 8)
	var on_rect := 0
	for q in o:
		if is_zero_approx(q.x - court.position.x) or is_zero_approx(q.x - court.end.x) or is_zero_approx(q.y - court.position.y) or is_zero_approx(q.y - court.end.y):
			on_rect += 1
	assert_true(on_rect < o.size() / 2, "platform outline is no rectangle")
