## GFX-112: Scenery.path_tiles lays road pieces deterministically inside the path rect, none on a bridge.
extends TestCase


func _region(style: String, water: String = "clear") -> Dictionary:
	return {"id": "r", "map": {"ground_style": style, "water": water, "landmarks": [{"kind": "stream", "pos": [400, 500], "size": [30, 1000]}]}}


func test_deterministic_and_inside() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	for style in ["grass", "scree", "paved", "bog", "litter"]:
		var a := Scenery.path_tiles(_region(style), rect)
		assert_true(a.size() > 5, style + " has tiles")
		assert_eq(a, Scenery.path_tiles(_region(style), rect), style + " deterministic")
		for t in a:
			assert_true(rect.grow(0.01).encloses(t["rect"]), style + " tile inside the path")


func test_kinds_by_style() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	assert_eq(Scenery.path_tiles(_region("scree"), rect)[0]["kind"], "slab")
	assert_eq(Scenery.path_tiles(_region("bog", "murky"), rect)[0]["kind"], "plank")
	var kinds := {}
	for t in Scenery.path_tiles(_region("bog"), rect):
		kinds[t["kind"]] = true
	assert_true(kinds.has("puddle") and kinds.has("rut"), "muddy track")


func test_nothing_on_bridge() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	var bridge := Rect2(385, 0, 30, 1000)
	for style in ["grass", "scree", "bog"]:
		for t in Scenery.path_tiles(_region(style), rect):
			assert_false(bridge.intersects(t["rect"]), style + " tile on bridge")


## GFX-124: walked earth: pebbles/footprints, rain puddles, winter-covered ruts, nothing under a place.
func test_walked_earth() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	var kinds := {}
	for t in Scenery.path_tiles(_region("grass"), rect):
		kinds[t["kind"]] = true
	assert_true(kinds.has("pebble") and kinds.has("print"), "pebbles and footprints")
	assert_false(kinds.has("puddle"), "dry day has no puddles")
	var wet := Scenery.path_tiles(_region("grass"), rect, "rain")
	var sky := 0
	for t in wet:
		if t["flag"] == "sky":
			sky += 1
			assert_true(rect.grow(0.01).encloses(t["rect"]), "puddle inside road")
	assert_true(sky > 0, "rain puddles")
	for t in Scenery.path_tiles(_region("grass"), rect, "rain", true):
		assert_false(t["kind"] == "puddle", "no puddles in snow")
	for t in Scenery.path_tiles(_region("grass"), rect, "clear", true):
		if t["kind"] == "rut":
			assert_eq(t["flag"], "slush", "winter ruts are slush")


func test_nothing_under_a_place() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	var reg := _region("grass")
	reg["places"] = [{"type": "merchant", "pos": [800, 500], "size": [200, 100]}]
	var k := Npcs.place_keepout(reg["places"][0])
	for t in Scenery.path_tiles(reg, rect, "rain"):
		if t["kind"] in ["pebble", "print", "puddle", "tuft"]:
			assert_false(k.intersects(t["rect"]), "decor under a place")


func test_market_props_keep_clear_and_are_seeded() -> void:
	var region: Dictionary = GameData.load_from_dir().regions["fallen_star_market"]
	var size := Vector2(region["map"]["size"][0], region["map"]["size"][1])
	var a := Scenery.market_props(region, size)
	var b := Scenery.market_props(region, size)
	assert_eq(a["props"].size(), b["props"].size(), "same seed same props")
	assert_true(a["props"].size() > 0, "stalls get props")
	assert_true(a["scorch"].size() > 0, "crater ring")
	var roads: Array[Rect2] = []
	for p in region["map"]["paths"]:
		roads.append(Rect2(p[0], p[1], p[2], p[3]))
	for list in [a["props"].map(func(q): return q["rect"]), a["patches"], a["cobbles"]]:
		for rect: Rect2 in list:
			for road in roads:
				assert_false(road.intersects(rect), "nothing on a road")
			for pl: Dictionary in region["places"]:
				assert_false(Npcs.place_keepout(pl).intersects(rect), "nothing in a place keepout")


func test_market_avenue_crater_plaza_and_clusters() -> void:
	var region: Dictionary = GameData.load_from_dir().regions["fallen_star_market"]
	var size := Vector2(region["map"]["size"][0], region["map"]["size"][1])
	var d := Scenery.market_props(region, size)
	var av: Rect2 = d["avenue"]
	assert_true(av.size.x >= 64.0 and av.size.x <= 80.0, "avenue 64-80 px wide")
	var gate := Rect2()
	for pl: Dictionary in region["places"]:
		if pl["type"] == "travel":
			gate = Npcs.place_keepout(pl)
	assert_true(av.grow(1.0).intersects(gate), "avenue touches the gate")
	var main := Rect2(0, 470, 1600, 60)
	assert_true(av.grow(1.0).intersects(main), "avenue touches the main street")
	assert_true(d["avenue_slabs"].size() > 20, "paved")
	assert_true(d["ring"].size() >= 8, "ragged ring")
	assert_true(d["shards"].size() >= 4 and d["shards"].size() <= 6, "4-6 star shards")
	assert_true(d["fence"].size() >= 1, "rope fence")
	var near := 0
	for q: Dictionary in d["props"]:
		if (q["rect"] as Rect2).grow(30.0).intersects(av):
			near += 1
	assert_true(near >= 4, "prop clusters along the avenue")
	var keep: Array[Rect2] = []
	for pl: Dictionary in region["places"]:
		if pl["type"] == "travel":
			continue
		if str(pl.get("look", "")) == "crater":  # shards ring it; only its rect + label band stay clear
			var cp := Vector2(pl["pos"][0], pl["pos"][1])
			var cs := Vector2(pl["size"][0], pl["size"][1])
			keep.append(Rect2(cp - cs / 2.0 - Vector2(0, 26), cs + Vector2(0, 26)))
		else:
			keep.append(Npcs.place_keepout(pl))
	var items: Array = d["shards"].duplicate()
	for f: Dictionary in d["fence"]:
		items.append_array(f["posts"])
	for r: Rect2 in items:
		for k in keep:
			assert_false(k.intersects(r), "shards and posts clear of places and labels")
