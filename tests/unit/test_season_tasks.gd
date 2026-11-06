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
	gd.season_tasks["seasons"]["spring"]["tasks"][0]["kind"] = "dance"
	gd.season_tasks["seasons"]["winter"]["tasks"].pop_back()
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
	for t: Dictionary in SeasonTasks.def(gd, day)["tasks"]:
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
		for t: Dictionary in SeasonTasks.def(gs.data, day)["tasks"]:
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
		for task: Dictionary in gd.season_tasks["seasons"][season]["tasks"]:
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
