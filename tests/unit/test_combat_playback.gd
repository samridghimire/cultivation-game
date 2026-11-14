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
func test_easy_fight_shows_summary_not_blows() -> void:
	var r := _report(true)
	r.summary = ["You beat Foe in 2 exchanges, losing 3 hp.", "Your best blow: a blow for 5."] as Array[String]
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(["a herb"]), TRACE, 20, 10)
	assert_false(r.playing, "no blow-by-blow playback")
	var t := _text(r)
	assert_true(t.contains("You beat Foe in 2 exchanges"))
	assert_true(t.contains("You defeat the foe!"), "the collapses line stays")
	assert_true(t.contains("Spoils: a herb"))
	assert_false(t.contains("Foe hits you for 3"), "blows hidden")
	assert_true(r._blows_button.visible)
	assert_eq(int(r._enemy_bar.value), 0)
	assert_false(r._close_button.disabled)
	_done(r)


func test_show_every_blow_expands_in_place() -> void:
	var r := _report(true)
	r.summary = ["You beat Foe in 2 exchanges, losing 3 hp."] as Array[String]
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(["a herb"]), TRACE, 20, 10)
	r.show_every_blow()
	var t := _text(r)
	assert_true(t.contains("Foe hits you for 3"))
	assert_false(t.contains("You beat Foe in 2"))
	assert_true(t.contains("Spoils: a herb"))
	assert_false(r._blows_button.visible)
	_done(r)


func test_close_fight_shows_full_log() -> void:
	var r := _report(false)
	r.summary = [] as Array[String]
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10)
	assert_true(_text(r).contains("Foe hits you for 3"))
	assert_false(r._blows_button.visible)
	_done(r)


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
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10, false, "Rated before the fight: Even, 55 in 100.")
	assert_true(r._rated.visible)
	assert_eq(r._rated.text, "Rated before the fight: Even, 55 in 100.")
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10, true, "Rated before the fight: Even, 55 in 100.")
	assert_false(r._rated.visible, "no rating for a friendly spar")
	_done(r)


func test_rating_line_skips_friendly_spars() -> void:
	var gd := GameData.new()
	var c := CharacterData.new()
	var enemy := {"id": "x", "name": "Foe", "hp": 10, "attack": 1, "defense": 0, "realm": "mortal"}
	assert_true(CombatReport.rating_line(c, gd, enemy).begins_with("Rated before the fight: "))
	enemy["friendly"] = true
	assert_eq(CombatReport.rating_line(c, gd, enemy), "")


func test_blow_info_from_trace() -> void:
	var hit := DuelStage.blow_info([20, 10], [20, 5], "You strike for 5. (Foe: 5 hp)")
	assert_eq(hit, {"side": 1, "amount": 5, "kind": "hit"})
	var crit := DuelStage.blow_info([20, 10], [14, 10], "Foe hits you critically for 6.")
	assert_eq(crit, {"side": -1, "amount": 6, "kind": "crit"})
	assert_eq(DuelStage.blow_info([20, 10], [20, 9], "You strike for 1: a glancing blow")["kind"], "glance")
	assert_eq(DuelStage.blow_info([20, 10], [20, 6], "You strike for 4: a solid blow")["kind"], "solid")
	assert_eq(DuelStage.blow_info([20, 10], [20, 10], "Foe evades your strike.")["side"], 0)


func test_technique_of_line() -> void:
	assert_eq(DuelStage.technique_of("You strike with Cloud Palm critically: a solid blow for 9. (Boar: 3 hp)"), "Cloud Palm")
	assert_eq(DuelStage.technique_of("Wolf attacks with Pounce for 4. (You: 5 hp)"), "Pounce")
	assert_eq(DuelStage.technique_of("You strike for 5."), "")


func test_blow_floats_numbers_and_skip_clears() -> void:
	var r := _report(true)
	r.show_fight("Foe", true, PackedStringArray(LINES), "", PackedStringArray(), TRACE, 20, 10)
	r.tick()
	r.tick()
	assert_gt(r._stage.floater_count(), 0)
	r.skip()
	assert_eq(r._stage.floater_count(), 0)
	_done(r)


func test_five_blow_report_is_shorter() -> void:
	assert_true(CombatReport.log_height(8) < 8 * 26.0 + 20.0)


## WU-491: the report uses the HUD's wording and odds.
func test_rating_line_matches_hud_odds() -> void:
	var gd := GameData.new()
	var c := CharacterData.new()
	var enemy := {"id": "x", "name": "Foe", "hp": 10, "attack": 1, "defense": 0, "realm": "mortal", "lethal": true}
	var expect := UIStyle.odds_text(c, gd, enemy, true)
	assert_eq(CombatReport.rating_line(c, gd, enemy), "Rated before the fight: %s." % expect)
	assert_true(expect.ends_with("to the death"))
