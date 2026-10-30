extends TestCase
## C-234: small-change repeatables fade out; a pocket-change find does not loop forever past its realm.


func test_small_change_repeatables_have_a_realm_ceiling() -> void:
	for e: Dictionary in data().encounters.values():
		if not e.get("repeatable", false) or e.has("max_realm"):
			continue
		if e.has("choices") or e.has("enemy") or e.has("set_flag"):
			continue
		var items: Dictionary = e.get("effects", {}).get("items", {})
		var only_stones := not items.is_empty() and items.keys() == ["spirit_stone"]
		if only_stones:
			assert_true(int(items["spirit_stone"]) > 10, "%s pays <= 10 stones forever" % e["id"])
		assert_false(items.keys() == ["spirit_herb"], "%s gives only a common herb forever" % e["id"])


func test_mortal_home_fights_have_a_realm_ceiling() -> void:
	for e: Dictionary in data().encounters.values():
		if not e.has("enemy") or e.has("choices"):
			continue
		var tags: Array = e.get("tags", [])
		if not ("village" in tags or "city" in tags):
			continue
		var foe: Variant = data().enemies.get(e["enemy"])
		if foe == null or str(foe.realm) != "mortal":
			continue
		assert_true(e.has("max_realm"), "%s: a mortal foe at home never fades" % e["id"])


func _send_youths_to_sect_hall(sect: Dictionary) -> Node:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := new_character()
	c.sect = sect
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	gs.pending_encounter = "village_hopeful_youths"
	var index := -1
	for ch: Dictionary in gs.data.encounters["village_hopeful_youths"]["choices"]:
		if String(ch["label"]).begins_with("Send"):
			index = gs.data.encounters["village_hopeful_youths"]["choices"].find(ch)
	gs.choose_encounter(index)
	return gs


func test_youths_sent_to_sect_hall_earn_a_rogue_renown() -> void:
	var gs := _send_youths_to_sect_hall({})
	assert_true(gs.player.is_rogue(), "a rogue stays a rogue")
	assert_gt(Renown.value(gs.player, "qingshi_village"), 0)
	gs.end_session()


func test_youths_sent_to_sect_hall_still_pay_a_member() -> void:
	var gs := _send_youths_to_sect_hall({"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0})
	assert_eq(int(gs.player.sect["contribution"]), 10)
	gs.end_session()


func test_foundation_village_pool_has_six_one_shots_and_repeatables() -> void:
	var ids: Array[String] = []
	for e: Dictionary in data().encounters.values():
		if not ("village" in e.get("tags", [])) or String(e.get("min_realm", "")) != "foundation_establishment":
			continue
		ids.append(String(e["id"]))
	assert_gt(ids.size(), 5, "Foundation village pool: %s" % str(ids))
	for id in ["village_name_the_newborn", "village_rogue_begs_pointers", "village_well_vein_stirs"]:
		assert_true(ids.has(id), id)
		assert_false(data().encounters[id].get("repeatable", false), "%s is a one-shot" % id)
	assert_eq(String(data().encounters["village_beggar_child"].get("max_realm", "")), "qi_refining")


func test_village_foundation_beats_fade_or_retire() -> void:
	var c := new_character()
	c.realm_index = data().realm_index_of("foundation_establishment")
	var ids := func(flags: Dictionary) -> Array:
		return Exploration.eligible_encounters(c, data(), ["village"], flags).map(func(e: Dictionary) -> String: return e["encounter"]["id"])
	assert_true("village_well_vein_stirs" in ids.call({}), "the well hums for a fresh Foundation player")
	assert_false("village_well_vein_stirs" in ids.call({"heard_well_hum": true}), "the well is a one-shot")
	assert_true("village_name_the_newborn" in ids.call({}))
	assert_false("village_name_the_newborn" in ids.call({"named_a_newborn": true}), "a child is named once")
	assert_true("village_headman_petition" in ids.call({}), "the granary blessing is offered to a fresh Foundation player")
	assert_false("village_headman_petition" in ids.call({"blessed_granary": true}), "a granary is blessed once")
	assert_false("village_hopeful_youths" in ids.call({"met_hopeful_youths": true}), "the same two youths come once")


func test_c265_repeats_rest_or_retire() -> void:
	var rests := {"village_lost_coin": 60, "village_boar": 45, "city_pickpocket_caught": 90, "village_old_boxer_spar": 60, "village_drunk_bully": 90}
	for id: String in rests:
		assert_eq(int(data().encounters[id].get("rest_days", 0)), rests[id], "%s rest_days" % id)
	var once := {"village_beast_at_the_fold": "met_fold_beast", "village_hopeful_youths": "met_hopeful_youths", "village_rogue_begs_pointers": "met_peak_rogue", "village_name_the_newborn": "named_a_newborn"}
	for id: String in once:
		var e: Dictionary = data().encounters[id]
		assert_eq(String(e.get("blocked_by_flag", "")), once[id], "%s is retired by its flag" % id)
		for ch: Dictionary in e["choices"]:
			assert_eq(String(ch.get("effects", {}).get("set_flag", "")), once[id], "%s: every choice sets the flag" % id)
