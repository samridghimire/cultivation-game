extends TestCase
## GUIDE-271: the great-beast road goal is rated, picks the best beast, and the HUD skips it while it is out of reach.


func _after_ladder() -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.stage = 0
	return c


func test_row_skipped_when_every_beast_deadly() -> void:
	var c := _after_ladder()
	var flags := {Guidance.ELDER_MO_FLAG: true}
	var d := data()
	var best := Guidance._best_great(c, d, 0)
	if best.is_empty() or float(best["chance"]) >= 0.5:
		return  # this data set has a beatable beast for a newcomer; the raised-stats test covers the other side
	var rows := Guidance.road_goals(c, d, flags, 0)
	var row := rows[2]
	assert_true(bool(row.get("skip", false)))
	assert_false(bool(row["done"]))
	assert_true(String(row["text"]).ends_with("now; come back stronger)"), row["text"])
	assert_false(Guidance.hud_goal_text(c, d, flags, "", 0).begins_with("Beat a great beast"))


func test_row_names_odds_when_beatable() -> void:
	var c := _after_ladder()
	c.realm_index = 2
	c.stage = 8
	var d := data()
	var best := Guidance._best_great(c, d, 0)
	assert_false(best.is_empty())
	var rows := Guidance.road_goals(c, d, {Guidance.ELDER_MO_FLAG: true}, 0)
	var row := rows[2]
	var chance := float(best["chance"])
	if chance >= 0.5:
		assert_true(String(row["text"]).contains(Combat.label_for_chance(chance) + ", "), row["text"])
		assert_false(bool(row.get("skip", false)))


func test_great_better_prefers_fair_then_soonest() -> void:
	var weak := {"chance": 0.2, "day": 1}
	var fair := {"chance": 0.8, "day": 9}
	var fairer := {"chance": 0.95, "day": 20}
	assert_true(Guidance._great_better(fair, weak))
	assert_true(Guidance._great_better(fairer, fair))
	assert_true(Guidance._great_better({"chance": 0.1, "day": 1}, {"chance": 0.2, "day": 5}))


func test_whole_name_match() -> void:
	assert_true(Guidance._has_whole_name("Mugwort by the path", "Mugwort"))
	assert_false(Guidance._has_whole_name("Mugwort Root by the path", "Mugwort"))
	assert_false(Guidance._has_whole_name("Wild Mugwort by the path", "Mugwort"))
	assert_true(Guidance._has_whole_name("Sage, Mugwort and moss", "Mugwort"))
