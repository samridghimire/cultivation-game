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
