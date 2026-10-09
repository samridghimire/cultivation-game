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


func test_encounter_min_stage_gates_within_min_realm() -> void:
	var d := GameData.load_from_dir()
	d.encounters["stage_test"] = {"id": "stage_test", "tags": ["stage_tag"], "weight": 1, "min_realm": "qi_refining", "min_stage": 4}
	var c := new_character()
	c.realm_index = d.realm_index_of("qi_refining")
	c.stage = 3
	assert_eq(Exploration.eligible_encounters(c, d, ["stage_tag"], {}).size(), 0)
	c.stage = 4
	assert_eq(Exploration.eligible_encounters(c, d, ["stage_tag"], {}).size(), 1)
	c.realm_index = d.realm_index_of("foundation_establishment")
	c.stage = 0
	assert_eq(Exploration.eligible_encounters(c, d, ["stage_tag"], {}).size(), 1)


func test_encounter_min_stage_is_validated() -> void:
	var d := GameData.load_from_dir()
	var before := d.load_errors.size()
	d.encounters["bad_a"] = {"id": "bad_a", "tags": ["x"], "min_stage": 1}
	d.encounters["bad_b"] = {"id": "bad_b", "tags": ["x"], "min_realm": "qi_refining", "min_stage": 99}
	d._validate_world()
	var text := ", ".join(d.load_errors)
	assert_true(text.contains("'bad_a' has min_stage without min_realm"), text)
	assert_true(text.contains("'bad_b' has min_stage 99 outside"), text)
	assert_eq(d.load_errors.size(), before + 2, text)


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


func test_gather_entries_below_min_realm_find_nothing() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("qi_refining")
	var table := [
		{"item": "dew_grass", "weight": 1, "min": 1, "max": 1},
		{"item": "nine_leaf_soul_grass", "weight": 3, "min": 1, "max": 1, "min_realm": "foundation_establishment"},
	]
	var filtered := Exploration.gather_table_for(c, data(), table)
	assert_eq(filtered.size(), 2)
	assert_eq(String(filtered[1]["item"]), "", "locked entry becomes nothing")
	assert_eq(float(filtered[1]["weight"]), 3.0, "odds of the other finds stay the same")
	assert_eq(Exploration.locked_gather_count(c, data(), table), 1)
	for seed_value in 5:
		var found := Exploration.gather(c, filtered, seeded_rng(seed_value))
		assert_false(found.has("nine_leaf_soul_grass"))
	c.realm_index = data().realm_index_of("foundation_establishment")
	assert_eq(Exploration.locked_gather_count(c, data(), table), 0)
	assert_eq(String(Exploration.gather_table_for(c, data(), table)[1]["item"]), "nine_leaf_soul_grass")


func test_high_grade_herbs_are_realm_gated_in_gather_tables() -> void:
	var gated := {}
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			for entry: Dictionary in place.get("gather_table", []):
				if entry.get("item", "") in ["nine_leaf_soul_grass", "earth_marrow_fungus", "golden_core_lotus_seed"]:
					assert_true(entry.has("min_realm"), "%s needs a min_realm" % entry["item"])
					gated[entry["item"]] = true
	assert_eq(gated.size(), 3, "all three C-007 herbs can be gathered")


func test_encounter_alignment_bounds() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.stage = 2  # city_righteous_enforcer has min_stage 2 (C-015)
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


func test_is_nearby() -> void:
	var d := data()
	assert_true(Exploration.is_nearby(d, "qingshi_village", "qingshi_village"))
	assert_true(Exploration.is_nearby(d, "qingshi_village", "misty_forest"), "direct route")
	assert_true(Exploration.is_nearby(d, "qingshi_village", ""), "realm-wide")
	assert_false(Exploration.is_nearby(d, "qingshi_village", "azure_peak"), "not a direct route")


func _outlook_data() -> GameData:
	var d := GameData.load_from_dir()
	d.encounters.clear()
	d.encounters["o_fight"] = {"id": "o_fight", "tags": ["ot"], "weight": 2, "kind": "misfortune", "enemy": "mountain_bandit"}
	d.encounters["o_fight2"] = {"id": "o_fight2", "tags": ["ot"], "weight": 1, "kind": "misfortune", "enemy": "mountain_bandit"}
	d.encounters["o_gift"] = {"id": "o_gift", "tags": ["ot"], "weight": 1, "kind": "neutral"}
	d.encounters["o_late"] = {"id": "o_late", "tags": ["ot"], "weight": 5, "kind": "misfortune", "min_realm": "qi_refining", "min_stage": 4, "enemy": "mist_wolf"}
	return d


func test_outlook_shares_sum_to_one_and_dedupe_foes() -> void:
	var d := _outlook_data()
	var c := new_character()
	var o := Exploration.outlook(c, d, ["ot"], {})
	var sum: float = o["fight"] + o["choice"] + o["fortune"] + o["misfortune"] + o["other"]
	assert_almost_eq(sum, 1.0)
	var pool := Exploration.eligible_encounters(c, d, ["ot"], {})
	var weights := 0.0
	for entry in pool:
		weights += entry["weight"]
	assert_almost_eq(float(o["fight"]), (pool[0]["weight"] + pool[1]["weight"]) / weights)
	assert_eq(o["foes"].size(), 1)
	assert_eq(o["foes"][0]["name"], "Mountain Bandit")


func test_outlook_min_stage_fight_is_absent_below_its_stage() -> void:
	var d := _outlook_data()
	var c := new_character()
	c.realm_index = d.realm_index_of("qi_refining")
	c.stage = 3
	assert_eq(Exploration.outlook(c, d, ["ot"], {})["foes"].size(), 1)
	c.stage = 4
	assert_eq(Exploration.outlook(c, d, ["ot"], {})["foes"].size(), 2)


func test_outlook_with_no_encounters_is_quiet() -> void:
	var o := Exploration.outlook(new_character(), _outlook_data(), ["nothing_here"], {})
	assert_almost_eq(float(o["other"]), 1.0)
	assert_eq(Guidance.outlook_text(o), "Mostly quiet (100%).")


func test_outlook_text_reads_cleanly() -> void:
	var o := Exploration.outlook(new_character(), _outlook_data(), ["ot"], {})
	var text := Guidance.outlook_text(o)
	assert_true(text.contains("Fights %d%%: Mountain Bandit (" % roundi(float(o["fight"]) * 100)))
	assert_false(text.contains("{") or text.contains("%s") or text.contains("%d"))


## RV-009: every gather place yields something on at least half the rolls for a
## newcomer (locked min_realm entries count as misses), so trips are not empty.
func test_every_gather_place_finds_something_at_least_half_the_rolls() -> void:
	var c := new_character()
	var checked := 0
	for region: Dictionary in data().regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") != "gather":
				continue
			var table := Exploration.gather_table_for(c, data(), place.get("gather_table", []))
			var total := 0.0
			var found := 0.0
			for entry: Dictionary in table:
				total += float(entry.get("weight", 1))
				if String(entry.get("item", "")) != "":
					found += float(entry.get("weight", 1))
			assert_true(found / maxf(total, 0.001) >= 0.5, "%s: a roll finds something >= 50%% of the time (%.2f)" % [place.get("display_name", "?"), found / maxf(total, 0.001)])
			checked += 1
	assert_gt(checked, 0, "gather places checked")


## C-029: quiet days have deterministic flavour lines.
func test_quiet_line_is_stable_per_day_and_varies() -> void:
	var d := data()
	var region_id := "misty_forest"
	assert_true(((d.regions[region_id]["quiet_lines"]) as Array).size() >= 2)
	var today := Exploration.quiet_line(d, region_id, 100)
	assert_true(today != "")
	assert_eq(Exploration.quiet_line(d, region_id, 100), today)
	assert_true(Exploration.quiet_line(d, region_id, 101) != today)
	assert_eq(Exploration.quiet_line(d, "no_such_region", 5), "")
	for region: Dictionary in d.regions.values():
		assert_true((region.get("quiet_lines", []) as Array).size() >= 6, "%s needs quiet lines" % region["id"])


# --- SEASON-001: seasonal herbs and encounters ---------------------------------

func test_out_of_season_gather_entry_never_rolls() -> void:
	var c := new_character()
	var table := [
		{"item": "dew_grass", "weight": 1, "min": 1, "max": 1},
		{"item": "spirit_herb", "weight": 5, "min": 1, "max": 1, "seasons": ["spring"]},
	]
	var winter := Exploration.gather_table_for(c, data(), table, "Winter")
	assert_eq(winter.size(), 1)
	for seed_value in 200:
		assert_false(Exploration.gather(c, winter, seeded_rng(seed_value)).has("spirit_herb"))
	var spring := Exploration.gather_table_for(c, data(), table, "Spring")
	assert_eq(spring.size(), 2)
	var seen := false
	for seed_value in 200:
		seen = seen or Exploration.gather(c, spring, seeded_rng(seed_value)).has("spirit_herb")
	assert_true(seen)
	assert_eq(Exploration.gather_table_for(c, data(), table).size(), 2, "'' ignores seasons")


func test_out_of_season_encounter_is_never_eligible() -> void:
	var d := GameData.load_from_dir()
	d.encounters = {"snow": {"id": "snow", "tags": ["st"], "weight": 1, "kind": "neutral", "text": "Snow.", "seasons": ["winter"]}}
	var c := new_character()
	assert_eq(Exploration.eligible_encounters(c, d, ["st"], {}, null, 1.0, "Summer").size(), 0)
	assert_true(Exploration.roll_encounter(c, d, ["st"], {}, seeded_rng(), null, 1.0, "Summer").is_empty())
	assert_eq(Exploration.eligible_encounters(c, d, ["st"], {}, null, 1.0, "Winter").size(), 1)
	assert_eq(Exploration.eligible_encounters(c, d, ["st"], {}).size(), 1, "'' ignores seasons")
	assert_eq(Exploration.outlook(c, d, ["st"], {}, "Summer")["other"], 1.0)


func test_season_validator_rejects_unknown_season() -> void:
	var d := GameData.load_from_dir()
	assert_true(d.load_errors.is_empty())
	d._validate_seasons({"seasons": ["monsoon"]}, "Test")
	assert_eq(d.load_errors.size(), 1)
	d._validate_seasons({"seasons": []}, "Test")
	assert_eq(d.load_errors.size(), 2)
	d._validate_seasons({"seasons": ["spring", "winter"]}, "Test")
	assert_eq(d.load_errors.size(), 2)


func test_qingshi_herb_slope_has_a_spring_only_entry_and_sources_say_so() -> void:
	var slope: Array = []
	for place: Dictionary in data().regions["qingshi_village"]["places"]:
		if place.get("display_name", "") == "Village Herb Slope":
			slope = place["gather_table"]
	var spring_entries := slope.filter(func(e: Dictionary) -> bool: return e.has("seasons"))
	assert_eq(spring_entries.size(), 1)
	assert_eq(spring_entries[0]["seasons"], ["spring"])
	assert_true(Items.sources(data(), "spirit_herb").has("Gathered at Village Herb Slope (Qingshi Village)"), "year-round entry too: no note")


# --- SEASON-002: in season now ---------------------------------------------------

func test_seasonal_highlights_by_season() -> void:
	var spring := Exploration.seasonal_highlights(data(), "spring")
	assert_true(spring.any(func(h: Dictionary) -> bool: return h["item"] == "spirit_herb" and h["region"] == "qingshi_village"))
	var autumn := Exploration.seasonal_highlights(data(), "autumn")
	assert_false(autumn.any(func(h: Dictionary) -> bool: return h["item"] == "spirit_herb" and h["region"] == "qingshi_village"))
	assert_eq(Exploration.seasonal_highlights(data(), "").size(), 0)


func test_season_news_only_when_season_changes() -> void:
	var c := new_character()
	var line := Exploration.season_news(c, data(), 89, 90)
	assert_eq(Exploration.season_news(c, data(), 10, 11), "", "same season")
	assert_eq(Exploration.season_news(c, data(), -1, 5), "", "no negative days")
	assert_eq(line == "", Exploration.seasonal_highlights(data(), "summer").is_empty())
	var spring := Exploration.season_news(c, data(), 359, 360)
	assert_true(spring.begins_with("Spring has come. In season now: "), spring)
	assert_true(spring.ends_with("."))
	assert_true(spring.count(";") <= 2)


# --- TRAV-005: first-exploration discovery ---------------------------------------

func test_discovery_only_encounters_never_roll_and_validate() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	var rng := seeded_rng(5)
	for i in 100:
		assert_true(Exploration.roll_encounter(c, d, ["forest"], {}, rng).get("id", "") != "misty_forest_hollow_shrine")
	assert_eq(Exploration.discovery_for(c, d, "misty_forest", {}).get("id", ""), "misty_forest_hollow_shrine")
	assert_true(Exploration.discovery_for(c, d, "misty_forest", {"discovered_misty_forest": true}).is_empty())
	assert_true(Exploration.discovery_for(c, d, "qingshi_village", {}).is_empty())
	var before := d.load_errors.size()
	d.regions["qingshi_village"]["discovery"] = "no_such_encounter"
	d.encounters["orphan_find"] = {"id": "orphan_find", "tags": ["x"], "discovery_only": true}
	d._validate_world()
	var text := ", ".join(d.load_errors)
	assert_true(text.contains("discovery 'no_such_encounter' must be a discovery_only encounter"), text)
	assert_true(text.contains("'orphan_find' is discovery_only but is no region's discovery"), text)
	assert_eq(d.load_errors.size(), before + 2, text)


# --- SEASON-003: Herbalist of Four Seasons --------------------------------------

func _gather_noting(c: CharacterData, table: Array, season: String) -> void:
	var rolled: Array = []
	Exploration.gather(c, table, seeded_rng(1), rolled)
	Exploration.note_seasonal_gather(c, rolled, season)


func test_seasonal_gather_records_season_once() -> void:
	var c := new_character()
	var table := [{"item": "spirit_herb", "weight": 1, "min": 1, "max": 1, "seasons": ["spring"]}]
	_gather_noting(c, table, "Spring")
	_gather_noting(c, table, "Spring")
	assert_eq(c.seasonal_gathers, ["spring"] as Array[String])
	assert_eq(LifeStats.get_stat(c, "seasons_gathered"), 1)


func test_normal_gather_records_nothing() -> void:
	var c := new_character()
	_gather_noting(c, [{"item": "dew_grass", "weight": 1, "min": 1, "max": 1}], "Spring")
	assert_true(c.seasonal_gathers.is_empty())


func test_seasonal_gathers_save_and_old_saves_default() -> void:
	var c := new_character()
	c.seasonal_gathers.append("winter")
	assert_eq(CharacterData.from_dict(c.to_dict()).seasonal_gathers, ["winter"] as Array[String])
	var d := c.to_dict()
	d.erase("seasonal_gathers")
	assert_true(CharacterData.from_dict(d).seasonal_gathers.is_empty())


func test_four_seasons_herbalist_milestone_at_four() -> void:
	var c := new_character()
	var table := [{"item": "spirit_herb", "weight": 1, "min": 1, "max": 1, "seasons": ["spring", "summer", "autumn", "winter"]}]
	for season in ["Spring", "Summer", "Autumn"]:
		_gather_noting(c, table, season)
	assert_false(Milestones.newly_reached(c, data(), {}).has("four_seasons_herbalist"))
	_gather_noting(c, table, "Winter")
	assert_true(Milestones.newly_reached(c, data(), {}).has("four_seasons_herbalist"))


func test_seasonal_sources_lists_restricted_entries() -> void:
	var src := Exploration.seasonal_sources(data(), "ice_soul_flower")
	assert_true(src.size() >= 1)
	assert_eq(src[0]["place"], "Frost Ledge")
	assert_eq(src[0]["seasons"], ["winter"])
	assert_eq(Exploration.seasonal_sources(data(), "cold_iron").size(), 0)


func test_region_progress_counts_met_and_realm_gated() -> void:
	var c := new_character()
	var region_id: String = data().start_region
	var before := Exploration.region_progress(c, data(), region_id)
	assert_true(int(before["total"]) > 0)
	assert_eq(int(before["met"]), 0)
	var tags: Array = data().regions[region_id].get("encounter_tags", [])
	var pick: Dictionary = {}
	for e: Dictionary in data().encounters.values():
		if e.get("tags", []).any(func(t: Variant) -> bool: return tags.has(t)) and not e.has("requires_flag") and not e.has("rival") and not e.get("discovery_only", false) and not e.has("min_realm") and not e.has("blocked_by_flag"):
			pick = e
			break
	assert_false(pick.is_empty())
	Exploration.note_met(c, pick)
	var after := Exploration.region_progress(c, data(), region_id)
	assert_eq(int(after["met"]), 1)
	assert_eq(int(after["total"]), int(before["total"]))
	assert_eq(LifeStats.get_stat(c, "happenings_seen"), 1)



func test_region_progress_leaves_out_happenings_past_your_realm() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("qi_refining")
	var at_qi := Exploration.region_progress(c, data(), "qingshi_village")
	Exploration.note_met(c, data().encounters["village_runaway_mule"])
	c.realm_index = data().realm_index_of("foundation_establishment")
	var at_foundation := Exploration.region_progress(c, data(), "qingshi_village")
	assert_true(int(at_foundation["total"]) < int(at_qi["total"]), "unmet Qi Refining-only happenings drop out")
	assert_eq(int(at_foundation["met"]), 1, "a met one still counts")
	assert_true(int(at_foundation["met"]) <= int(at_foundation["total"]))


func test_happenings_seen_milestone_at_fifty() -> void:
	var c := new_character()
	for i in 49:
		Exploration.note_met(c, {"id": "fake_%d" % i})
	assert_eq(LifeStats.get_stat(c, "happenings_seen"), 49)
	Exploration.note_met(c, {"id": "fake_49"})
	assert_eq(LifeStats.get_stat(c, "happenings_seen"), 50)
	var m: Dictionary = {}
	for entry: Dictionary in data().milestones:
		if entry["id"] == "wanderer_many_roads":
			m = entry
	assert_eq(int(m["check"]["min"]), 50)


func test_discoveries_follow_flags_and_backfill() -> void:
	var c := new_character()
	var flags := {"discovered_a": true, "discovered_b": false, "other": true}
	LifeStats.sync_discoveries(c, flags)
	assert_eq(LifeStats.get_stat(c, "discoveries"), 1)
	flags["discovered_b"] = true
	flags["discovered_c"] = true
	flags["discovered_d"] = true
	LifeStats.sync_discoveries(c, flags)
	assert_eq(LifeStats.get_stat(c, "discoveries"), 4)
	var old := new_character()
	LifeStats.backfill(old, data(), flags)
	assert_eq(LifeStats.get_stat(old, "discoveries"), 4)
	var m: Dictionary = {}
	for entry: Dictionary in data().milestones:
		if entry["id"] == "seeker_of_hidden_places":
			m = entry
	assert_eq(int(m["check"]["min"]), 4)


func test_familiarity_line() -> void:
	var site: GDScript = load("res://src/world/interactables/explore_site.gd")
	var c := new_character()
	c.realm_index = data().realm_index_of("qi_refining")
	assert_eq(site.familiarity_line(c, data(), "no_such_region"), "")
	assert_eq(site.familiarity_line(c, data(), "misty_forest").contains("You know"), false)
	for i in 3:
		Exploration.add_explore_day(c, "misty_forest")
	var line: String = site.familiarity_line(c, data(), "misty_forest")
	assert_true(line.contains("3 days explored"), line)
	var deeper := Exploration.next_deep_path(c, data(), "misty_forest")
	assert_true(deeper > 3)
	assert_true(line.contains("after %d days" % deeper), line)
	c.explore_days["misty_forest"] = 100000
	line = site.familiarity_line(c, data(), "misty_forest")
	assert_true(line.contains("days explored"))
	assert_false(line.contains("deeper"), line)


## TRAV-006: road encounters.
func test_road_encounter_no_draw_without_road_block() -> void:
	var d := GameData.load_from_dir()
	d.road = {}
	var rng := seeded_rng(5)
	var before := rng.state
	assert_true(Exploration.road_encounter(new_character(), d, 10, {}, rng, "Spring").is_empty())
	assert_eq(rng.state, before, "no rng draw")


func test_road_encounter_chance_scales_with_days_and_caps() -> void:
	var d := GameData.load_from_dir()
	d.encounters = {"r": {"id": "r", "tags": ["road"], "weight": 1, "kind": "neutral", "text": "Road."}}
	d.road = {"chance_per_day": 0.1, "max_chance": 0.3, "encounter_tags": ["road"]}
	var c := new_character()
	var hits := {1: 0, 2: 0, 9: 0}
	for seed_value in range(400):
		for days: int in hits:
			if not Exploration.road_encounter(c, d, days, {}, seeded_rng(seed_value), "Spring").is_empty():
				hits[days] += 1
	assert_true(hits[1] < hits[2], "more days, more chances")
	assert_true(hits[9] < 400 * 0.3 + 50 and hits[9] > 400 * 0.3 - 50, "capped near max_chance: %d" % hits[9])


func test_road_data_is_valid() -> void:
	var d := GameData.load_from_dir()
	assert_true(d.load_errors.is_empty(), str(d.load_errors))
	assert_false(d.road.is_empty())
	assert_true(Exploration.eligible_encounters(new_character(), d, d.road["encounter_tags"], {}).size() >= 2)


## TRAV-007: faster travel for higher realms.
func test_travel_days_by_realm() -> void:
	var d := GameData.load_from_dir()
	assert_true(d.load_errors.is_empty(), str(d.load_errors))
	var c := new_character()
	var expected := {0: 10, 1: 7, 2: 5, 3: 4}
	for realm in expected:
		c.realm_index = d.realm_index_of(["qi_refining", "foundation_establishment", "core_formation", "nascent_soul"][realm])
		assert_eq(Exploration.travel_days(c, d, 10), expected[realm], "realm %d" % realm)
		assert_eq(Exploration.travel_days(c, d, 1), 1, "never below 1")
	c.realm_index = 0
	assert_eq(Exploration.travel_how(c, d), "")
	c.realm_index = d.realm_index_of("foundation_establishment")
	assert_eq(Exploration.travel_how(c, d), "on your flying sword")


func test_check_travel_and_routes_use_shortened_days() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	var from: String = d.start_region
	var route: Dictionary = d.regions[from]["routes"][0]
	c.realm_index = d.realm_index_of("nascent_soul")
	var check := Exploration.check_travel(c, d, from, route["to"])
	assert_true(check["ok"])
	assert_eq(check["base_days"], int(route["days"]))
	assert_eq(check["days"], Exploration.travel_days(c, d, int(route["days"])))
	assert_eq(Exploration.routes(c, d, from)[0]["days"], check["days"])


func test_travel_speed_validation() -> void:
	var d := GameData.load_from_dir()
	d.travel_speed = [{"min_realm": "core_formation", "mult": 0.5, "how": "x"}, {"min_realm": "foundation_establishment", "mult": 1.5, "how": ""}]
	d.load_errors.clear()
	d._validate_world()
	var text := str(d.load_errors)
	assert_true(text.contains("strictly rising"), text)
	assert_true(text.contains("mult"), text)
	assert_true(text.contains("non-empty"), text)


## WU-080: travel options say how busy the road is.
func test_road_note_by_days() -> void:
	var d := GameData.load_from_dir()
	d.road = {"chance_per_day": 0.08, "max_chance": 0.4, "encounter_tags": ["road"]}
	assert_eq(Exploration.road_note(d, 1), "Roads are quiet.")
	assert_true(Exploration.road_note(d, 6).begins_with("Roads see traffic"))
	d.road = {}
	assert_eq(Exploration.road_note(d, 6), "Roads are quiet.")


## EXPL-003: mastering a region.
func _master(c: CharacterData, region_id: String, flags: Dictionary) -> void:
	for e: Dictionary in data().encounters.values():
		Exploration.note_met(c, e)
		if String(e.get("blocked_by_flag", "")) != "":
			flags[e["blocked_by_flag"]] = true
	if String(data().regions[region_id].get("discovery", "")) != "":
		flags["discovered_" + region_id] = true
	c.explore_days[region_id] = 100000


func test_mastered_needs_everything() -> void:
	var c := new_character()
	var flags := {}
	assert_false(Exploration.mastered(c, data(), "qingshi_village", flags))
	_master(c, "qingshi_village", flags)
	assert_true(Exploration.mastered(c, data(), "qingshi_village", flags))
	if String(data().regions["qingshi_village"].get("discovery", "")) != "":
		flags.erase("discovered_qingshi_village")
		assert_false(Exploration.mastered(c, data(), "qingshi_village", flags), "discovery not found")
	assert_false(Exploration.mastered(c, data(), "no_such_region", {}))


func test_mastery_lost_with_new_realm_gated_happenings() -> void:
	var c := new_character()
	var flags := {}
	_master(c, "qingshi_village", flags)
	assert_true(Exploration.mastered(c, data(), "qingshi_village", flags))
	# Mark one met happening as never seen: it counts again while it is in range.
	var id := ""
	for e: Dictionary in data().encounters.values():
		var tags: Array = data().regions["qingshi_village"].get("encounter_tags", [])
		if e.get("tags", []).any(func(t: Variant) -> bool: return tags.has(t)) and not e.has("requires_flag") and not e.has("rival") and not e.get("discovery_only", false) and not e.has("blocked_by_flag"):
			id = e["id"]
			break
	c.encounter_counts.erase(id)
	assert_false(Exploration.mastered(c, data(), "qingshi_village", flags))
