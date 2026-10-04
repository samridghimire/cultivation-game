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


func test_encounter_alignment_bounds() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("foundation_establishment")
	var ids := func() -> Array:
		return Exploration.eligible_encounters(c, data(), ["city"], {}).map(func(e): return e["encounter"]["id"])
	c.alignment = 0
	assert_false(ids.call().has("city_righteous_enforcer"), "enforcers leave neutral cultivators alone")
	c.alignment = -200
	assert_true(ids.call().has("city_righteous_enforcer"), "max_alignment is inclusive")
	c.alignment = -800
	assert_true(ids.call().has("city_righteous_enforcer"))
	var entry := {"min_alignment": 100, "max_alignment": 300}
	c.alignment = 99
	assert_false(Exploration.alignment_allows(c, entry))
	c.alignment = 100
	assert_true(Exploration.alignment_allows(c, entry))
	c.alignment = 301
	assert_false(Exploration.alignment_allows(c, entry))
	assert_true(Exploration.alignment_allows(c, {}))


func test_encounter_alignment_validation() -> void:
	var d := GameData.new()
	d.realms = data().realms
	d.items = data().items
	d.enemies = data().enemies
	d.encounters = {
		"ok": {"id": "ok", "min_alignment": -1000, "max_alignment": 0},
		"swapped": {"id": "swapped", "min_alignment": 200, "max_alignment": -200},
		"out": {"id": "out", "max_alignment": 5000},
		"text": {"id": "text", "min_alignment": "evil"},
		"choice": {"id": "choice", "choices": [{"label": "a", "requires": {"min_alignment": 1.5}}, {"label": "b"}]},
	}
	var errors := Exploration.validate_choices(d)
	assert_eq(errors.size(), 4, str(errors))
