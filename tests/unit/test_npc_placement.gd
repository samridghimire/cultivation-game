extends TestCase
## FAM-002f: generated NPCs are placed in the world (npc_spots, titles, Look).


func test_every_region_has_npc_spots_for_its_candidates() -> void:
	var per_region := int(data().family["eligible_npcs"]["per_gender"]) * Names.genders(data()).size()
	for region: Dictionary in data().regions.values():
		assert_true((region.get("npc_spots", []) as Array).size() >= per_region, "%s needs npc_spots" % region["id"])


func test_generated_in_region_is_sorted_and_skips_named_and_dead() -> void:
	var npcs := {}
	Npcs.ensure_all(npcs, data(), seeded_rng())
	var region := String(data().start_region)
	for i in 11:
		Npcs.spawn(npcs, data(), seeded_rng(i), {"region": region})
	var dead := Npcs.spawn(npcs, data(), seeded_rng(99), {"region": region})
	dead.alive = false
	var found := Npcs.generated_in_region(npcs, data(), region)
	assert_eq(found.size(), 11)
	for i in range(1, found.size()):
		assert_gt(int(found[i].id.trim_prefix(Npcs.SPAWN_PREFIX)), int(found[i - 1].id.trim_prefix(Npcs.SPAWN_PREFIX)), "natural id order")
	for c in found:
		assert_false(data().npcs.has(c.id))
		assert_true(c.alive)


func test_spot_positions_use_spots_then_ring() -> void:
	var spots := [[10, 20], [30, 40]]
	var pos := Npcs.spot_positions(4, spots, Vector2(500, 500))
	assert_eq(pos.size(), 4)
	assert_eq(pos[0], Vector2(10, 20))
	assert_eq(pos[1], Vector2(30, 40))
	assert_true(pos[2].distance_to(Vector2(500, 500)) > 100.0)
	assert_true(pos[2] != pos[3], "overflow NPCs do not stack")


func test_spot_positions_avoid_points() -> void:
	var center := Vector2(500, 500)
	var avoid: Array[Vector2] = []
	for k in 8:
		avoid.append(center + Vector2.from_angle(TAU * float(k) / 8.0) * 140.0)
	var plain := Npcs.spot_positions(5, [], center)
	assert_eq(plain, Npcs.spot_positions(5, [], center, []), "no avoid behaves as before")
	var pos := Npcs.spot_positions(10, [[10, 20]], center, avoid)
	assert_eq(pos.size(), 10, "count is honored")
	for i in range(1, pos.size()):
		for p in avoid:
			assert_true(pos[i].distance_to(p) >= Npcs.SPOT_CLEARANCE, "spot %d clear of avoid point" % i)
		for j in range(1, i):
			assert_true(pos[i].distance_to(pos[j]) >= Npcs.SPOT_CLEARANCE, "ring spots do not crowd")
	var crowded: Array[Vector2] = [center]
	assert_eq(Npcs.spot_positions(3, [], center, crowded).size(), 3, "count honored even when nothing is clear")


func test_world_title_and_describe() -> void:
	var player := new_character()
	player.gender = "male"
	var npcs := {}
	var she := Npcs.spawn(npcs, data(), seeded_rng(), {"gender": "female"})
	she.age_days = 20 * Calendar.DAYS_PER_YEAR
	assert_eq(Npcs.world_title(she, player, data()), Cultivation.realm_label(she, data()))
	assert_true(Npcs.describe(she, data()).contains("woman of 20"), Npcs.describe(she, data()))
	Family.marry(player, she, "wife")
	assert_eq(Npcs.world_title(she, player, data()), "Your Wife")
	var kid := Npcs.spawn(npcs, data(), seeded_rng(2), {"gender": "male"})
	kid.age_days = 3 * Calendar.DAYS_PER_YEAR
	assert_eq(Npcs.world_title(kid, player, data()), "Child")
	assert_true(Npcs.describe(kid, data()).contains("boy of 3"))
	player.children.append(kid.id)
	assert_eq(Npcs.world_title(kid, player, data()), "Your Son")


func _villager(id: String) -> CharacterData:
	var c := new_character(id.hash())
	c.id = id
	return c


func test_haunt_is_deterministic_and_changes_across_days() -> void:
	var region: Dictionary = data().regions[data().start_region]
	var moved := 0
	for i in 8:
		var c := _villager("npc_%d" % i)
		assert_eq(Npcs.haunt(c, region, 10), Npcs.haunt(c, region, 10))
		var seen := {}
		for day in 6:
			seen[Npcs.haunt(c, region, day)] = true
		if seen.size() > 1:
			moved += 1
	assert_gt(moved, 3, "most villagers rotate between haunts")


func test_haunt_place_agrees_with_haunt() -> void:
	var region: Dictionary = data().regions["qingshi_village"]
	for i in 20:
		var c := _villager("npc_%d" % i)
		for day in 5:
			var place := Npcs.haunt_place(c, region, day)
			assert_false(place.is_empty())
			var rect := Npcs._rect_of(place)
			var stand := Npcs.haunt(c, region, day)
			assert_true(stand.distance_to(rect.get_center()) < maxf(rect.size.x, rect.size.y) / 2.0 + Npcs.HAUNT_STAND_OFF + 1.0)


func test_activity_line_by_place_type() -> void:
	var c := _villager("npc_x")
	var cases := {
		"merchant": "browsing the stalls at the Shop", "workshop": "lending a hand at the Shop",
		"gather": "picking herbs on the Shop", "meditation": "sitting quietly by the Shop",
		"clinic": "waiting at the Shop", "well": "drawing water at the Shop",
		"orphanage": "playing near the Shop", "bounty_board": "about the Shop",
	}
	for t: String in cases:
		assert_eq(Npcs.activity_line(c, {"type": t, "display_name": "Shop"}), cases[t], t)
	assert_eq(Npcs.activity_line(c, {}), "")
	assert_eq(Npcs.activity_line(c, {"type": "well"}), "drawing water at the well")


func test_haunt_never_stands_in_a_solid_landmark_or_place() -> void:
	for region: Dictionary in data().regions.values():
		var solids := Scenery.landmark_rects(region, true)
		var rects: Array[Rect2] = []
		for p: Dictionary in region.get("places", []):
			rects.append(Npcs._rect_of(p))
		for i in 12:
			var c := _villager("npc_%d" % i)
			for adult in [true, false]:
				for day in 5:
					var pos := Npcs.haunt(c, region, day, adult)
					for r in solids + rects:
						assert_false(r.has_point(pos), "%s: %s on day %d inside %s" % [region["id"], c.id, day, r])


func test_haunt_children_stay_near_home_or_orphanage() -> void:
	var region: Dictionary = data().regions[data().start_region]
	var anchors: Array[Dictionary] = Npcs._haunt_anchors(region, false)
	assert_false(anchors.is_empty())
	for i in 6:
		var pos := Npcs.haunt(_villager("kid_%d" % i), region, 3, false)
		var near := false
		for a in anchors:
			if Npcs._rect_of(a).grow(Npcs.HAUNT_STAND_OFF + 80.0).has_point(pos):
				near = true
		assert_true(near, "child %d stays near the Family Home or orphanage" % i)


func _outdoor_swapped(region: Dictionary, weather: String) -> int:
	var swapped := 0
	for i in 30:
		var c := _villager("npc_%d" % i)
		for day in 6:
			var clear := Npcs.haunt_place(c, region, day)
			var wet := Npcs.haunt_place(c, region, day, true, weather)
			if clear != wet:
				swapped += 1
				assert_true(Npcs.HAUNT_OUTDOOR.has(String(clear["type"])), "only outdoor picks move")
				assert_true(Npcs.HAUNT_SHELTER_PLACES.has(String(wet["type"])), "to a sheltered place")
				assert_true(Npcs.is_sheltering(c, region, day, true, weather))
			else:
				assert_false(Npcs.is_sheltering(c, region, day, true, weather))
	return swapped


func test_rain_and_snow_send_villagers_indoors_clear_does_not() -> void:
	var region: Dictionary = data().regions["qingshi_village"]
	assert_gt(_outdoor_swapped(region, "rain"), 0)
	assert_gt(_outdoor_swapped(region, "snow"), 0)
	assert_eq(_outdoor_swapped(region, "clear"), 0)
	assert_eq(_outdoor_swapped(region, "fog"), 0)


func test_region_without_shelter_keeps_outdoor_pick() -> void:
	var region: Dictionary = data().regions["misty_forest"]
	assert_eq(_outdoor_swapped(region, "rain"), 0)


func test_sheltered_pick_is_stable_for_the_day() -> void:
	var region: Dictionary = data().regions["qingshi_village"]
	var c := _villager("npc_3")
	assert_eq(Npcs.haunt_place(c, region, 8, true, "rain"), Npcs.haunt_place(c, region, 8, true, "rain"))
	assert_eq(Npcs.haunt(c, region, 8, true, "rain"), Npcs.haunt(c, region, 8, true, "rain"))


func test_activity_line_sheltering_variants() -> void:
	var c := _villager("npc_x")
	var place := {"type": "workshop", "display_name": "Village Workshop"}
	assert_eq(Npcs.activity_line(c, place, "rain"), "sheltering from the rain at the Village Workshop")
	assert_eq(Npcs.activity_line(c, place, "snow"), "waiting out the snow at the Village Workshop")
	assert_eq(Npcs.activity_line(c, place), "lending a hand at the Village Workshop")


func test_villagers_at_one_place_stand_apart() -> void:
	var region: Dictionary = data().regions["qingshi_village"]
	var people: Array[CharacterData] = []
	for i in 25:
		people.append(_villager("npc_%d" % i))
	for weather in ["", "rain"]:
		for day in 4:
			var stands := Npcs.haunt_positions(people, region, day, 16, weather)
			assert_eq(stands.size(), people.size())
			assert_eq(stands, Npcs.haunt_positions(people, region, day, 16, weather), "deterministic")
			for a in people:
				for b in people:
					if a.id < b.id and Npcs.haunt_place(a, region, day, true, weather) == Npcs.haunt_place(b, region, day, true, weather):
						assert_true((stands[a.id] as Vector2).distance_to(stands[b.id]) >= Npcs.HAUNT_SPACING - 0.01, "%s/%s day %d" % [a.id, b.id, day])


## [REVIEW] Look's "Today they are ..." line is only for villagers on a daily round, not named NPCs or the family at home.
func test_keeps_round_skips_named_npcs_family_and_other_regions() -> void:
	var npcs := {}
	Npcs.ensure_all(npcs, data(), seeded_rng())
	var home_region := ""
	for region: Dictionary in data().regions.values():
		if region.has("family_home"):
			home_region = String(region["id"])
			break
	assert_true(home_region != "", "some region has a family_home")
	var player := new_character()
	var villager := Npcs.spawn(npcs, data(), seeded_rng(1), {"region": home_region})
	assert_true(Npcs.keeps_round(villager, player, npcs, data(), home_region))
	var other := ""
	for region_id: String in data().regions:
		if region_id != home_region:
			other = region_id
			break
	assert_false(Npcs.keeps_round(villager, player, npcs, data(), other), "not in its region")
	var named_id: String = data().npcs.keys()[0]
	var named: CharacterData = npcs[named_id]
	assert_false(Npcs.keeps_round(named, player, npcs, data(), Npcs.region_of(named, data())), "named NPC")
	player.spouses.append(villager.id)
	assert_false(Npcs.keeps_round(villager, player, npcs, data(), home_region), "family stands by the Family Home")
