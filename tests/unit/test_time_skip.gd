extends TestCase
## UI-010: time-skip summaries (TimeSkip), the GameState.time_skipped signal
## and the TimeSkipOverlay.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _gs() -> Node:
	return _root().get_node("GameState")


func _start() -> CharacterData:
	var c := new_character(777)
	c.spiritual_roots = {"fire": 80}  # guarantee a usable root
	c.realm_index = 1  # a month of meditation must not hit the first bottleneck
	_gs().start_session(c)
	return c


## Runs `action` and returns every time_skipped emission as [days, summary].
func _capture(action: Callable) -> Array:
	var got: Array = []
	var bus: Node = _root().get_node("EventBus")
	var listener := func(days: int, summary: Dictionary): got.append([days, summary])
	bus.time_skipped.connect(listener)
	action.call()
	bus.time_skipped.disconnect(listener)
	return got


func test_summary_lists_qi_stones_and_news() -> void:
	var before := {"qi": 10.0, "realm_index": 1, "stage": 2, "stones": 50}
	var after := {"qi": 130.0, "realm_index": 1, "stage": 2, "stones": 80}
	var s := TimeSkip.summarize("Meditating", 30, before, after, "Qi Refining 3", 2)
	assert_eq(s["title"], "Meditating")
	assert_eq(s["days"], 30)
	assert_eq(Array(s["lines"]), ["+120 qi", "+30 spirit stones", "2 pieces of news in the log"])


func test_summary_reports_a_stage_gain_instead_of_qi() -> void:
	var before := {"qi": 90.0, "realm_index": 1, "stage": 2, "stones": 5}
	var after := {"qi": 3.0, "realm_index": 1, "stage": 3, "stones": 0}
	var lines: PackedStringArray = TimeSkip.summarize("Meditating", 30, before, after, "Qi Refining 4", 1)["lines"]
	assert_eq(Array(lines), ["Cultivation rose to Qi Refining 4", "-5 spirit stones", "1 piece of news in the log"])


func test_summary_never_empty() -> void:
	var same := {"qi": 0.0, "realm_index": 0, "stage": 0, "stones": 0}
	assert_eq(Array(TimeSkip.summarize("Travelling", 3, same, same, "Mortal", 0)["lines"]), ["Nothing of note happened."])


func test_should_show_respects_min_days_and_fast_setting() -> void:
	assert_true(TimeSkip.should_show(30, false))
	assert_false(TimeSkip.should_show(30, true))
	assert_false(TimeSkip.should_show(TimeSkip.MIN_DAYS - 1, false))


func test_fast_time_skips_setting_sanitizes_to_bool() -> void:
	var settings_script := preload("res://src/autoload/settings.gd")
	assert_eq(settings_script.sanitize("fast_time_skips", true), true)
	assert_eq(settings_script.sanitize("fast_time_skips", "true"), true)
	assert_eq(settings_script.sanitize("fast_time_skips", 0.3), false)
	assert_eq(settings_script.DEFAULTS["fast_time_skips"], false)


func test_cultivating_emits_time_skipped() -> void:
	var c := _start()
	var got := _capture(func(): _gs().cultivate(Calendar.DAYS_PER_MONTH))
	assert_eq(got.size(), 1)
	assert_eq(got[0][0], Calendar.DAYS_PER_MONTH)
	var summary: Dictionary = got[0][1]
	assert_eq(summary["title"], "Meditating")
	assert_gt(c.qi, 0.0)
	assert_true(String(summary["lines"][0]).begins_with("+") or String(summary["lines"][0]).begins_with("Cultivation rose"), str(summary["lines"]))
	_gs().end_session()


func test_work_and_travel_emit_time_skipped() -> void:
	_start()
	var gs := _gs()
	var prof_id: String = gs.data.professions.keys()[0]
	var got := _capture(func(): gs.work_profession(prof_id, Calendar.DAYS_PER_MONTH))
	assert_eq(got.size(), 1)
	assert_true(String(got[0][1]["title"]).begins_with("Working as a"))
	var route: Dictionary = {}
	for r in Exploration.routes(gs.player, gs.data, gs.current_region):
		if r["ok"]:
			route = r
			break
	assert_false(route.is_empty(), "start region has an open route")
	got = _capture(func(): gs.travel(route["to"]))
	assert_eq(got.size(), 1)
	assert_eq(got[0][1]["title"], "Travelling to %s" % Exploration.region_name(gs.data, route["to"]))
	gs.end_session()


func test_failed_action_and_short_actions_emit_nothing() -> void:
	var c := _start()
	c.spiritual_roots = {}
	assert_eq(_capture(func(): _gs().cultivate(Calendar.DAYS_PER_MONTH)).size(), 0)
	assert_eq(_capture(func(): _gs().explore(["no_such_tag_ui010"])).size(), 0)
	_gs().end_session()


func test_overlay_shows_summary_and_any_press_dismisses() -> void:
	var overlay := TimeSkipOverlay.new()
	_root().add_child(overlay)
	var closed_count := [0]
	overlay.closed.connect(func(): closed_count[0] += 1)
	overlay.show_skip({"title": "Meditating", "days": 30, "lines": PackedStringArray(["+120 qi", "1 piece of news in the log"])})
	assert_true(overlay.visible)
	assert_eq(overlay.summary_text(), "+120 qi\n1 piece of news in the log")
	var release := InputEventJoypadButton.new()
	release.button_index = JOY_BUTTON_A
	release.pressed = false
	assert_false(TimeSkipOverlay.is_dismiss_event(release))
	assert_false(TimeSkipOverlay.is_dismiss_event(InputEventJoypadMotion.new()))
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	assert_true(TimeSkipOverlay.is_dismiss_event(press))
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	assert_true(TimeSkipOverlay.is_dismiss_event(key))
	overlay.close()
	assert_false(overlay.visible)
	assert_eq(closed_count[0], 1)
	overlay.close()
	assert_eq(closed_count[0], 1, "closing twice emits once")
	overlay.free()


func test_hud_shows_overlay_unless_fast_skips() -> void:
	_start()
	var settings: Node = _root().get_node("Settings")
	var fast_before: bool = settings.get_value("fast_time_skips")
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	settings._values["fast_time_skips"] = false
	_gs().cultivate(Calendar.DAYS_PER_MONTH)
	var overlay: TimeSkipOverlay = hud._time_skip
	assert_true(overlay.visible, "overlay after a month of meditation")
	assert_true(overlay.summary_text() != "")
	overlay.close()
	settings._values["fast_time_skips"] = true
	_gs().cultivate(Calendar.DAYS_PER_MONTH)
	assert_false(overlay.visible, "fast time skips hide the overlay")
	settings._values["fast_time_skips"] = fast_before
	hud.free()
	_gs().end_session()


## The overlay on screen survives the HUD rebuild that travel's scene reload
## causes (static _showing_skip; WU-031 had made it per-instance).
func test_overlay_survives_hud_rebuild() -> void:
	_start()
	var settings: Node = _root().get_node("Settings")
	var fast_before: bool = settings.get_value("fast_time_skips")
	settings._values["fast_time_skips"] = false
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	_gs().cultivate(Calendar.DAYS_PER_MONTH)
	assert_true(hud._time_skip.visible, "overlay after a month of meditation")
	hud.free()
	var hud2: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud2)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(hud2._time_skip.visible, "the new HUD finishes showing it")
	hud2._time_skip.close()
	assert_true(hud2.get("_showing_skip").is_empty(), "closing clears it")
	settings._values["fast_time_skips"] = fast_before
	hud2.free()
	_gs().end_session()


## UI-010b: practice, Dao contemplation, treating patients and seclusion get
## their own overlay titles.
func test_other_long_actions_emit_time_skipped() -> void:
	var c := _start()
	var gs := _gs()
	var tech_id := String(c.techniques.keys()[0]) if not c.techniques.is_empty() else ""
	if tech_id == "":
		Techniques.learn(c, gs.data, "basic_breathing")
		tech_id = "basic_breathing"
	var got := _capture(func(): gs.practice_technique(tech_id, Calendar.DAYS_PER_MONTH))
	assert_eq(got.size(), 1)
	assert_eq(got[0][1]["title"], "Practicing the %s" % (gs.data.techniques[tech_id] as TechniqueDef).name)
	got = _capture(func(): gs.treat_patients(Calendar.DAYS_PER_MONTH))
	assert_eq(got.size(), 1)
	assert_eq(got[0][1]["title"], "Treating patients")
	var insight_id: String = gs.data.dao_insights.keys()[0]
	Dao.gain_levels(c, gs.data, insight_id, 1)
	assert_eq(Dao.check_contemplate(c, gs.data, insight_id), "")
	got = _capture(func(): gs.contemplate_dao(insight_id, Calendar.DAYS_PER_MONTH))
	assert_eq(got.size(), 1)
	assert_eq(got[0][1]["title"], "Contemplating the %s" % Dao.def_of(gs.data, insight_id)["name"])
	c.realm_index = gs.data.realm_index_of("qi_refining")
	c.qi = 0.0
	gs.current_region = "misty_forest"
	c.abode = "waterfall_cave"
	got = _capture(func(): gs.cultivate_in_seclusion(Calendar.DAYS_PER_MONTH))
	assert_eq(got.size(), 1)
	assert_eq(got[0][1]["title"], "In seclusion")
	gs.end_session()
