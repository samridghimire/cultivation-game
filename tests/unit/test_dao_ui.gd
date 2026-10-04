extends TestCase
## DAO-001b: Dao insights on the character sheet and contemplation at meditation spots.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _first_insight(gs: Node) -> String:
	return String(gs.data.dao_insights.keys()[0])


func test_known_ids_and_progress_text() -> void:
	var d := data()
	var c := new_character()
	assert_eq(Dao.known_ids(c, d).size(), 0)
	var insight_id := String(d.dao_insights.keys()[0])
	Dao.gain_levels(c, d, insight_id, 1)
	assert_eq(Dao.known_ids(c, d), [insight_id] as Array[String])
	assert_eq(Dao.progress_text(c, d, insight_id), "0/%d toward level 2" % int(Dao.progress_needed(c, d, insight_id)))
	Dao.gain_levels(c, d, insight_id, Dao.max_level(d))
	assert_eq(Dao.progress_text(c, d, insight_id), "fully comprehended")


func test_sheet_lists_insights_with_progress() -> void:
	var gs := _gs()
	var c := new_character()
	gs.start_session(c)
	var sheet := CharacterSheet.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(sheet)
	sheet.open()
	assert_true(sheet._text.get_parsed_text().contains("None glimpsed yet"))
	var insight_id := _first_insight(gs)
	Dao.gain_levels(c, gs.data, insight_id, 1)
	sheet.open()
	var text: String = sheet._text.get_parsed_text()
	var name: String = Dao.def_of(gs.data, insight_id)["name"]
	assert_true(text.contains("%s 1/%d" % [name, Dao.max_level(gs.data)]), text)
	assert_true(text.contains("toward level 2"), text)
	sheet.free()
	gs.end_session()


func test_meditation_spot_offers_contemplation() -> void:
	var gs := _gs()
	var c := new_character()
	gs.start_session(c)
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var contemplate := func() -> Array:
		return spot.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Contemplate"))
	assert_eq(contemplate.call().size(), 0, "nothing to contemplate before glimpsing a Dao")
	var insight_id := _first_insight(gs)
	Dao.gain_levels(c, gs.data, insight_id, 1)
	var entries: Array = contemplate.call()
	assert_eq(entries.size(), 1)
	assert_false(entries[0].get("disabled", false))
	var day_before: int = gs.get_node("/root/GameClock").total_days
	entries[0]["action"].call()
	assert_eq(gs.get_node("/root/GameClock").total_days, day_before + Calendar.DAYS_PER_MONTH)
	assert_gt(Dao.progress(c, insight_id) + float(Dao.level(c, insight_id) - 1), 0.0)
	Dao.gain_levels(c, gs.data, insight_id, Dao.max_level(gs.data))
	entries = contemplate.call()
	assert_true(entries[0]["disabled"], "a fully comprehended Dao is disabled")
	assert_true(String(entries[0]["label"]).contains("fully comprehended"))
	spot.free()
	gs.end_session()
