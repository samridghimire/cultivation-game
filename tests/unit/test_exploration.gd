extends TestCase


func test_world_data_loads_without_errors() -> void:
	assert_eq(data().load_errors.size(), 0, ", ".join(data().load_errors))
	assert_true(data().regions.has(data().start_region))


func test_every_region_is_reachable_from_start() -> void:
	var seen := {data().start_region: true}
	var queue := [data().start_region]
	while not queue.is_empty():
		for route: Dictionary in data().regions[queue.pop_front()].get("routes", []):
			if not seen.has(route["to"]):
				seen[route["to"]] = true
				queue.append(route["to"])
	assert_eq(seen.size(), data().regions.size())


func test_every_region_has_a_way_out() -> void:
	for region: Dictionary in data().regions.values():
		var has_travel := false
		for place: Dictionary in region.get("places", []):
			has_travel = has_travel or place["type"] == "travel"
		assert_true(has_travel, region["id"])


func test_travel_realm_gate() -> void:
	var c := new_character()
	c.realm_index = 0
	assert_false(Exploration.check_travel(c, data(), "misty_forest", "azure_peak")["ok"])
	c.realm_index = data().realm_index_of("qi_refining")
	var check := Exploration.check_travel(c, data(), "misty_forest", "azure_peak")
	assert_true(check["ok"])
	assert_gt(check["days"], 0)


func test_no_travel_without_route() -> void:
	var c := new_character()
	c.realm_index = data().realms.size() - 1
	assert_false(Exploration.check_travel(c, data(), "qingshi_village", "azure_peak")["ok"])


func test_encounters_respect_realm_and_flags() -> void:
	var c := new_character()
	c.realm_index = 0
	for entry in Exploration.eligible_encounters(c, data(), ["forest"], {}):
		assert_false(entry["encounter"]["id"] == "forest_wolf", "mortals should not meet mist wolves")
	var ids := []
	for entry in Exploration.eligible_encounters(c, data(), ["village"], {"met_old_man": true}):
		ids.append(entry["encounter"]["id"])
	assert_false(ids.has("village_old_man"))
	assert_true(ids.has("village_lost_coin"))


func test_fortune_shifts_weights() -> void:
	var lucky := new_character()
	lucky.attributes["fortune"] = 20
	var unlucky := new_character()
	unlucky.attributes["fortune"] = 0
	var w := func(c: CharacterData, id: String) -> float:
		for entry in Exploration.eligible_encounters(c, data(), ["village"], {}):
			if entry["encounter"]["id"] == id:
				return entry["weight"]
		return 0.0
	assert_gt(w.call(lucky, "village_lost_coin"), w.call(unlucky, "village_lost_coin"))
	assert_gt(w.call(unlucky, "village_boar"), w.call(lucky, "village_boar"))


func test_roll_is_deterministic_and_eligible() -> void:
	var c := new_character()
	var a := Exploration.roll_encounter(c, data(), ["village"], {}, seeded_rng(7))
	var b := Exploration.roll_encounter(c, data(), ["village"], {}, seeded_rng(7))
	assert_eq(a["id"], b["id"])
	assert_true(a["tags"].has("village"))
	assert_true(Exploration.roll_encounter(c, data(), ["no_such_tag"], {}, seeded_rng()).is_empty())


func test_resolve_applies_effects_and_clamps_losses() -> void:
	var c := new_character()
	c.inventory = {"spirit_stone": 2}
	var result := Exploration.resolve(c, data(), data().encounters["city_pickpocket"], {})
	assert_true(result["ok"])
	assert_eq(c.item_count("spirit_stone"), 0)
	var flags := {}
	result = Exploration.resolve(c, data(), data().encounters["village_old_man"], flags)
	assert_true(flags.get("met_old_man", false))
	assert_eq(result["enemy"], "")
	assert_eq(Exploration.resolve(c, data(), data().encounters["village_boar"], {})["enemy"], "wild_boar")



func test_deadly_lethal_foes_are_evaded() -> void:
	var c := new_character()
	c.realm_index = 0
	assert_true(Exploration.should_evade(c, data(), "cave_guardian"))
	assert_false(Exploration.should_evade(c, data(), "wild_boar"), "non-lethal foes are never evaded")
	c.realm_index = data().realm_index_of("core_formation")
	assert_false(Exploration.should_evade(c, data(), "cave_guardian"))


func test_every_encounter_enemy_exists() -> void:
	for e: Dictionary in data().encounters.values():
		if e.has("enemy"):
			assert_true(data().enemies.has(e["enemy"]), e["id"])


func test_every_explore_spot_has_encounters_at_its_lowest_realm() -> void:
	# A Qi Refining 1 cultivator (the realm most gated routes need) always finds something.
	var c := new_character()
	c.realm_index = 1
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			if place["type"] != "explore":
				continue
			var tags: Array = place.get("explore_tags", [])
			if tags.is_empty():
				tags = region.get("encounter_tags", [])
			assert_false(Exploration.eligible_encounters(c, data(), tags, {}).is_empty(), "%s: %s" % [region["id"], place["display_name"]])


func test_withered_bone_marsh_offers_both_paths() -> void:
	var marsh: Array = data().encounters.values().filter(func(e: Dictionary) -> bool: return (e.get("tags", []) as Array).has("marsh"))
	assert_true(marsh.size() >= 8, "8+ marsh encounters")
	var good := marsh.filter(func(e: Dictionary) -> bool: return int(e.get("effects", {}).get("alignment", 0)) > 0)
	var evil := marsh.filter(func(e: Dictionary) -> bool: return int(e.get("effects", {}).get("alignment", 0)) < 0)
	assert_true(good.size() >= 2 and evil.size() >= 2, "righteous and demonic options")
