extends TestCase
## G-008c: sect contribution shop (sects.json `shop`, Sects shop functions, GameState.buy_with_contribution).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _disciple(sect_id: String = "azure_cloud_sect", contribution: int = 0) -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": sect_id, "rank": 0, "contribution": 0}
	Sects.add_contribution(c, data(), contribution)
	return c


func _entry(c: CharacterData, min_rank: int) -> Dictionary:
	for entry in Sects.shop_items(c, data()):
		if int(entry.get("min_rank", 0)) == min_rank:
			return entry
	return {}


func test_shop_data_is_valid() -> void:
	assert_true(Sects.validate_shops(data()).is_empty(), str(Sects.validate_shops(data())))
	for sect: SectDef in data().sects.values():
		assert_gt(sect.shop.size(), 0, "%s has a shop" % sect.id)
	var d := GameData.new()
	var bad := SectDef.from_dict({"id": "bad", "ranks": [{"name": "A", "contribution": 0}], "shop": [
		{"item_id": "nope", "contribution": 5},
		{"item_id": "qi_gathering_pill", "contribution": 0, "min_rank": 3},
		{"item_id": "qi_gathering_pill", "contribution": 5},
	]})
	d.items = data().items
	d.sects = {"bad": bad}
	assert_eq(Sects.validate_shops(d).size(), 4, "unknown item, cost, rank, duplicate")


func test_rogues_have_no_shop() -> void:
	var c := new_character()
	assert_true(Sects.shop_items(c, data()).is_empty())
	assert_eq(Sects.contribution_balance(c), 0)
	assert_true(Sects.check_purchase(c, data(), "qi_gathering_pill") != "")


func test_buying_spends_balance_but_keeps_rank() -> void:
	var c := _disciple("azure_cloud_sect", 600)
	assert_eq(int(c.sect["rank"]), 1, "600 contribution = Inner Disciple")
	var entry := _entry(c, 1)
	assert_false(entry.is_empty(), "azure sells a rank-1 item")
	var item_id := String(entry["item_id"])
	var cost := int(entry["contribution"])
	var before := c.item_count(item_id)
	var result := Sects.buy_with_contribution(c, data(), item_id)
	assert_true(result["ok"], result["reason"])
	assert_eq(result["cost"], cost)
	assert_eq(c.item_count(item_id), before + 1)
	assert_eq(Sects.contribution_balance(c), 600 - cost)
	assert_eq(int(c.sect["rank"]), 1, "spending never demotes")
	Sects.add_contribution(c, data(), 10)
	assert_eq(int(c.sect["rank"]), 1, "rank follows lifetime contribution")
	assert_eq(Sects.contribution_balance(c), 610 - cost)


func test_purchase_checks() -> void:
	var c := _disciple("azure_cloud_sect", 0)
	var cheap := _entry(c, 0)
	var item_id := String(cheap["item_id"])
	assert_true(Sects.check_purchase(c, data(), item_id).contains("contribution"), "can't afford")
	Sects.add_contribution(c, data(), int(cheap["contribution"]))
	assert_eq(Sects.check_purchase(c, data(), item_id), "")
	var ranked := _entry(c, 1)
	Sects.add_contribution(c, data(), 400)
	assert_eq(int(c.sect["rank"]), 0)
	assert_true(Sects.check_purchase(c, data(), String(ranked["item_id"])).contains("Inner Disciple"), "rank gate")
	assert_true(Sects.check_purchase(c, data(), "blood_demon_pill").contains("does not offer"))


func test_spent_contribution_round_trips_and_old_saves_default() -> void:
	var c := _disciple("blood_lotus_sect", 300)
	Sects.buy_with_contribution(c, data(), String(Sects.shop_items(c, data())[0]["item_id"]))
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(int(back.sect["spent"]), int(c.sect["spent"]))
	assert_eq(Sects.contribution_balance(back), Sects.contribution_balance(c))
	var old := CharacterData.from_dict({"id": "player", "sect": {"id": "blood_lotus_sect", "rank": 0, "contribution": 120}})
	assert_eq(Sects.contribution_balance(old), 120, "old saves spent nothing")


func test_game_state_buy_with_contribution() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.buy_with_contribution("qi_gathering_pill")
	assert_eq(c.item_count("qi_gathering_pill"), 0, "rogue refused")
	c.sect = {"id": "myriad_treasure_pavilion", "rank": 0, "contribution": 50, "spent": 0}
	var before := c.item_count("qi_gathering_pill")
	gs.buy_with_contribution("qi_gathering_pill")
	assert_eq(c.item_count("qi_gathering_pill"), before + 1)
	assert_eq(Sects.contribution_balance(c), 50 - int(Sects.shop_entry(c, gs.data, "qi_gathering_pill")["contribution"]))
	assert_eq(clock.total_days, days, "buying takes no time")
	gs.end_session()
