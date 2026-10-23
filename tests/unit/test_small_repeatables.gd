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
