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
