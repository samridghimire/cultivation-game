extends TestCase
## WU-036: the combat report reveals blows one at a time, with hp bars.

const LINES := ["You face the foe.", "You strike for 5.", "Foe hits you for 3.", "You defeat the foe!"]
const TRACE := [[20, 10], [20, 5], [17, 5], [17, 0]]


var _old_animate: Variant = null


func _settings() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Settings")


func _report(animate: bool) -> CombatReport:
	_old_animate = _settings().get_value("animate_fights")
	_settings().set_value("animate_fights", animate)
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
	_done(r)


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
	_done(r)


func test_setting_off_is_instant() -> void:
	var r := _report(false)
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10)
	assert_false(r.playing)
	assert_true(_text(r).contains("You defeat"))
	assert_eq(int(r._enemy_bar.value), 0)
	assert_false(r._close_button.disabled)
	_done(r)


func test_no_trace_is_instant() -> void:
	var r := _report(true)
	r.show_fight("Foe", false, PackedStringArray(LINES), "")
	assert_false(r.playing)
	assert_true(_text(r).contains("You defeat"))
	_done(r)


## Frees the report and restores the player's "Animate fights" setting (set_value saves it).
func _done(r: CombatReport) -> void:
	r.queue_free()
	_settings().set_value("animate_fights", _old_animate)


func test_sound_for_line_by_blow_weight() -> void:
	assert_eq(CombatReport._sound_for_line("You strike the wolf for 30: a crushing blow"), "hit_heavy")
	assert_eq(CombatReport._sound_for_line("You strike the wolf for 2: a glancing blow"), "hit_light")
	assert_eq(CombatReport._sound_for_line("You strike the wolf for 10"), "hit")


func test_styled_line_tones() -> void:
	var warn := UIStyle.CATEGORY_COLORS["warning"].to_html(false)
	var enemy_hit := CombatReport.styled_line("The wolf hits you for 4. (You: 20 hp)")
	assert_true(enemy_hit.contains(warn))
	assert_eq(CombatReport.styled_line("You strike the wolf for 4. (Wolf: 9 hp)"), "You strike the wolf for 4. (Wolf: 9 hp)")
	assert_true(CombatReport.styled_line("The wolf hits you: a crushing blow for 9.").contains(UIStyle.ACCENT.to_html(false)))
	assert_true(CombatReport.styled_line("You hurl a Fire Talisman for 5.").contains(UIStyle.ACCENT.darkened(0.35).to_html(false)))


func test_finishing_line_is_bold_and_large() -> void:
	var t := CombatReport.finishing_line("You defeat the wolf.", Color.RED)
	assert_true(t.begins_with("[b][font_size=19]"))
	assert_true(t.contains("You defeat the wolf."))


## WU-104: the pre-fight rating shows at the top, never for a friendly spar.
func test_report_shows_pre_fight_rating() -> void:
	var r := _report(false)
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10, false, "Rated: Even before the fight.")
	assert_true(r._rated.visible)
	assert_eq(r._rated.text, "Rated: Even before the fight.")
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10, true, "Rated: Even before the fight.")
	assert_false(r._rated.visible, "no rating for a friendly spar")
	_done(r)


func test_rating_line_skips_friendly_spars() -> void:
	var gd := GameData.new()
	var c := CharacterData.new()
	var enemy := {"id": "x", "name": "Foe", "hp": 10, "attack": 1, "defense": 0, "realm": "mortal"}
	assert_true(CombatReport.rating_line(c, gd, enemy).begins_with("Rated: "))
	enemy["friendly"] = true
	assert_eq(CombatReport.rating_line(c, gd, enemy), "")
