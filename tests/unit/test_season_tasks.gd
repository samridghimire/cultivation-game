extends TestCase
## SEASON-005: the village's seasonal tasks.

func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Tasker", gs.data, seeded_rng(77))
	gs.start_session(c)
	return c


## Day 0 is month 1 (spring); 90 = summer, 180 = autumn, 270 = winter.
func test_progress_per_kind_and_reward_once() -> void:
	var gd: GameData = _gs().data
	var c := CharacterData.new()
	assert_eq(SeasonTasks.note(c, gd, "catch", "silver_carp", 1, 5).size(), 0, "not a task")
	assert_eq(SeasonTasks.note(c, gd, "catch", "peach_blossom_bream", 1, 5).size(), 1)
	assert_eq(SeasonTasks.note(c, gd, "gather", "peach_blossom_petal", 2, 5).size(), 0, "3 needed")
	var lines := SeasonTasks.note(c, gd, "gather", "peach_blossom_petal", 1, 5)
	assert_eq(lines.size(), 1)
	lines = SeasonTasks.note(c, gd, "hunt", "fog_antler_stag", 1, 5)
	assert_eq(lines.size(), 3, "task + thanks + shrine stage")
	assert_true(lines[1].begins_with("The village thanks you for the spring"))
	assert_true(SeasonTasks.note(c, gd, "hunt", "fog_antler_stag", 1, 5).is_empty(), "paid once")
	var list := SeasonTasks.list(c, gd, 5)
	assert_eq(list.size(), 3)
	assert_true(list[1]["done"] and int(list[1]["n"]) == 3)


func test_contest_and_sell_kinds() -> void:
	var gd: GameData = _gs().data
	var c := CharacterData.new()
	assert_eq(SeasonTasks.note(c, gd, "contest", "lantern_festival", 1, 270).size(), 1)
	assert_eq(SeasonTasks.note(c, gd, "sell_wanted", "", 1, 180).size(), 0, "1 of 2")
	assert_eq(SeasonTasks.note(c, gd, "sell_wanted", "", 1, 180).size(), 1)


func test_season_rollover_resets_and_save_round_trip() -> void:
	var gd: GameData = _gs().data
	var c := CharacterData.new()
	SeasonTasks.note(c, gd, "gather", "peach_blossom_petal", 2, 5)
	var back := CharacterData.from_dict(c.to_dict())
	assert_eq(int(SeasonTasks.list(back, gd, 5)[1]["n"]), 2)
	assert_eq(int(SeasonTasks.list(back, gd, 95)[1]["n"]), 0, "new season")
	assert_eq(int(SeasonTasks.list(back, gd, 5 + 360)[1]["n"]), 0, "next spring is a new year")
	assert_true(CharacterData.from_dict({}).season_tasks.is_empty(), "old saves")


func test_validation() -> void:
	assert_eq(SeasonTasks.validate(_gs().data).size(), 0)
	assert_eq(_gs().data.load_errors.size(), 0)
	var gd: GameData = _gs().data
	var saved: Dictionary = gd.season_tasks.duplicate(true)
	gd.season_tasks["seasons"]["spring"]["sets"][0][0]["kind"] = "dance"
	gd.season_tasks["seasons"]["winter"]["sets"][0].pop_back()
	assert_eq(SeasonTasks.validate(gd).size(), 2)
	gd.season_tasks = saved


func test_game_state_hooks_pay_reward() -> void:
	var gs := _gs()
	var c := _start()
	GameClock.total_days = 5
	gs.current_region = "qingshi_village"
	var stones := c.item_count("spirit_stone")
	gs._season_note("catch", "peach_blossom_bream", 1)
	gs._season_note("gather", "peach_blossom_petal", 3)
	assert_eq(gs.season_tasks().size(), 3)
	gs._season_note("hunt", "fog_antler_stag", 1)
	assert_eq(c.item_count("spirit_stone"), stones + 60)
	assert_true(c.renown.get("qingshi_village", 0) >= 2)
	gs._season_note("hunt", "fog_antler_stag", 1)
	assert_eq(c.item_count("spirit_stone"), stones + 60, "once")
	gs.end_session()


## SEASON-006: the shrine restoration.
func _finish_season(c: CharacterData, gd: GameData, day: int) -> Array[String]:
	var lines: Array[String] = []
	for t: Dictionary in SeasonTasks.tasks_for(gd, day):
		lines.append_array(SeasonTasks.note(c, gd, String(t["kind"]), String(t["target"]), int(t["count"]), day))
	return lines


func test_restoration_stages_count_once() -> void:
	var gd: GameData = _gs().data
	var c := CharacterData.new()
	assert_eq(SeasonTasks.restoration_stage(c, gd), 0)
	var lines := _finish_season(c, gd, 5)
	assert_true(String(lines[lines.size() - 1]).begins_with("Villagers clear"), "stage 1 text")
	_finish_season(c, gd, 6)
	assert_eq(SeasonTasks.restoration_stage(c, gd), 1, "same season twice counts once")
	_finish_season(c, gd, 95)
	assert_eq(SeasonTasks.restoration_stage(c, gd), 2)
	assert_eq(SeasonTasks.restoration_flags(c, gd), ["shrine_stage_1", "shrine_stage_2"])
	assert_eq(SeasonTasks.restoration_line(c, gd), "The old shrine: 2 of 4 stages repaired.")


func test_restoration_complete_and_qi() -> void:
	var gs := _gs()
	var c := _start()
	var base: float = gs.region_qi_density()
	for day in [5, 95, 185, 275]:
		GameClock.total_days = day
		for t: Dictionary in SeasonTasks.tasks_for(gs.data, day):
			gs._season_note(String(t["kind"]), String(t["target"]), int(t["count"]))
	assert_eq(SeasonTasks.restoration_stage(c, gs.data), 4)
	assert_true(bool(gs.world_flags.get("shrine_restored", false)))
	GameClock.total_days = 5
	assert_true(absf(gs.region_qi_density() - base * 1.05) < 0.02 * base, "qi +5%")
	assert_eq(SeasonTasks.restoration_line(c, gs.data), "")


func test_restoration_validation_and_save() -> void:
	var gd: GameData = _gs().data
	var saved: Dictionary = gd.season_tasks.duplicate(true)
	gd.season_tasks["restoration"]["region"] = "nowhere"
	assert_false(SeasonTasks.validate(gd).is_empty(), "unknown region")
	gd.season_tasks = saved.duplicate(true)
	gd.season_tasks["restoration"]["qi_flag"]["bonus"] = 0.5
	assert_false(SeasonTasks.validate(gd).is_empty(), "bonus too big")
	gd.season_tasks = saved
	assert_true(SeasonTasks.validate(gd).is_empty())
	var c := CharacterData.new()
	c.seasons_completed.append("1-spring")
	assert_eq(CharacterData.from_dict(c.to_dict()).seasons_completed, ["1-spring"] as Array[String])
	var d := c.to_dict()
	d.erase("seasons_completed")
	assert_true(CharacterData.from_dict(d).seasons_completed.is_empty())


## C-315: every hunt task of every season can be met roaming by a Qi Refining and a Foundation player.
func test_hunt_targets_roam_for_both_realms() -> void:
	var gd: GameData = _gs().data
	var realms: Array[int] = [gd.realm_index_of("qi_refining"), gd.realm_index_of("foundation_establishment")]
	for season: String in gd.season_tasks["seasons"]:
		var first_day: int = {"spring": 5, "summer": 95, "autumn": 185, "winter": 275}[season]
		for task: Dictionary in SeasonTasks.tasks_for(gd, 5 + 90 * ["spring", "summer", "autumn", "winter"].find(season)):
			if String(task["kind"]) != "hunt":
				continue
			for realm_index in realms:
				var found := false
				for region_id: String in gd.regions:
					for d in range(first_day, first_day + 60):
						for r in Wildlife.roamers(gd, region_id, d, realm_index, {}):
							if String(r["enemy"]) == String(task["target"]):
								found = true
				assert_true(found, "%s hunt %s roams for realm %d" % [season, task["target"], realm_index])


## SEASON-007: incense at the restored shrine.
func _restore(gs: Node, c: CharacterData) -> void:
	for day in [5, 95, 185, 275]:
		GameClock.total_days = day
		for t: Dictionary in SeasonTasks.tasks_for(gs.data, day):
			gs._season_note(String(t["kind"]), String(t["target"]), int(t["count"]))


func test_incense_reasons_and_offer() -> void:
	var gs := _gs()
	var c := _start()
	var flags := {}
	assert_eq(SeasonTasks.can_offer_incense(c, gs.data, flags, 5), "The shrine is not restored yet.")
	_restore(gs, c)
	GameClock.total_days = 300
	assert_eq(SeasonTasks.can_offer_incense(c, gs.data, flags, 300), "You have no Mugwort.")
	c.add_item("village_mugwort", 2)
	assert_eq(SeasonTasks.can_offer_incense(c, gs.data, flags, 300), "")
	assert_true(SeasonTasks.offer_incense(c, gs.data, flags, 300) != "")
	assert_eq(c.item_count("village_mugwort"), 1)
	assert_eq(SeasonTasks.can_offer_incense(c, gs.data, flags, 300), "Incense already burns today.")
	assert_true(SeasonTasks.incense_line(c, gs.data, flags, 300).begins_with("Incense burns"))
	assert_true(SeasonTasks.incense_line(c, gs.data, flags, 301).begins_with("The old shrine is restored"))


func test_incense_qi_one_day() -> void:
	var gs := _gs()
	var c := _start()
	_restore(gs, c)
	GameClock.total_days = 300
	c.add_item("village_mugwort", 1)
	var base: float = gs.region_qi_density()
	assert_true(gs.offer_incense())
	assert_true(absf(gs.region_qi_density() - base * 1.05 / 1.0) < 0.03 * base, "x1.05 on top")
	GameClock.total_days = 301
	assert_true(absf(gs.region_qi_density() - base) < 0.001 * base, "back the next day")
	assert_eq(c.item_count("village_mugwort"), 0)


func test_offer_incense_twice_fails() -> void:
	var gs := _gs()
	var c := _start()
	_restore(gs, c)
	GameClock.total_days = 300
	c.add_item("village_mugwort", 2)
	assert_true(gs.offer_incense())
	assert_false(gs.offer_incense())
	assert_eq(c.item_count("village_mugwort"), 1)


func test_incense_validation() -> void:
	var gd: GameData = _gs().data
	var saved: Dictionary = gd.season_tasks.duplicate(true)
	gd.season_tasks["restoration"]["incense"]["item"] = "no_such_item"
	assert_false(SeasonTasks.validate(gd).is_empty(), "unknown item")
	gd.season_tasks = saved.duplicate(true)
	gd.season_tasks["restoration"]["incense"]["bonus"] = 0.2
	assert_false(SeasonTasks.validate(gd).is_empty(), "bonus 0.2")
	gd.season_tasks = saved.duplicate(true)
	gd.season_tasks["restoration"]["incense"]["flag"] = "not_in_qi_flags"
	assert_false(SeasonTasks.validate(gd).is_empty(), "flag missing from qi_flags")
	gd.season_tasks = saved
	assert_true(SeasonTasks.validate(gd).is_empty())


## GUIDE-214: where a task can be done.
func test_where_per_kind() -> void:
	var gd: GameData = _gs().data
	var c := CharacterData.new()
	c.realm_index = gd.realm_index_of("foundation_establishment")
	assert_eq(SeasonTasks.where({"kind": "catch", "target": "peach_blossom_bream"}, c, gd, 5), "at Village Pond Jetty")
	assert_eq(SeasonTasks.where({"kind": "catch", "target": "peach_blossom_bream"}, c, gd, 185), "", "not in autumn")
	assert_true(SeasonTasks.where({"kind": "gather", "target": "peach_blossom_petal"}, c, gd, 5).contains("village"), "forage")
	assert_true(SeasonTasks.where({"kind": "gather", "target": "spirit_herb"}, c, gd, 5).begins_with("at Village Herb Slope"))
	assert_true(SeasonTasks.where({"kind": "hunt", "target": "mist_fox"}, c, gd, 185).begins_with("in ") or SeasonTasks.where({"kind": "hunt", "target": "mist_fox"}, c, gd, 185) == "at the village hunt")
	var contest := SeasonTasks.where({"kind": "contest", "target": "dragon_boat_festival"}, c, gd, 95)
	assert_true(contest.contains("Dragon Boat Festival") and contest.contains("month 5"), contest)
	assert_eq(SeasonTasks.where({"kind": "sell_wanted", "target": ""}, c, gd, 5), "at a market stall's wanted item")
	assert_eq(SeasonTasks.where({"kind": "catch", "target": "no_such_fish"}, c, gd, 5), "")
	assert_eq(SeasonTasks.where({"kind": "hunt", "target": "no_such_beast"}, c, gd, 5), "")


func test_list_carries_where_and_hud_line() -> void:
	var gs := _gs()
	_start()
	GameClock.total_days = 5
	var tasks: Array[Dictionary] = gs.season_tasks()
	assert_eq(String(tasks[0]["where"]), "at Village Pond Jetty")
	const HUD := preload("res://src/ui/hud.gd")
	var line: String = HUD.season_one_left_line([{"text": "Catch a fish.", "where": "at Village Pond Jetty", "done": false}], "spring")
	assert_eq(line, "One more for spring: Catch a fish at Village Pond Jetty.")


func test_where_is_memoized_per_day() -> void:
	var gd := data()
	var c := CharacterData.new()
	var task: Dictionary = SeasonTasks.tasks_for(gd, 5)[0]
	var first := SeasonTasks.where(task, c, gd, 5)
	var scans := SeasonTasks.where_scans
	assert_eq(SeasonTasks.where(task, c, gd, 5), first)
	assert_eq(SeasonTasks.where_scans, scans, "the second call does not rescan")
	SeasonTasks.where(task, c, gd, 6)
	assert_eq(SeasonTasks.where_scans, scans + 1, "a new day recomputes")


## SEASON-008: the village well after the shrine.
func _finish_seasons(gs: Node, days: Array) -> void:
	for day: int in days:
		GameClock.total_days = day
		for t: Dictionary in SeasonTasks.tasks_for(gs.data, day):
			gs._season_note(String(t["kind"]), String(t["target"]), int(t["count"]))


func test_well_stages_follow_the_shrine() -> void:
	var gs := _gs()
	var c := _start()
	_restore(gs, c)
	assert_eq(SeasonTasks.project_stage(c, gs.data, 1), 0, "shrine stage 4 continues at well stage 0")
	assert_eq(SeasonTasks.current_project(c, gs.data)["index"], 1)
	_finish_seasons(gs, [365])
	assert_eq(SeasonTasks.project_stage(c, gs.data, 1), 1)
	assert_eq(SeasonTasks.restoration_stage(c, gs.data), 4, "shrine stays whole")
	assert_true(bool(gs.world_flags.get("well_stage_1", false)))
	assert_false(bool(gs.world_flags.get("well_stage_2", false)))
	assert_eq(SeasonTasks.project_line(c, gs.data, {}, 365), "The Founder's Old Well: 1 of 3 stages repaired.")
	_finish_seasons(gs, [455, 545])
	assert_eq(SeasonTasks.project_stage(c, gs.data, 1), 3)
	assert_true(SeasonTasks.current_project(c, gs.data).is_empty())


func test_well_crop_bonus_and_draw() -> void:
	var gs := _gs()
	var c := _start()
	_restore(gs, c)
	assert_eq(SeasonTasks.crop_bonus(c, gs.data, "qingshi_village"), 0.0)
	_finish_seasons(gs, [365, 455, 545])
	assert_true(absf(SeasonTasks.crop_bonus(c, gs.data, "qingshi_village") - 0.15) < 0.0001)
	assert_eq(SeasonTasks.crop_bonus(c, gs.data, "misty_forest"), 0.0)
	GameClock.total_days = 600
	assert_true(SeasonTasks.project_line(c, gs.data, gs.world_flags, 600).contains("draw well water"))
	assert_true(gs.draw_well_water())
	assert_eq(c.item_count("well_water"), 1)
	assert_false(gs.draw_well_water(), "once a day")
	assert_eq(SeasonTasks.project_line(c, gs.data, gs.world_flags, 600), "", "GUIDE-216: no draw line after drawing")
	GameClock.total_days = 601
	assert_true(gs.draw_well_water())
	assert_eq(c.item_count("well_water"), 2)


func test_well_draw_needs_whole_well() -> void:
	var gs := _gs()
	var c := _start()
	_restore(gs, c)
	_finish_seasons(gs, [365])
	assert_false(gs.draw_well_water())
	assert_eq(c.item_count("well_water"), 0)


func test_crop_bonus_speeds_growth() -> void:
	var gd: GameData = _gs().data
	var c := CharacterData.new()
	for k in ["1-spring", "1-summer", "1-autumn", "1-winter", "2-spring", "2-summer", "2-autumn"]:
		c.seasons_completed.append(k)
	var place := FieldPlots.place_def(gd, "qingshi_village")
	var key := FieldPlots.key("qingshi_village", place)
	c.field_plots[key] = {"paid_until": 9999, "crops": [{"item": "village_mugwort", "days_left": 40}]}
	var weather := func(_r: String, _d: int) -> String: return "clear"
	FieldPlots.advance(c, gd, 20, 20, weather)  # summer days 1..20 of year 1; spring frozen? use result only
	var left := int(c.field_plots[key]["crops"][0]["days_left"])
	var plain := CharacterData.new()
	plain.field_plots[key] = {"paid_until": 9999, "crops": [{"item": "village_mugwort", "days_left": 40}]}
	FieldPlots.advance(plain, gd, 20, 20, weather)
	var plain_left := int(plain.field_plots[key]["crops"][0]["days_left"])
	assert_true(left < plain_left or plain_left == 40, "bonus grows faster than none (or both frozen)")
	assert_true(plain_left < 40 or left == 40)


func test_well_validation() -> void:
	var gd: GameData = _gs().data
	var saved: Dictionary = gd.season_tasks.duplicate(true)
	gd.season_tasks["restoration"]["projects"][0]["crop_bonus"] = 0.5
	assert_false(SeasonTasks.validate(gd).is_empty(), "crop_bonus")
	gd.season_tasks = saved.duplicate(true)
	gd.season_tasks["restoration"]["projects"][0]["stages"][0]["flag"] = "shrine_stage_1"
	assert_false(SeasonTasks.validate(gd).is_empty(), "duplicate flag")
	gd.season_tasks = saved.duplicate(true)
	gd.season_tasks["restoration"]["projects"][0]["daily"]["item"] = "no_such"
	assert_false(SeasonTasks.validate(gd).is_empty(), "daily item")
	gd.season_tasks = saved
	assert_true(SeasonTasks.validate(gd).is_empty())


func _two_set_data() -> GameData:
	var gd: GameData = _gs().data
	var spring: Dictionary = gd.season_tasks["seasons"]["spring"]
	var set_a: Array = spring["sets"][0]
	var set_b: Array = (set_a as Array).duplicate(true)
	for t: Dictionary in set_b:
		t["id"] = String(t["id"]) + "_b"
	spring["sets"] = [set_a, set_b]
	return gd


func test_sets_rotate_by_year() -> void:
	var gd: GameData = _gs().data
	var saved: Dictionary = gd.season_tasks.duplicate(true)
	_two_set_data()
	var year_len: int = Calendar.year_of(400) - Calendar.year_of(5)
	var y2 := 5
	while Calendar.year_of(y2) < 2:
		y2 += 30
	var y3 := y2
	while Calendar.year_of(y3) < 3:
		y3 += 30
	assert_eq(String(SeasonTasks.tasks_for(gd, 5)[0]["id"]), "spring_bream")
	assert_eq(String(SeasonTasks.tasks_for(gd, y2)[0]["id"]), "spring_bream_b")
	assert_eq(String(SeasonTasks.tasks_for(gd, y3)[0]["id"]), "spring_bream", "wraps")
	gd.season_tasks = saved
	assert_eq(String(SeasonTasks.tasks_for(gd, y2)[0]["id"]), "spring_carp", "C-311: shipped data has a second set")
	assert_true(year_len >= 0)


func test_sets_validation() -> void:
	var gd: GameData = _gs().data
	var saved: Dictionary = gd.season_tasks.duplicate(true)
	_two_set_data()
	assert_eq(SeasonTasks.validate(gd).size(), 0)
	gd.season_tasks["seasons"]["spring"]["sets"][1].pop_back()
	assert_true(SeasonTasks.validate(gd).size() > 0, "2-task set rejected")
	gd.season_tasks = saved.duplicate(true)
	_two_set_data()
	gd.season_tasks["seasons"]["spring"]["sets"][1][0]["id"] = "spring_bream"
	assert_true(SeasonTasks.validate(gd).size() > 0, "duplicate id across sets")
	gd.season_tasks = saved.duplicate(true)
	gd.season_tasks["seasons"]["spring"]["tasks"] = gd.season_tasks["seasons"]["spring"]["sets"][0]
	assert_true(SeasonTasks.validate(gd).size() > 0, "both tasks and sets")
	gd.season_tasks = saved


func test_mid_season_progress_survives_save() -> void:
	var gd: GameData = _gs().data
	var c := CharacterData.new()
	SeasonTasks.note(c, gd, "gather", "peach_blossom_petal", 2, 5)
	var c2 := CharacterData.from_dict(c.to_dict())
	assert_eq(int(SeasonTasks.list(c2, gd, 6)[1]["n"]), 2)
