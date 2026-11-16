extends TestCase
## WU-548: a friendly spar's report shows bars, a result block, no "Defeated" tag, and the bout's loser kneels.


func test_spar_result_lines() -> void:
	var a := Mentorship.spar_result_lines("Ma", true, PackedStringArray(["Iron Fist"]), 3, 2, PackedStringArray(["Iron Fist reaches level 2"]), "Ma nods: you graduate.")
	assert_eq(a[0], "You held your own.")
	assert_true(a.has("Iron Fist: +3 practice"))
	assert_true(a.has("Ma nods: you graduate."))
	var b := Mentorship.spar_result_lines("Ma", false, PackedStringArray(), 3, 0)
	assert_eq(b.size(), 1)
	assert_eq(b[0], "Ma got the better of you.")


func test_spar_report_shows_stage_result_and_kneel() -> void:
	var old: Variant = (Engine.get_main_loop() as SceneTree).root.get_node("Settings").get_value("animate_fights")
	(Engine.get_main_loop() as SceneTree).root.get_node("Settings").set_value("animate_fights", false)
	var r := CombatReport.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	r.show_fight("Ma", false, PackedStringArray(["Round 1: a.", "Round 2: b."]), "", PackedStringArray(), [[40, 30], [38, 20]], 40, 30, true)
	r.show_spar_result(PackedStringArray(["Ma got the better of you.", "Iron Fist: +3 practice"]))
	assert_true(r._stage.visible)
	assert_true(r._stage.is_kneeling(0))
	assert_false(r._stage.is_kneeling(1))
	assert_false(r._stage.is_fallen(0) or r._stage.is_fallen(1), "nobody lies defeated in a spar")
	var text := r._log.get_parsed_text()
	assert_true(text.contains("got the better of you") and text.contains("Iron Fist: +3 practice"))
	assert_true(r._log.custom_minimum_size.y <= CombatReport.log_room(720.0) + 1.0, "fits 1280x720")
	r.queue_free()
	(Engine.get_main_loop() as SceneTree).root.get_node("Settings").set_value("animate_fights", old)
