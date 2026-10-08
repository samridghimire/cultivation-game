extends TestCase
## REL-001: silent autosave slot, once per day, respects the setting and death.

func _setup() -> Array:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var saves := root.get_node("SaveManager")
	saves.delete_save("autosave")
	saves._last_autosave_day = -1
	gs.start_session(CharacterFactory.create("Auto", gs.data, seeded_rng(5)))
	return [gs, saves]


func _cleanup(gs: Node, saves: Node) -> void:
	saves.delete_save("autosave")
	saves._last_autosave_day = -1
	gs.end_session()


func test_once_per_day() -> void:
	var s := _setup()
	var gs: Node = s[0]
	var saves: Node = s[1]
	assert_true(saves.autosave(), "first autosave writes")
	assert_true(saves.has_save("autosave"))
	assert_false(saves.autosave(), "same day is skipped")
	assert_true(saves.autosave(true), "force bypasses the limit")
	gs.get_node("/root/GameClock").advance(1)
	assert_true(saves.autosave(), "next day saves again")
	_cleanup(gs, saves)


func test_dead_player_and_setting() -> void:
	var s := _setup()
	var gs: Node = s[0]
	var saves: Node = s[1]
	var settings := gs.get_node("/root/Settings")
	settings._values["autosave"] = false
	assert_false(saves.autosave(), "setting off")
	settings._values["autosave"] = true
	gs.player.alive = false
	assert_false(saves.autosave(), "dead player")
	gs.player.alive = true
	_cleanup(gs, saves)


func test_travel_autosaves_and_loads() -> void:
	var s := _setup()
	var gs: Node = s[0]
	var saves: Node = s[1]
	var target := ""
	for route: Dictionary in gs.data.regions[gs.current_region].get("routes", []):
		if Exploration.check_travel(gs.player, gs.data, gs.current_region, String(route["to"]))["ok"]:
			target = String(route["to"])
			break
	if target != "":
		gs.travel(target)
		assert_true(saves.has_save("autosave"), "travel autosaved")
		gs.player.qi = 0.0
		gs.current_region = "elsewhere"
		assert_true(saves.load_game("autosave"))
		assert_eq(gs.current_region, target)
	_cleanup(gs, saves)


func test_final_death_overwrites_saves_and_blocks_loading() -> void:
	var s := _setup()
	var gs: Node = s[0]
	var saves: Node = s[1]
	assert_true(saves.save_game("_test_final"))
	assert_true(saves.autosave())
	gs._kill("Test death.")
	for slot in ["_test_final", "autosave"]:
		assert_false(bool(saves.read_meta(slot).get("alive", true)), slot + " records the fall")
		assert_false(saves.load_game(slot), slot + " refuses to load")
	assert_true(LoadScreen.describe_slot(saves.read_meta("_test_final")).contains("fallen at age"))
	saves.delete_save("_test_final")
	_cleanup(gs, saves)


func test_new_character_death_leaves_other_saves_alone() -> void:
	var s := _setup()
	var gs: Node = s[0]
	var saves: Node = s[1]
	assert_true(saves.save_game("_test_other"))
	assert_true(saves.autosave())
	# A different character starts without loading: its death must not touch them.
	gs.start_session(CharacterFactory.create("Other", gs.data, seeded_rng(6)))
	assert_eq(saves.current_slot, "", "a new session forgets the old slot")
	gs._kill("Test death.")
	for slot in ["_test_other", "autosave"]:
		assert_true(bool(saves.read_meta(slot).get("alive", false)), slot + " keeps the other character")
	saves.delete_save("_test_other")
	_cleanup(gs, saves)


func test_suspend_save_is_rate_limited() -> void:
	var s := _setup()
	var gs: Node = s[0]
	var saves: Node = s[1]
	saves._last_suspend_save_msec = -1
	assert_true(saves.autosave_on_suspend(), "first suspend writes")
	assert_true(saves.has_save("autosave"))
	assert_false(saves.autosave_on_suspend(), "second within 60 s does not")
	saves._last_suspend_save_msec = Time.get_ticks_msec() - SaveManager.SUSPEND_SAVE_INTERVAL_MSEC - 1
	assert_true(saves.autosave_on_suspend(), "after the interval it saves again")
	_cleanup(gs, saves)
	saves._last_suspend_save_msec = -1


func test_suspend_save_refuses_without_session() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var saves := (Engine.get_main_loop() as SceneTree).root.get_node("SaveManager")
	gs.end_session()
	saves._last_suspend_save_msec = -1
	assert_false(saves.autosave_on_suspend(), "no session")
	assert_eq(saves._last_suspend_save_msec, -1)
