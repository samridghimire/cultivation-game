## GFX-141: roads that are walked, not painted: wandering wheel tracks, ragged verges, an old-boards boardwalk.
extends TestCase


func _region(style: String = "grass", water: String = "clear") -> Dictionary:
	return {"id": "r", "map": {"ground_style": style, "water": water, "landmarks": []}}


func _offs(rect: Rect2, winter: bool) -> Array[float]:
	var out: Array[float] = []
	for t in Scenery.path_tiles(_region(), rect, "clear", winter):
		if t["kind"] == "rut":
			out.append(((t["rect"] as Rect2).get_center().y - rect.get_center().y) / rect.size.y)
	return out


func test_winter_ruts_sit_off_the_centre_on_both_sides() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	var offs := _offs(rect, true)
	var below := 0
	var above := 0
	for o in offs:
		assert_true(absf(o) >= 0.15, "rut off the centre line")
		if o < 0.0:
			above += 1
		else:
			below += 1
	assert_true(above > 3 and below > 3, "two tracks")


func test_ruts_are_not_evenly_dashed() -> void:
	var rect := Rect2(0, 470, 400, 60)
	var lens := {}
	for t in Scenery.path_tiles(_region(), rect):
		if t["kind"] == "rut":
			lens[snappedf((t["rect"] as Rect2).size.x, 0.01)] = true
	assert_true(lens.size() > 3, "varied dash lengths")


func test_road_verge_both_edges_deterministic_and_clear() -> void:
	var rect := Rect2(0, 470, 800, 60)
	var reg := _region()
	reg["places"] = [{"type": "merchant", "pos": [400, 440], "size": [100, 60]}]
	var a := Scenery.road_verge(rect, 7, reg)
	assert_eq(a, Scenery.road_verge(rect, 7, reg), "deterministic")
	var top := 0
	var bottom := 0
	var k := Npcs.place_keepout(reg["places"][0])
	for r in a:
		assert_false(k.intersects(r), "clear of the place")
		if r.get_center().y < rect.get_center().y:
			top += 1
		else:
			bottom += 1
	assert_true(top > 5 and bottom > 5, "both long edges")


func test_boardwalk_missing_boards_are_rare_and_never_adjacent() -> void:
	var rect := Rect2(0, 470, 1600, 60)
	var planks: Array = []
	for t in Scenery.path_tiles(_region("bog", "murky"), rect):
		if t["kind"] == "plank":
			planks.append(t)
	var missing := 0
	for i in planks.size():
		if planks[i]["flag"] == "missing":
			missing += 1
			if i > 0:
				assert_true(planks[i - 1]["flag"] != "missing", "no two in a row")
	assert_true(float(missing) <= float(planks.size()) / 12.0, "rare")
