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
	assert_eq(lines.size(), 2, "task + thanks")
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
