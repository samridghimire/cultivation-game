extends TestCase
## TRIB-001b: the tribulation preparation warning and wave sequence screen.

const CORE := 3  # core_formation, the first realm with a tribulation


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _at_peak(c: CharacterData, d: GameData) -> CharacterData:
	c.realm_index = CORE - 1
	c.stage = d.realms[CORE - 1].stage_count() - 1
	c.qi = d.realms[CORE - 1].qi_required(c.stage)
	c.breakthrough_bonus = 1.0
	return c


func test_preview_lines_warn_by_odds() -> void:
	var safe := TribulationScreen.preview_lines({"waves": 3, "heart_demon": false, "expected_damage": 50, "max_hp": 200, "shield": 0})
	assert_true(safe[0].begins_with("3 waves"), safe[0])
	assert_true(safe[2].contains("should endure"), safe[2])
	var deadly := TribulationScreen.preview_lines({"waves": 4, "heart_demon": true, "expected_damage": 500, "max_hp": 200, "shield": 50})
	assert_true(deadly[0].contains("heart demon"), deadly[0])
	assert_true(deadly[0].begins_with("3 waves"), "the heart demon is not counted as lightning")
	assert_true(deadly[1].contains("+ 50 from shield talismans"), deadly[1])
	assert_true(deadly[2].contains("unlikely to survive"), deadly[2])


func test_wave_line_names_heart_demon() -> void:
	assert_eq(TribulationScreen.wave_line({"kind": "lightning", "damage": 40, "hp_left": 60}, 1), "Lightning wave 2: 40 damage  (60 left)")
	assert_true(TribulationScreen.wave_line({"kind": "heart_demon", "damage": 9, "hp_left": 1}, 3).begins_with("Heart demon"))


func test_show_result_reveals_waves_and_outcome() -> void:
	var screen := TribulationScreen.new()
	var result := {"survived": true, "died": false, "max_hp": 100, "talismans_used": PackedStringArray(["Golden Shield Talisman"]),
		"waves": [{"kind": "lightning", "damage": 30, "hp_left": 70}, {"kind": "lightning", "damage": 40, "hp_left": 30}]}
	screen.show_result("Core Formation", result)
	assert_true(screen.visible)
	var text := screen._log.get_parsed_text()
	assert_true(text.contains("Golden Shield Talisman"), text)
	assert_true(text.contains("Lightning wave 2: 40 damage"), text)
	assert_true(text.contains("You enter Core Formation"), text)
	assert_eq(int(screen._hp_bar.value), 30)
	assert_eq(screen._continue_button.text, "Continue")
	screen._on_continue()
	assert_false(screen.visible)
	screen.free()


func test_prepare_lists_preview_and_cancel_closes() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Tribulant", gs.data, seeded_rng())
	gs.start_session(_at_peak(c, gs.data))
	var screen := TribulationScreen.new()
	screen.open_prepare()
	assert_true(screen._confirm_button.visible)
	var text := screen._log.get_parsed_text()
	assert_true(text.contains("waves of heavenly lightning"), text)
	assert_true(text.contains("Readied shield talismans: none"), text)
	screen._on_continue()
	assert_false(screen.visible)
	assert_eq(c.realm_index, CORE - 1, "not attempted")
	screen.free()
	gs.end_session()


func test_meditation_spot_warns_before_tribulation_and_game_state_reports_it() -> void:
	var gs := _root().get_node("GameState")
	var bus := _root().get_node("EventBus")
	var c := CharacterFactory.create("Tribulant", gs.data, seeded_rng())
	gs.start_session(_at_peak(c, gs.data))
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var asked: Array = []
	var ask_cb := func(): asked.append(true)
	bus.tribulation_prepare_requested.connect(ask_cb)
	for option: Dictionary in spot.get_options():
		if String(option["label"]).begins_with("Attempt breakthrough"):
			assert_true(String(option["label"]).contains("Tribulation"), option["label"])
			option["action"].call()
	bus.tribulation_prepare_requested.disconnect(ask_cb)
	spot.free()
	assert_eq(asked, [true])
	assert_eq(c.realm_index, CORE - 1, "choosing the option only warns")
	var endured: Array = []
	var end_cb := func(realm_name: String, result: Dictionary): endured.append([realm_name, result])
	bus.tribulation_endured.connect(end_cb)
	gs.attempt_breakthrough()
	bus.tribulation_endured.disconnect(end_cb)
	assert_eq(endured.size(), 1)
	assert_eq(endured[0][0], gs.data.realms[CORE].name)
	assert_false((endured[0][1]["waves"] as Array).is_empty())
	gs.end_session()
