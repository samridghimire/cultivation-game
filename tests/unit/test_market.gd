extends TestCase
## GFX-119: a market that bustles: MarketLayout is seeded, inside the map and clear of places, paths and the spawn.


func _market() -> Dictionary:
	return GameData.load_from_dir().regions["fallen_star_market"]


func test_validates_and_rejects_bad_market() -> void:
	var data := GameData.load_from_dir()
	assert_eq(Scenery.validate(data).size(), 0)
	data.regions["fallen_star_market"]["map"]["market"] = {"stalls": 99, "bogus": 1, "carts": "x"}
	assert_eq(Scenery.validate(data).size(), 3)


func test_layout_seeded_and_populated() -> void:
	var r := _market()
	var a := MarketLayout.layout(r)
	assert_eq(a, MarketLayout.layout(r))
	assert_true((a["stalls"] as Array).size() >= 6, "enough stalls fit")
	assert_true((a["fronts"] as Array).size() >= 4)
	assert_true((a["strings"] as Array).size() >= 2)


func test_layout_inside_map_and_clear() -> void:
	var r := _market()
	var a := MarketLayout.layout(r)
	var map := Rect2(Vector2.ZERO, Vector2(1600, 1000))
	var paths: Array[Rect2] = []
	for p in r["map"]["paths"]:
		paths.append(Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3])))
	var rects: Array[Rect2] = []
	for s: Dictionary in a["stalls"]:
		rects.append(s["rect"])
	for c: Dictionary in a["carts"]:
		rects.append(c["rect"])
	for i in rects.size():
		assert_true(map.encloses(rects[i]), "inside the map")
		for pl: Dictionary in r["places"]:
			var sz := Vector2(float(pl["size"][0]), float(pl["size"][1]))
			var pr := Rect2(Vector2(float(pl["pos"][0]), float(pl["pos"][1])) - sz / 2.0, sz)
			assert_false(pr.intersects(rects[i]), "clear of %s" % pl["display_name"])
		for pr in paths:
			assert_false(pr.intersects(rects[i]), "off the road")
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]), "no overlap")
		assert_false(rects[i].has_point(Vector2(float(r["spawn"][0]), float(r["spawn"][1]))))


func test_other_regions_have_no_market() -> void:
	var r: Dictionary = GameData.load_from_dir().regions["qingshi_village"]
	assert_true((MarketLayout.layout(r)["stalls"] as Array).is_empty())


func test_shoppers_walk_between_fronts_and_stand_still_when_reduced() -> void:
	var fronts: Array = MarketLayout.layout(_market())["fronts"]
	assert_eq(MarketLayout.shopper_pos(fronts, "m", 3, 0, 0.0, true), MarketLayout.shopper_pos(fronts, "m", 3, 0, 0.0, true))
	assert_eq(MarketLayout.shopper_pos(fronts, "m", 3, 0, 0.0, false), MarketLayout.shopper_pos(fronts, "m", 3, 0, 500.0, false))
	var moved := false
	for t in range(0, 120, 3):
		if MarketLayout.shopper_pos(fronts, "m", 3, 0, float(t), true) != MarketLayout.shopper_pos(fronts, "m", 3, 0, 0.0, true):
			moved = true
	assert_true(moved, "the shopper strolls")
	assert_eq(MarketLayout.shopper_pos([], "m", 1, 0, 5.0, true), Vector2.ZERO)


func test_market_life_draws_in_both_seasons() -> void:
	var node := MarketLife.new()
	for season in ["Summer", "Winter"]:
		node.setup(_market(), season, "rain", 4, false)
		assert_eq(node.get_child_count(), 0)
	node.free()


## WU-521: the lantern string is much darker than the lantern dot so both read at 1x.
func test_lantern_string_contrast() -> void:
	assert_true(MarketLife.LANTERN_RED.get_luminance() - MarketLife.STRING_COLOR.get_luminance() > 0.2)
	assert_true(MarketLife.LANTERN_CORE.get_luminance() > MarketLife.LANTERN_RED.get_luminance())


## GFX-138: the market's crate clusters are spread out, the scorch is a ragged outline and the fence has a south run.
func test_market_dress_loose_ends() -> void:
	var r: Dictionary = data().regions["fallen_star_market"]
	var s: Array = r["map"]["size"]
	var d := Scenery.market_props(r, Vector2(float(s[0]), float(s[1])))
	for sc: Dictionary in d["scorch"]:
		assert_eq((sc["outlines"] as Array).size(), 5)
		var o: PackedVector2Array = sc["outlines"][0]
		var lo := 1e9
		var hi := 0.0
		for p in o:
			lo = minf(lo, p.distance_to(sc["center"]))
			hi = maxf(hi, p.distance_to(sc["center"]))
		assert_true(hi - lo > 1.0, "scorch outline is not a circle")
	var av: Rect2 = d["avenue"]
	var ys: Array[float] = []
	for p: Dictionary in d["props"]:
		var rc: Rect2 = p["rect"]
		if rc.position.x > av.position.x - 30.0 and rc.end.x < av.end.x + 30.0 and rc.position.y >= av.position.y:
			ys.append(rc.position.y)
	ys.sort()
	var groups := 0
	var last := -1e9
	for y in ys:
		if y - last >= 100.0:
			groups += 1
		last = y
	assert_true(groups >= 2, "avenue crates form >= 2 separate clusters: %s" % [ys])
	var south := 0
	var cy: float = (r["places"] as Array).filter(func(p: Dictionary) -> bool: return str(p.get("look", "")) == "crater")[0]["pos"][1]
	for f: Dictionary in d["fence"]:
		var first: Rect2 = f["posts"][0]
		if first.position.y > cy + 40.0:
			south += 1
	assert_true(south >= 1, "south fence run")


## GFX-155: earth dressing between the streets is deterministic and keeps off roads, places and the avenue.
func test_market_earth_dress() -> void:
	var r: Dictionary = data().regions["fallen_star_market"]
	var size := Vector2(float(r["map"]["size"][0]), float(r["map"]["size"][1]))
	var d := Scenery.market_props(r, size)
	var d2 := Scenery.market_props(r, size)
	assert_eq((d["loose_flags"] as Array).size(), (d2["loose_flags"] as Array).size(), "deterministic")
	assert_true((d["loose_flags"] as Array).size() > 40, "loose flags are scattered")
	var tilted := 0
	var roads: Array[Rect2] = []
	for pr in r["map"]["paths"]:
		roads.append(Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3])))
	for f: Dictionary in d["loose_flags"]:
		var fr: Rect2 = f["rect"]
		if f["tilt"]:
			tilted += 1
		assert_false((d["avenue"] as Rect2).intersects(fr), "no loose flag on the avenue")
		for rd in roads:
			assert_false(rd.intersects(fr), "no loose flag on a street")
		for pl: Dictionary in r["places"]:
			assert_false(Npcs.place_keepout(pl).intersects(fr), "no loose flag on a place")
	assert_true(tilted > 0 and tilted < (d["loose_flags"] as Array).size() / 2, "some flags tilt")
	assert_true((d["ruts"] as Array).size() >= 2, "cart ruts join the avenue")
	assert_true((d["kerbs"] as Array).size() > 10, "streets have kerb stones")


## GFX-174: flagstone courts and cobbled lanes stay inside the region, off the crater bowl and clear of the avenue; packed earth hugs edges.
func test_market_courts_and_lanes() -> void:
	var r: Dictionary = data().regions["fallen_star_market"]
	var size := Vector2(float(r["map"]["size"][0]), float(r["map"]["size"][1]))
	var d := Scenery.market_props(r, size)
	assert_true((d["courts"] as Array).size() >= 4, "a court per hall")
	assert_true((d["lanes"] as Array).size() >= 1, "lanes join stalls to the streets")
	var crater := Rect2()
	for pl: Dictionary in r["places"]:
		if str(pl.get("look", "")) == "crater":
			var cs: Array = pl["size"]
			crater = Rect2(Vector2(float(pl["pos"][0]) - float(cs[0]) * 0.5, float(pl["pos"][1]) - float(cs[1]) * 0.5), Vector2(float(cs[0]), float(cs[1])))
	var bounds := Rect2(Vector2.ZERO, size)
	for key in ["courts", "lanes"]:
		for fr: Rect2 in d[key]:
			assert_true(bounds.encloses(fr), "%s inside the region" % key)
	for fr: Rect2 in d["lanes"]:
		assert_false(crater.intersects(fr), "lane avoids the crater")
		assert_false((d["avenue"] as Rect2).intersects(fr), "lane avoids the avenue")
	for pt: Rect2 in d["patches"]:
		for fr: Rect2 in (d["courts"] as Array) + (d["lanes"] as Array):
			assert_false(fr.intersects(pt), "earth never under paving")
