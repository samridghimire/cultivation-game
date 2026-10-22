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
	assert_true(hunt[0].contains(" in 100"), hunt[0])
	assert_eq(hunt[0].contains(", to the death"), bool(data().enemies["mist_wolf"]["lethal"]), hunt[0])


func test_odds_text_wording() -> void:
	assert_eq(UIStyle.odds_wording(0.8, true), "Even, 80 in 100, to the death")
	assert_eq(UIStyle.odds_wording(0.04, false), "Deadly, 4 in 100")


func test_trial_line_never_says_to_the_death() -> void:
	var c := _disciple()
	var board := MissionBoard.new()
	board._set_tab("rank")
	assert_false(board._requirements.text.contains("to the death"), board._requirements.text)


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
	assert_eq(board._selected, MissionBoard.ordered(gs.player, data(), gs.world_flags, ids)[0], "first takeable mission is preselected")
	board._select("gather_spirit_herbs")
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


func test_danger_text_warns_about_forced_fights() -> void:
	assert_eq(MissionBoard.danger_text(""), "")
	assert_eq(MissionBoard.danger_text("Weak"), "Danger: Weak.")
	assert_true(MissionBoard.danger_text("Deadly").contains("always fought"))
	assert_eq(UIStyle.danger_color("Deadly"), UIStyle.DANGER_COLORS["Deadly"])
	assert_eq(UIStyle.danger_color("nonsense"), Color.WHITE)


func test_board_shows_colored_danger_for_fight_missions() -> void:
	var gs := _root().get_node("GameState")
	var c := _disciple()
	gs.start_session(c)
	var board := MissionBoard.new()
	board._rebuild()
	var fights := 0
	for mission_id in Sects.available_missions(gs.player, data()):
		var b := board._list.get_node(NodePath(mission_id)) as Button
		var danger := Sects.mission_danger(gs.player, data(), mission_id)
		if danger == "":
			assert_false(b.text.contains("["), b.text)
			continue
		fights += 1
		assert_true(b.text.contains("[%s, " % danger) and b.text.ends_with(" in 100]") or b.text.ends_with(" in 100, to the death]"), b.text)
		assert_eq(b.get_theme_color("font_color"), UIStyle.danger_color(danger))
		board._select(mission_id)
		assert_true(board._danger.visible)
		assert_eq(board._danger.text, MissionBoard.danger_text(danger))
	assert_gt(fights, 0, "the sect posts at least one fight")
	board._select("gather_spirit_herbs")
	assert_false(board._danger.visible, "a gathering mission has no foe")
	board.free()
	gs.end_session()


## WU-088: a lost fight shows its cooldown reason, then a "you lost" line once offered again.
func test_board_remembers_a_lost_fight() -> void:
	var gs := _root().get_node("GameState")
	var c := _disciple()
	c.stage = 5
	gs.start_session(c)
	var id := "cull_mist_wolves"
	assert_eq(MissionBoard.loss_text(gs.player, id), "")
	Sects.fail_mission(gs.player, data(), id)
	var board := MissionBoard.new()
	board._rebuild()
	board._select(id)
	assert_true(board._status.text != "", "cooldown reason shown")
	assert_false(board._danger.text.contains("You lost"), "only once offered again")
	gs.player.age_days += maxi(data().sect_mission_loss_cooldown_days, int(data().sect_missions[id].get("cooldown_days", 0))) + 1
	board._show_details()
	assert_true(board._danger.text.contains("You lost this fight"), "%s | %s | %d" % [board._danger.text, Sects.check_mission(gs.player, data(), id, gs.world_flags), Sects.last_loss_days_ago(gs.player, id)])
	assert_true(board._danger.text.begins_with("Danger:"), "the danger rating stays")
	board.free()
	gs.end_session()


## G-011b: the Rank tab shows requirements, stipend and duty, and the trial.
func test_rank_tab_shows_requirements_and_trial() -> void:
	var gs := _root().get_node("GameState")
	var c := _disciple()
	gs.start_session(c)
	var sect: SectDef = gs.data.sects[c.sect["id"]]
	var board := MissionBoard.new()
	board._set_tab("rank")
	var ranks := board._list.get_children().filter(func(n: Node) -> bool: return n is Button)
	assert_eq(ranks.size(), sect.ranks.size())
	assert_eq(board._selected, "rank_1", "the next rank is preselected")
	assert_true(board._requirements.text.contains("Trial: defeat"), board._requirements.text)
	assert_true(board._rewards.text.contains("Stipend:"), board._rewards.text)
	assert_true(board._take_button.visible and board._take_button.disabled, "not enough contribution yet")
	assert_true(board._status.text.contains("contribution"), board._status.text)
	c.sect["contribution"] = int(sect.ranks[1]["contribution"])
	board._rebuild()
	assert_false(board._take_button.disabled, board._status.text)
	board._select("rank_0")
	assert_false(board._take_button.visible, "no trial for the rank you hold")
	assert_eq(board._status.text, "You hold this rank.")
	board._select("rank_2")
	assert_true(board._status.text.begins_with("Reach "), board._status.text)
	board.free()
	gs.end_session()


func test_rank_text_helpers() -> void:
	var c := _disciple()
	var d := data()
	var sect: SectDef = d.sects[c.sect["id"]]
	var lines := MissionBoard.rank_requirement_lines(c, d, 2)
	assert_true(lines[0].begins_with("0 / %d" % int(sect.ranks[2]["contribution"])), lines[0])
	assert_true(lines[1].begins_with("Realm: "), lines[1])
	var benefits := MissionBoard.rank_benefit_lines(d, sect.id, 0)
	assert_eq(benefits, PackedStringArray(["Stipend: none", "Monthly duty: none"]))
	var core := MissionBoard.rank_benefit_lines(d, "azure_cloud_sect", 2)
	assert_true(core[0].contains("1 Qi Gathering Pill a month"), core[0])
	d.sects["azure_cloud_sect"].ranks[2]["stipend"]["items"]["qi_gathering_pill"] = 2
	assert_true(MissionBoard.rank_benefit_lines(d, "azure_cloud_sect", 2)[0].contains("2 Qi Gathering Pills a month"))
	assert_eq(MissionBoard.duty_text(c, d), "Your rank owes no monthly duty.")
	c.sect["rank"] = 1
	c.sect["month_earned"] = 10
	assert_true(MissionBoard.duty_text(c, d).begins_with("Duty this month: 10 / "), MissionBoard.duty_text(c, d))


func test_sect_hall_offers_promotion_trial() -> void:
	var gs := _root().get_node("GameState")
	var c := _disciple()
	gs.start_session(c)
	var hall: Node = load("res://src/world/interactables/sect_hall.gd").new()
	var trial: Dictionary = hall.trial_option()
	assert_true(String(trial["label"]).begins_with("Attempt the trial for "), trial["label"])
	assert_true(trial["disabled"])
	c.sect["contribution"] = 100000
	assert_false(hall.trial_option()["disabled"])
	hall.free()
	gs.end_session()


func test_sect_call_mission_is_listed_first_with_days_left() -> void:
	var gs := _root().get_node("GameState")
	var c := _disciple()
	c.stage = 8
	gs.start_session(c)
	gs.world_flags["sect_call_azure_cloud_sect"] = true
	gs.world_flags["sect_call_day_azure_cloud_sect"] = GameClock.total_days
	var board := MissionBoard.new()
	board._rebuild()
	var first := board._list.get_child(0) as Button
	assert_eq(String(first.name), "answer_azure_call")
	assert_true(first.text.contains("%d days left" % SectFactions.CALL_DAYS), first.text)
	board.free()


func test_call_days_left_helper() -> void:
	var flags := {"sect_call_x": true, "sect_call_day_x": 100}
	assert_eq(SectFactions.call_days_left(flags, "x", 110), SectFactions.CALL_DAYS - 10)
	assert_eq(SectFactions.call_days_left(flags, "x", 100 + SectFactions.CALL_DAYS + 5), 0)
	assert_eq(SectFactions.call_days_left(flags, "y", 110), -1)
	assert_eq(SectFactions.call_days_left({}, "x", 110), -1)
	assert_eq(SectFactions.call_mission_id(data(), "azure_cloud_sect"), "answer_azure_call")


func test_danger_text_risky_warns_to_prepare() -> void:
	assert_true(MissionBoard.danger_text("Risky").contains("probably win, but a loss is likely enough to prepare for."))
	assert_false(MissionBoard.danger_text("Risky").contains("no slipping away"))


## WU-107: the "you lost this fight" line fades after LOSS_MEMORY_DAYS and a win clears it.
func test_loss_text_fades_and_a_win_clears_it() -> void:
	var c := _disciple()
	var id := "cull_mist_wolves"
	assert_eq(MissionBoard.loss_text(c, id), "", "never lost")
	c.mission_losses[id] = c.age_days - 10
	assert_true(MissionBoard.loss_text(c, id).contains("You lost this fight"), "10 days ago")
	c.mission_losses[id] = c.age_days - MissionBoard.LOSS_MEMORY_DAYS
	assert_true(MissionBoard.loss_text(c, id) != "", "still remembered on the last day")
	c.mission_losses[id] = c.age_days - (MissionBoard.LOSS_MEMORY_DAYS + 1)
	assert_eq(MissionBoard.loss_text(c, id), "", "61 days ago")
	c.mission_losses[id] = c.age_days - 40
	assert_true(MissionBoard.loss_text(c, id) != "", "40 days ago")
	c.stage = 5
	var d := data()
	for item_id: String in d.sect_missions[id].get("requires", {}).get("items", {}):
		c.add_item(item_id, 99)
	var result := Sects.complete_mission(c, d, id, {})
	assert_true(result["ok"], str(result["reason"]))
	assert_eq(MissionBoard.loss_text(c, id), "", "a won retry clears it")


## WU-126: takeable fights come first by rating, then other takeable missions, then unavailable ones.
func test_ordered_puts_fair_fights_first_and_unavailable_last() -> void:
	var c := _disciple()
	c.stage = 5
	var d := data()
	var ids := Sects.available_missions(c, d, {})
	# Make one mission unavailable (on cooldown after a loss).
	var lost := "cull_mist_wolves"
	assert_true(ids.has(lost))
	Sects.fail_mission(c, d, lost)
	var out := MissionBoard.ordered(c, d, {}, ids)
	assert_eq(out.size(), ids.size(), "nothing dropped")
	assert_true(Sects.check_mission(c, d, lost, {}) != "", "the lost fight is on cooldown")
	var ratings := ["Weak", "Even", "Risky", "Dangerous", "Deadly"]
	var phase := 0 # 0 = takeable fights, 1 = takeable others, 2 = unavailable
	var last_rating := 0
	for id in out:
		var takeable := Sects.check_mission(c, d, id, {}) == ""
		var rating := ratings.find(Sects.mission_danger(c, d, id))
		var group := 2 if not takeable else (0 if rating >= 0 else 1)
		assert_true(group >= phase, "group order at %s" % id)
		if group > phase:
			phase = group
			last_rating = 0
		if group == 0:
			assert_true(rating >= last_rating, "rating order at %s" % id)
			last_rating = rating
	assert_eq(MissionBoard.ordered(c, d, {}, [] as Array[String]).size(), 0)


## WU-189: a nearly empty artifact warns before a risky lethal mission fight.
func test_low_artifact_warns_on_risky_lethal_missions() -> void:
	var gs := _root().get_node("GameState")
	var c := _disciple()
	gs.start_session(c)
	var d := data()
	var lethal_id := ""
	var weak_id := ""
	for id in d.sect_missions:
		var eid := String(d.sect_missions[id].get("enemy", ""))
		if eid == "" or not d.enemies.has(eid):
			continue
		if bool(d.enemies[eid].get("lethal", false)) and lethal_id == "":
			lethal_id = id
		elif not bool(d.enemies[eid].get("lethal", false)) and weak_id == "":
			weak_id = id
	assert_true(lethal_id != "")
	var board := MissionBoard.new()
	var p: CharacterData = gs.player
	p.artifact_lives = 1
	var enemy: Dictionary = d.enemies[String(d.sect_missions[lethal_id]["enemy"])]
	var saved := enemy.duplicate()
	enemy["realm"] = "void_refinement"
	enemy["stage"] = 3
	assert_true(["Risky", "Dangerous", "Deadly"].has(Sects.mission_danger(p, d, lethal_id)))
	assert_true(MissionBoard.low_artifact_warning(p, d, lethal_id).contains("holds 1 life"))
	p.artifact_lives = 0
	assert_true(MissionBoard.low_artifact_warning(p, d, lethal_id).contains("holds no lives"))
	p.artifact_lives = 1
	board._rebuild()
	var row := board._list.get_node_or_null(NodePath(lethal_id)) as Button
	if row != null:
		assert_true(row.text.ends_with(" !"), row.text)
		board._select(lethal_id)
		assert_true(board._danger.text.contains("Creation Artifact"), board._danger.text)
	p.artifact_lives = 3
	assert_eq(MissionBoard.low_artifact_warning(p, d, lethal_id), "")
	p.artifact_lives = 1
	for k in saved:
		enemy[k] = saved[k]
	enemy["realm"] = "mortal"
	enemy["stage"] = 0
	enemy["hp"] = -1000
	assert_eq(MissionBoard.low_artifact_warning(p, d, lethal_id), "", "a Weak fight does not warn")
	for k in saved:
		enemy[k] = saved[k]
	board.free()
	gs.end_session()


## WU-291: exactly one mission wears " (best pay)", and none when all are on cooldown.
func test_best_pay_mark_on_exactly_one_mission() -> void:
	var c := _disciple()
	c.stage = 2
	var d := data()
	var ids := Sects.available_missions(c, d, {})
	var best := Guidance.best_mission(c, d, {})
	assert_true(best != "", "a ready mission exists")
	var marked: Array[String] = []
	for id in ids:
		if MissionBoard.label_for(c, d, {}, id, "", -1).contains(" (best pay)"):
			marked.append(id)
	assert_eq(marked, [best] as Array[String])
	for id in ids:
		c.mission_cooldowns[id] = 999999
	for id in ids:
		assert_false(MissionBoard.label_for(c, d, {}, id, "", -1).contains(" (best pay)"), id)
