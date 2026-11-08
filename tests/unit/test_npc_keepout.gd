extends TestCase
## WU-484: nobody stands on a roof, a gate name board or a building's keepout.


func _in_keepout(pos: Vector2, region: Dictionary, allow_stalls: bool) -> bool:
	for p: Dictionary in region.get("places", []):
		if not String(p.get("type", "")) in Npcs.BUILDING_TYPES:
			continue
		if allow_stalls and float((p.get("size", [64, 64]) as Array)[0]) < 110.0:
			continue
		if Npcs.place_keepout(p).has_point(pos):
			return true
	return false


func test_place_keepout_buildings_are_bigger_than_rects() -> void:
	var shop := {"type": "merchant", "pos": [500, 500], "size": [100, 80]}
	var r := Rect2(450, 460, 100, 80)
	assert_true(Npcs.place_keepout(shop).encloses(r.grow(20)))
	var spot := {"type": "gather", "pos": [500, 500], "size": [100, 80]}
	assert_eq(Npcs.place_keepout(spot), r.grow(24.0))


func test_door_is_south_of_the_keepout_centre() -> void:
	var shop := {"type": "merchant", "pos": [500, 500], "size": [120, 80]}
	var k := Npcs.place_keepout(shop)
	assert_eq(Npcs.door_of(shop), Vector2(500, k.end.y + 10.0))
	assert_false(k.has_point(Npcs.door_of(shop)))


func test_settle_stand_door_rule_and_narrow_stalls() -> void:
	var region := {"places": [{"type": "merchant", "pos": [500, 500], "size": [120, 80]}, {"type": "merchant", "pos": [900, 500], "size": [70, 60]}]}
	assert_eq(Npcs.settle_stand(Vector2(500, 480), region, true), Npcs.door_of(region["places"][0]))
	assert_eq(Npcs.settle_stand(Vector2(900, 500), region, true), Vector2(900, 500), "narrow stall keeps its spot")
	assert_false(Npcs.place_keepout(region["places"][0]).has_point(Npcs.settle_stand(Vector2(500, 480), region, false)))


func test_nobody_stands_in_a_building_or_gate_in_any_region() -> void:
	var bad: Array[String] = []
	for rid: String in data().regions:
		var region: Dictionary = data().regions[rid]
		var gate := SectCourt.gate(region)
		var keep_gate := Rect2()
		if not gate.is_empty():
			keep_gate = SectCourt.gate_rect(gate).grow(SectCourt.GATE_KEEP)
		var named: Array = data().npcs.values().filter(func(d: Dictionary) -> bool: return String(d.get("region", "")) == rid)
		for day in 28:
			var stands: Array = []
			for d: Dictionary in named:
				stands.append([d["id"], SectCourt.settle_stand(Folk.spot_for(data(), d, day, "", [])["pos"], region, true), true])
			for i in 8:
				var c := CharacterData.new()
				c.id = "walker_%d" % i
				var pos := Npcs.haunt(c, region, day, i % 4 != 0, "")
				if pos != Vector2.ZERO:
					stands.append([c.id, SectCourt.settle_stand(pos, region, false), false])
			for s: Array in stands:
				if _in_keepout(s[1], region, s[2]) or (not gate.is_empty() and keep_gate.has_point(s[1])):
					bad.append("%s %s day %d at %s" % [rid, s[0], day, s[1]])
	assert_eq(bad.size(), 0, "stands on buildings or gates: " + "; ".join(bad.slice(0, 6)))


## WU-489: SectCourt.place_footprint and Npcs.place_keepout share one set of building numbers.
func test_footprint_and_keepout_agree_for_every_building_kind() -> void:
	for kind: String in Npcs.BUILDING_TYPES:
		var place := {"type": kind, "pos": [640, 400], "size": [110, 90]}
		assert_eq(SectCourt.place_footprint(place), Npcs.place_keepout(place), kind)
