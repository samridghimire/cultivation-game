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
		assert_true(e >= 0.88 - 0.0001 and e <= 1.0 + 0.0001, "edge within [0.88, 1]")
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
