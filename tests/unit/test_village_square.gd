## GFX-131: roads that wander and the village square.
extends TestCase


func _qingshi() -> Dictionary:
	return data().regions["qingshi_village"]


func _pieces(region: Dictionary, rect: Rect2) -> Array[Dictionary]:
	return Scenery.path_tiles(region, rect)


func test_square_deterministic_and_clear() -> void:
	var r := _qingshi()
	var a := Scenery.village_square(r)
	var b := Scenery.village_square(r)
	assert_true(not a.is_empty(), "qingshi has a square")
	assert_eq(a["tree"], b["tree"])
	assert_eq(a["props"], b["props"])
	var keep: Array[Rect2] = []
	for pl: Dictionary in r["places"]:
		keep.append(Npcs.place_keepout(pl))
	for pr in r["map"]["paths"]:
		keep.append(Rect2(pr[0], pr[1], pr[2], pr[3]))
	var taken: Array[Rect2] = []
	if not (a["tree"] as Dictionary).is_empty():
		var tp: Vector2 = a["tree"]["pos"]
		taken.append(Rect2(tp - Vector2(20, 20), Vector2(40, 40)))
	for p: Dictionary in a["props"]:
		taken.append(p["rect"])
	for i in taken.size():
		for k in keep:
			assert_false(k.intersects(taken[i]), "square item %d overlaps a place or road" % i)
		for j in range(i + 1, taken.size()):
			assert_false(taken[i].intersects(taken[j]), "square items overlap")
	assert_true(not (a["tree"] as Dictionary).is_empty(), "the square has its tree")


func test_no_square_is_empty() -> void:
	assert_true(Scenery.village_square({"id": "x", "map": {}}).is_empty())


func test_validate_rejects_bad_square() -> void:
	var d := data()
	var saved: Variant = d.regions["qingshi_village"]["map"]["square"]
	d.regions["qingshi_village"]["map"]["square"] = [1, 2]
	var errs := Scenery.validate(d)
	d.regions["qingshi_village"]["map"]["square"] = saved
	assert_true(errs.size() > 0, "square [1, 2] rejected")


func test_road_pieces_are_short_and_broken() -> void:
	var r := _qingshi()
	var counts: Array[int] = []
	for rect: Rect2 in [Rect2(0, 0, 60, 1000), Rect2(0, 0, 1000, 60)]:
		var n := 0
		for t in _pieces({"id": "t", "map": {}}, rect):
			if t["kind"] in ["edge", "rut"]:
				n += 1
				var rr: Rect2 = t["rect"]
				assert_true(maxf(rr.size.x, rr.size.y) <= 40.0, "piece too long")
		counts.append(n)
	assert_true(absf(float(counts[0] - counts[1])) <= 0.25 * float(maxi(counts[0], counts[1])), "piece counts alike: %s" % [counts])
	assert_true(r.has("map"))


func test_edges_have_gaps() -> void:
	var rect := Rect2(0, 0, 60, 1000)
	var spans: Array = []
	for t in _pieces({"id": "t", "map": {}}, rect):
		if t["kind"] == "edge" and (t["rect"] as Rect2).position.x < 30.0:
			spans.append(t["rect"])
	spans.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y < b.position.y)
	var window := 0
	var gaps := 0
	for i in range(1, spans.size()):
		if (spans[i] as Rect2).position.y > (spans[i - 1] as Rect2).end.y + 0.5:
			gaps += 1
	assert_true(gaps >= 1000 / 120, "edge strip has gaps (%d)" % gaps)
	assert_eq(window, 0)


func test_market_street_is_staggered() -> void:
	var region := {"id": "m", "map": {"ground_style": "paved", "market": {}}}
	var rect := Rect2(0, 0, 60, 1000)
	var starts := [[], []]
	for t in _pieces(region, rect):
		if t["kind"] == "slab":
			var rr: Rect2 = t["rect"]
			starts[0 if rr.position.x < 30.0 else 1].append(rr.position.y)
	var shared := 0
	for y in starts[0]:
		if starts[1].has(y):
			shared += 1
	assert_true(shared < starts[0].size() / 2, "joints do not line up")


## GFX-133: ragged outlines instead of straight-edged rectangles.
func _off_box(poly: PackedVector2Array, box: Rect2) -> bool:
	for v in poly:
		var d := minf(minf(absf(v.x - box.position.x), absf(v.x - box.end.x)), minf(absf(v.y - box.position.y), absf(v.y - box.end.y)))
		if d >= 4.0:
			return true
	return false


func test_square_outline_is_ragged_and_stable() -> void:
	var a := Scenery.village_square(_qingshi())
	var b := Scenery.village_square(_qingshi())
	assert_eq(a["blob"], b["blob"])
	assert_true(_off_box(a["blob"], a["rect"]), "square outline has a vertex >= 4 px off its box")
	assert_true((a["stones"] as Array).size() >= 3, "flagstones ring the tree")
	var keep: Array[Rect2] = []
	for pl: Dictionary in _qingshi()["places"]:
		keep.append(Npcs.place_keepout(pl))
	for st: Dictionary in a["stones"]:
		for k in keep:
			assert_false(k.intersects(st["rect"]), "flagstone over a place")


func test_yard_outline_is_ragged() -> void:
	var r := _qingshi()
	var s: Array = r["map"]["size"]
	var y := Scenery.village_yards(r, Vector2(float(s[0]), float(s[1])))
	assert_true((y["yards"] as Array).size() > 0)
	var ragged := 0
	for yd: Dictionary in y["yards"]:
		if _off_box(yd["outline"], yd["rect"]):
			ragged += 1
	assert_eq(ragged, (y["yards"] as Array).size())
