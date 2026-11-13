## SPOT-001: villagers spread over a region's places instead of crowding one clump.
extends TestCase


func _people(n: int) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for i in n:
		var c := CharacterData.new()
		c.id = "npc_%d" % i
		c.name = c.id
		c.age_days = 30 * Calendar.DAYS_PER_YEAR
		out.append(c)
	return out


func test_no_place_has_more_than_two_adults() -> void:
	var bad: Array[String] = []
	for rid: String in data().regions:
		var region: Dictionary = data().regions[rid]
		for day in [1, 10, 40]:
			for weather in ["", "snow"]:
				var places := Npcs.haunt_places(_people(12), region, day, 16, weather)
				var counts := {}
				for id: String in places:
					var pl: Dictionary = places[id]
					if pl.is_empty():
						continue
					var k := Npcs._place_key(pl)
					counts[k] = int(counts.get(k, 0)) + 1
					if int(counts[k]) > Npcs.HAUNT_MAX_PER_PLACE:
						bad.append("%s day %d %s" % [rid, day, k])
	assert_eq(bad.size(), 0, "; ".join(bad.slice(0, 5)))


func test_villagers_keep_apart_and_off_the_entrance() -> void:
	var bad: Array[String] = []
	for rid: String in data().regions:
		var region: Dictionary = data().regions[rid]
		var arrivals := Npcs.arrival_points(region)
		for day in [1, 10, 40]:
			var stands := Npcs.haunt_positions(_people(10), region, day, 16)
			var list: Array[Vector2] = []
			for id: String in stands:
				list.append(Npcs.settle_stand(stands[id], region, false))
			list = Npcs.spread_stands(list, region)
			for i in list.size():
				for a in arrivals:
					if list[i].distance_to(a) < 120.0 - 0.01:
						bad.append("%s d%d #%d near entrance" % [rid, day, i])
				for j in i:
					if list[i].distance_to(list[j]) < 36.0:
						bad.append("%s d%d #%d/#%d crowd" % [rid, day, i, j])
	assert_eq(bad.size(), 0, "; ".join(bad.slice(0, 6)))


func test_spread_is_deterministic() -> void:
	var region: Dictionary = data().regions["withered_bone_marsh"]
	assert_eq(Npcs.haunt_positions(_people(10), region, 10, 16), Npcs.haunt_positions(_people(10), region, 10, 16))


func test_spot_positions_keep_56px() -> void:
	var out := Npcs.spot_positions(4, [[100, 100], [120, 100], [400, 400]], Vector2(300, 300), [Vector2(400, 410)])
	for i in out.size():
		for j in i:
			assert_true(out[i].distance_to(out[j]) >= Npcs.SPOT_MIN_GAP - 0.01, "%s %s" % [out[i], out[j]])
		assert_true(out[i].distance_to(Vector2(400, 410)) >= Npcs.SPOT_MIN_GAP - 0.01)


## [REVIEW] SPOT-001: an overflow villager's place (what their "browsing the stalls at X" line reads) is the capped one,
## and a shared (mediated) place is kept as given.
func test_haunt_places_report_the_overflow_place_and_keep_shared() -> void:
	var region: Dictionary = data().regions["qingshi_village"]
	var people := _people(12)
	var moved := 0
	for day in [1, 10, 40]:
		var places := Npcs.haunt_places(people, region, day, 16)
		for c in people:
			var usual := Npcs.haunt_place(c, region, day, true)
			if not usual.is_empty() and places[c.id] != usual:
				moved += 1
	assert_true(moved > 0, "12 villagers in Qingshi should overflow at least one place")
	var shared_place: Dictionary = Npcs.haunt_place(people[0], region, 1, true)
	var got := Npcs.haunt_places(people, region, 1, 16, "", "", {}, {people[5].id: shared_place})
	assert_eq(got[people[5].id], shared_place)
