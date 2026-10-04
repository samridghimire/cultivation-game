extends TestCase
## G-008b: the sect mission board screen and its sect hall entry.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _disciple(sect_id: String = "azure_cloud_sect") -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.sect = {"id": sect_id, "rank": 0, "contribution": 0}
	return c


func test_info_text_shows_kind_days_and_contribution() -> void:
	var mission: Dictionary = data().sect_missions["cull_mist_wolves"]
	var text := MissionBoard.info_text(_disciple(), data(), mission)
	assert_true(text.begins_with("Hunt"), text)
	assert_true(text.contains(Calendar.format_duration(int(mission["days"]))), text)
	assert_true(text.contains("+%d contribution" % int(mission["contribution"])), text)


func test_info_text_names_min_rank_in_own_sect() -> void:
	var mission: Dictionary = data().sect_missions["purge_demonic_cultivator"]
	var sect: SectDef = data().sects["azure_cloud_sect"]
	var text := MissionBoard.info_text(_disciple(), data(), mission)
	assert_true(text.contains(sect.rank_name(int(mission["min_rank"]))), text)


func test_requirement_lines_show_have_over_need_and_danger() -> void:
	var c := _disciple()
	c.inventory = {"spirit_herb": 2}
	var gather := MissionBoard.requirement_lines(c, data(), data().sect_missions["gather_spirit_herbs"])
	assert_eq(gather, PackedStringArray(["2 / 5 %s" % data().items["spirit_herb"]["name"]]))
	var hunt := MissionBoard.requirement_lines(c, data(), data().sect_missions["cull_mist_wolves"])
	assert_eq(hunt.size(), 1)
	assert_true(hunt[0].begins_with("Defeat: %s (" % data().enemies["mist_wolf"]["name"]), hunt[0])


func test_sect_hall_offers_board_only_to_disciples() -> void:
	var gs := _root().get_node("GameState")
	var hall: Node = load("res://src/world/interactables/sect_hall.gd").new()
	gs.start_session(new_character())
	var labels: Array = hall.get_options().map(func(o: Dictionary) -> String: return o["label"])
	assert_false(labels.any(func(l: String) -> bool: return l.begins_with("Mission board")), "rogues have no board")
	gs.start_session(_disciple())
	var opened: Array = []
	var bus := _root().get_node("EventBus")
	var cb := func(): opened.append(true)
	bus.mission_board_requested.connect(cb)
	for option: Dictionary in hall.get_options():
		if option["label"].begins_with("Mission board"):
			option["action"].call()
	bus.mission_board_requested.disconnect(cb)
	hall.free()
	assert_eq(opened, [true])


func test_board_lists_missions_and_takes_one() -> void:
	var gs := _root().get_node("GameState")
	var c := _disciple()
	c.inventory = {"spirit_herb": 5}
	gs.start_session(c)
	var board := MissionBoard.new()
	board._rebuild()
	var ids := Sects.available_missions(gs.player, data())
	var buttons := board.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return ids.has(String(b.name)))
	assert_eq(buttons.size(), ids.size())
	assert_eq(board._selected, "gather_spirit_herbs", "first takeable mission is preselected")
	assert_false(board._take_button.disabled)
	board._take()
	assert_eq(gs.player.item_count("spirit_herb"), 0)
	assert_eq(int(gs.player.sect["contribution"]), int(data().sect_missions["gather_spirit_herbs"]["contribution"]))
	board._rebuild()
	board._select("gather_spirit_herbs")
	assert_true(board._take_button.disabled, "on cooldown after taking it")
	assert_true(board._status.text.contains("not offered again"), board._status.text)
	board.free()


func test_shop_info_text_shows_cost_rank_and_owned() -> void:
	var c := _disciple()
	var sect: SectDef = data().sects["azure_cloud_sect"]
	var ranked: Dictionary = {}
	for entry: Dictionary in sect.shop:
		if int(entry.get("min_rank", 0)) > 0:
			ranked = entry
			break
	c.inventory = {String(ranked["item_id"]): 2}
	var text := MissionBoard.shop_info_text(c, data(), ranked)
	assert_true(text.begins_with("Costs %d contribution" % int(ranked["contribution"])), text)
	assert_true(text.contains(sect.rank_name(int(ranked["min_rank"]))), text)
	assert_true(text.contains("you carry 2"), text)


func test_shop_item_lines_describe_effects_and_equipment() -> void:
	var c := _disciple()
	var pill := MissionBoard.shop_item_lines(c, data(), "qi_gathering_pill")
	assert_eq(pill, InventoryScreen.describe_effects(data().items["qi_gathering_pill"].get("effects", {}), data()))
	var saber := MissionBoard.shop_item_lines(c, data(), "cold_iron_saber")
	assert_true(saber.size() > 0 and saber[0].contains(Equipment.describe_stats(data(), "cold_iron_saber")), str(saber))


func test_treasury_tab_lists_shop_and_buys() -> void:
	var gs := _root().get_node("GameState")
	var c := _disciple()
	c.sect["contribution"] = 20
	gs.start_session(c)
	var board := MissionBoard.new()
	board._rebuild()
	board._set_tab("shop")
	var ids: Array = Sects.shop_items(gs.player, data()).map(func(e: Dictionary) -> String: return String(e["item_id"]))
	var buttons := board.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return ids.has(String(b.name)))
	assert_eq(buttons.size(), ids.size())
	assert_eq(board._selected, "qi_gathering_pill", "first affordable item is preselected")
	assert_eq(board._take_button.text, "Buy")
	assert_false(board._take_button.disabled)
	board._act()
	assert_eq(gs.player.item_count("qi_gathering_pill"), 1)
	assert_eq(Sects.contribution_balance(gs.player), 5)
	board._rebuild()
	assert_true(board._take_button.disabled, "cannot afford a second pill")
	assert_true(board._status.text.contains("contribution"), board._status.text)
	board._select("manual_flowing_water")
	assert_true(board._status.text.contains(data().sects["azure_cloud_sect"].rank_name(1)), board._status.text)
	board._set_tab("missions")
	assert_eq(board._take_button.text, "Take mission")
	board.free()


func test_treasury_is_empty_for_rogues() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	var board := MissionBoard.new()
	board._rebuild()
	board._set_tab("shop")
	assert_eq(board._selected, "")
	assert_false(board._take_button.visible)
	board.free()
