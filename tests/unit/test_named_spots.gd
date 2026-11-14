extends TestCase
## SPOT-002: hand-placed named folk keep off road crossings, the arrival point and entrances, and each other.

const REGIONS: PackedStringArray = ["qingshi_village", "withered_bone_marsh", "misty_forest"]


func _stands(region_id: String, day: int, weather: String) -> Dictionary:
	var region: Dictionary = data().regions[region_id]
	var stands := {}
	for id: String in data().npcs:
		var def: Dictionary = data().npcs[id]
		if String(def.get("region", "")) != region_id:
			continue
		var pos: Vector2 = Folk.spot_for(data(), def, day, weather, [])["pos"]
		stands[id] = Npcs.settle_stand(pos, region, true)
	return Npcs.settle_named(stands, region)


func test_named_folk_are_legal_in_the_first_hour_regions() -> void:
	for region_id in data().regions:
		var region: Dictionary = data().regions[region_id]
		var arrivals := Npcs.arrival_points(region)
		var crossings := Npcs.road_crossings(region)
		for day in [0, 3, 6, 9]:
			for weather in ["clear", "rain"]:
				var stands := _stands(region_id, day, weather)
				var ids: Array = stands.keys()
				for i in ids.size():
					var p: Vector2 = stands[ids[i]]
					for a in arrivals:
						assert_true(p.distance_to(a) >= Npcs.NAMED_ARRIVAL_CLEAR, "%s %s near arrival" % [region_id, ids[i]])
					for r in crossings:
						assert_false(r.has_point(p), "%s %s on a crossing" % [region_id, ids[i]])
					for j in range(i + 1, ids.size()):
						assert_true(p.distance_to(stands[ids[j]]) >= Npcs.HAUNT_SPACING, "%s %s and %s crowd" % [region_id, ids[i], ids[j]])


func test_legal_spot_is_kept_and_illegal_one_moves() -> void:
	var region: Dictionary = data().regions["qingshi_village"]
	var legal := Vector2(200, 200)
	var spawn := Npcs.arrival_points(region)[0]
	var out := Npcs.settle_named({"a": legal, "b": spawn}, region)
	assert_eq(out["a"], legal)
	assert_true((out["b"] as Vector2).distance_to(spawn) >= Npcs.NAMED_ARRIVAL_CLEAR)


func test_crossing_is_found_in_qingshi() -> void:
	assert_eq(Npcs.road_crossings(data().regions["qingshi_village"]).size(), 1)
