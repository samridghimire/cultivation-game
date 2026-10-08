extends TestCase
## WU-036: the combat report reveals blows one at a time, with hp bars.

const LINES := ["You face the foe.", "You strike for 5.", "Foe hits you for 3.", "You defeat the foe!"]
const TRACE := [[20, 10], [20, 5], [17, 5], [17, 0]]


func _report(animate: bool) -> CombatReport:
	var settings: Node = (Engine.get_main_loop() as SceneTree).root.get_node("Settings")
	settings.set_value("animate_fights", animate)
	var r := CombatReport.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	return r


func _text(r: CombatReport) -> String:
	return r._log.get_parsed_text()


func test_animated_report_reveals_line_by_line() -> void:
	var r := _report(true)
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10)
	assert_true(r.playing)
	assert_true(r._close_button.disabled, "Continue waits for the reveal")
	assert_eq(int(r._enemy_bar.value), 10)
	r.tick()
	r.tick()
	assert_true(_text(r).contains("You strike"))
	assert_false(_text(r).contains("You defeat"), "fewer lines than the log")
	assert_eq(int(r._enemy_bar.value), 5)
	r.tick()
	assert_eq(int(r._player_bar.value), 17)
	r.tick()
	assert_false(r.playing)
	assert_false(r._close_button.disabled)
	assert_true(_text(r).contains("You defeat"))
	assert_eq(int(r._enemy_bar.value), 0)
	r.queue_free()


func test_skip_shows_everything() -> void:
	var r := _report(true)
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(["a herb"]), TRACE, 20, 10)
	r.tick()
	r.skip()
	assert_false(r.playing)
	assert_true(_text(r).contains("You defeat"))
	assert_true(_text(r).contains("Spoils: a herb"))
	assert_eq(int(r._player_bar.value), 17)
	assert_false(r._close_button.disabled)
	r.queue_free()


func test_setting_off_is_instant() -> void:
	var r := _report(false)
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10)
	assert_false(r.playing)
	assert_true(_text(r).contains("You defeat"))
	assert_eq(int(r._enemy_bar.value), 0)
	assert_false(r._close_button.disabled)
	r.queue_free()


func test_no_trace_is_instant() -> void:
	var r := _report(true)
	r.show_fight("Foe", false, PackedStringArray(LINES), "")
	assert_false(r.playing)
	assert_true(_text(r).contains("You defeat"))
	r.queue_free()
