extends TestCase
## G-008: sect missions (data/sect_missions.json, Sects missions, GameState.take_mission).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _disciple(sect_id: String = "azure_cloud_sect") -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": sect_id, "rank": 0, "contribution": 0}
	return c


func test_mission_data_is_valid() -> void:
	assert_true(Sects.validate_missions(data()).is_empty(), str(Sects.validate_missions(data())))
	assert_gt(data().sect_missions.size(), 0)
	var d := GameData.new()
	d.realms = data().realms
	d.sect_missions = {"bad": {"id": "bad", "kind": "duel", "sects": ["nope"], "days": 0, "enemy": "ghost", "requires": {"items": {"air": 1}}}}
	assert_eq(Sects.validate_missions(d).size(), 5, "kind, sect, days, enemy, item")
	d.sect_missions = {"hunt": {"id": "hunt", "kind": "hunt", "days": 1}}
	assert_eq(Sects.validate_missions(d).size(), 1, "hunts need an enemy")
	d.sect_missions = {"deep": {"id": "deep", "kind": "gather", "days": 1, "min_realm": "mortal", "min_stage": 1}}
	assert_eq(Sects.validate_missions(d).size(), 1, "mortals have a single stage")
	d.sect_missions["deep"]["min_realm"] = "qi_refining"
	assert_eq(Sects.validate_missions(d).size(), 0)


func test_missions_offered_per_sect() -> void:
	assert_true(Sects.available_missions(new_character(), data()).is_empty(), "rogues get no missions")
	var azure := Sects.available_missions(_disciple("azure_cloud_sect"), data())
	var blood := Sects.available_missions(_disciple("blood_lotus_sect"), data())
	assert_true(azure.has("gather_spirit_herbs") and blood.has("gather_spirit_herbs"), "generic missions for everyone")
	assert_true(azure.has("escort_mortal_villagers"))
	assert_false(blood.has("escort_mortal_villagers"), "sect-specific missions")
	assert_true(Sects.check_mission(_disciple("blood_lotus_sect"), data(), "escort_mortal_villagers") != "")


func test_mission_requirements() -> void:
	var c := _disciple()
	assert_true(Sects.check_mission(new_character(), data(), "gather_spirit_herbs").contains("sect"), "rogue")
	assert_true(Sects.check_mission(c, data(), "gather_spirit_herbs").contains("Spirit Herb"), "needs herbs")
	c.add_item("spirit_herb", 5)
	assert_eq(Sects.check_mission(c, data(), "gather_spirit_herbs"), "")
	assert_true(Sects.check_mission(c, data(), "purge_demonic_cultivator") != "", "rank too low")
	c.sect["rank"] = 1
	assert_true(Sects.check_mission(c, data(), "purge_demonic_cultivator") != "", "realm too low for a Foundation foe")
	c.realm_index = 2
	assert_eq(Sects.check_mission(c, data(), "purge_demonic_cultivator"), "")
	c.realm_index = 0
	assert_true(Sects.check_mission(c, data(), "cull_mist_wolves") != "", "realm too low")
	assert_true(Sects.check_mission(c, data(), "no_such_mission") != "")


func test_mission_min_stage() -> void:
	var c := _disciple("blood_lotus_sect")
	var stage := int(data().sect_missions["cull_mist_wolves"]["min_stage"])
	assert_gt(stage, 0, "the mist wolf hunt waits for a later layer")
	c.stage = stage - 1
	assert_true(Sects.check_mission(c, data(), "cull_mist_wolves").contains(data().realms[1].stage_label(stage)), "names the stage needed")
	c.stage = stage
	assert_eq(Sects.check_mission(c, data(), "cull_mist_wolves"), "")
	c.realm_index = 2
	c.stage = 0
	assert_eq(Sects.check_mission(c, data(), "cull_mist_wolves"), "", "a higher realm always qualifies")


func test_mission_danger() -> void:
	var c := _disciple()
	assert_eq(Sects.mission_danger(c, data(), "gather_spirit_herbs"), "", "no fight")
	assert_eq(Sects.mission_danger(c, data(), "no_such_mission"), "")
	assert_eq(Sects.mission_danger(c, data(), "purge_demonic_cultivator"), "Deadly", "a Foundation foe for a Qi Refining disciple")
	assert_eq(Sects.mission_danger(c, data(), "escort_mortal_villagers"), "Weak")
	c.realm_index = 3
	assert_eq(Sects.mission_danger(c, data(), "purge_demonic_cultivator"), "Weak")


func test_complete_mission_hands_in_items_and_rewards() -> void:
	var c := _disciple()
	c.add_item("spirit_herb", 6)
	var stones := c.item_count("spirit_stone")
	var mission: Dictionary = data().sect_missions["gather_spirit_herbs"]
	var result := Sects.complete_mission(c, data(), "gather_spirit_herbs", {})
	assert_true(result["ok"])
	assert_eq(c.item_count("spirit_herb"), 1, "five herbs handed in")
	assert_eq(c.item_count("spirit_stone"), stones + int(mission["rewards"]["items"]["spirit_stone"]))
	assert_eq(int(c.sect["contribution"]), int(mission["contribution"]))
	assert_eq(int(result["days"]), int(mission["days"]))
	assert_eq(Sects.mission_cooldown_left(c, "gather_spirit_herbs"), int(mission["cooldown_days"]))
	c.add_item("spirit_herb", 10)
	assert_true(Sects.check_mission(c, data(), "gather_spirit_herbs").contains("not offered again"), "cooldown")
	c.age_days += int(mission["cooldown_days"])
	assert_eq(Sects.check_mission(c, data(), "gather_spirit_herbs"), "", "available after the cooldown")


func test_mission_contribution_promotes() -> void:
	var c := _disciple()
	c.sect["contribution"] = 490
	c.add_item("spirit_herb", 5)
	var d := GameData.load_from_dir()
	(d.sects[c.sect["id"]] as SectDef).ranks[1].erase("trial")
	assert_true(Sects.complete_mission(c, d, "gather_spirit_herbs", {})["promoted"])
	assert_eq(int(c.sect["rank"]), 1)


func test_mission_cooldowns_round_trip_in_saves() -> void:
	var c := _disciple()
	c.mission_cooldowns["gather_spirit_herbs"] = 1234
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.mission_cooldowns, {"gather_spirit_herbs": 1234})
	assert_true(CharacterData.from_dict({}).mission_cooldowns.is_empty(), "old saves load")


func test_game_state_take_missions() -> void:
	var gs: Node = _root().get_node("GameState")
	var clock: Node = _root().get_node("GameClock")
	var c := CharacterFactory.create("Disciple", gs.data, seeded_rng())
	gs.start_session(c)
	gs.take_mission("gather_spirit_herbs")
	assert_eq(clock.total_days, 0, "rogue: refused, no time passes")
	c.realm_index = 4  # strong enough to beat a mortal bandit every time
	c.alignment = 0
	gs.join_sect("azure_cloud_sect")
	assert_false(c.is_rogue())
	c.add_item("spirit_herb", 5)
	gs.take_mission("gather_spirit_herbs")
	assert_eq(c.item_count("spirit_herb"), 0)
	assert_eq(int(c.sect["contribution"]), int(gs.data.sect_missions["gather_spirit_herbs"]["contribution"]))
	var days: int = clock.total_days
	assert_eq(days, int(gs.data.sect_missions["gather_spirit_herbs"]["days"]))
	var contribution := int(c.sect["contribution"])
	var alignment := c.alignment
	gs.take_mission("escort_mortal_villagers")
	assert_gt(int(c.sect["contribution"]), contribution, "won the fight, mission done")
	assert_gt(c.alignment, alignment, "righteous mission")
	assert_gt(clock.total_days, days + int(gs.data.sect_missions["escort_mortal_villagers"]["days"]) - 1, "fight + mission days")
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_gt(Sects.mission_cooldown_left(gs.player, "escort_mortal_villagers"), 0, "cooldown survives a save")
	gs.end_session()


## G-008f: every sect posts at least two Core Formation missions, and missions
## against late-Qi-Refining foes wait for a late-Qi-Refining disciple.
func test_mission_content_spans_realms() -> void:
	var d := data()
	var core := d.realm_index_of("core_formation")
	for sect_id in d.sects:
		var count := 0
		for m: Dictionary in d.sect_missions.values():
			var sects: Array = m.get("sects", [])
			if (sects.is_empty() or sects.has(sect_id)) and d.realm_index_of(String(m.get("min_realm", "mortal"))) == core:
				count += 1
		assert_true(count >= 2, "%s has %d Core Formation missions" % [sect_id, count])
	for m: Dictionary in d.sect_missions.values():
		if String(m.get("enemy", "")) in ["rogue_cultivator", "stone_ape"]:
			assert_true(int(m.get("min_stage", 0)) >= 6 or d.realm_index_of(String(m.get("min_realm", "mortal"))) > 1, "%s sends a fresh Qi Refining disciple to a late-Qi-Refining foe" % m["id"])


func test_item_missions_pay_at_least_the_items_cost() -> void:
	for id in data().sect_missions:
		var m: Dictionary = data().sect_missions[id]
		var cost := 0
		for item_id in m.get("requires", {}).get("items", {}):
			cost += int(data().items[item_id].get("price", 0)) * int(m["requires"]["items"][item_id])
		if cost == 0:
			continue
		var pay := int(m.get("rewards", {}).get("items", {}).get("spirit_stone", 0))
		assert_true(pay >= int(ceil(cost * 1.2)), "%s pays %d for items costing %d" % [id, pay, cost])
