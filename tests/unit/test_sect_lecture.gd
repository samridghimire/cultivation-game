extends TestCase
## SECT-005: the elder's monthly lecture.


func _disciple(sect_id: String = "azure_cloud_sect") -> CharacterData:
	var c := new_character()
	c.spiritual_roots = {"fire": 80}
	c.realm_index = 1
	Sects.join(c, data(), sect_id)
	return c


func test_rogue_is_refused() -> void:
	var c := new_character()
	assert_true(Sects.check_lecture(c, data(), 0) != "")
	assert_false(Sects.attend_lecture(c, data(), seeded_rng(), 0)["ok"])


func test_once_per_month() -> void:
	var c := _disciple()
	assert_eq(Sects.check_lecture(c, data(), 5), "")
	assert_true(Sects.attend_lecture(c, data(), seeded_rng(), 5)["ok"])
	assert_true(Sects.check_lecture(c, data(), 20) != "", "same month")
	assert_eq(Sects.check_lecture(c, data(), Calendar.DAYS_PER_MONTH + 1), "", "next month")


func test_qi_matches_the_rate() -> void:
	var c := _disciple()
	var lecture := Sects.lecture_def(c, data())
	var expected := Cultivation.qi_per_day(c, data(), 1.5) * int(lecture["qi_days"])
	var before := c.qi
	var result := Sects.attend_lecture(c, data(), seeded_rng(), 0, 1.5)
	assert_eq(result["qi"], int(expected))
	assert_true(absf((c.qi - before) - expected) < 1.0)


func test_insight_glimpsed_when_roll_succeeds() -> void:
	var d := GameData.load_from_dir()
	(d.sects["azure_cloud_sect"] as SectDef).lecture["insight_chance"] = 1.0
	var c := new_character()
	c.realm_index = 1
	Sects.join(c, d, "azure_cloud_sect")
	var result := Sects.attend_lecture(c, d, seeded_rng(), 0)
	assert_eq(result["insight_id"], "sword_dao")
	assert_eq(Dao.level(c, "sword_dao"), 1)


func test_no_insight_when_chance_is_zero() -> void:
	var d := GameData.load_from_dir()
	(d.sects["azure_cloud_sect"] as SectDef).lecture["insight_chance"] = 0.0
	var c := new_character()
	c.realm_index = 1
	c.attributes["comprehension"] = 10
	Sects.join(c, d, "azure_cloud_sect")
	assert_eq(Sects.attend_lecture(c, d, seeded_rng(), 0)["insight_id"], "")


func test_lecture_month_survives_save() -> void:
	var c := _disciple()
	Sects.attend_lecture(c, data(), seeded_rng(), 0)
	var loaded := CharacterData.from_dict(c.to_dict())
	assert_true(Sects.check_lecture(loaded, data(), 0) != "")


func test_validation() -> void:
	var d := GameData.load_from_dir()
	assert_eq(Sects.validate_lectures(d).size(), 0)
	var lecture: Dictionary = (d.sects["azure_cloud_sect"] as SectDef).lecture
	lecture["days"] = 0
	lecture["insight_chance"] = 2.0
	lecture["insights"] = ["no_such_dao"]
	assert_eq(Sects.validate_lectures(d).size(), 3)


# --- GUIDE-013: surfacing the lecture ----------------------------------------

func _lecture_rows(c: CharacterData, today: int) -> Array:
	var rows: Array = []
	for row: Dictionary in Guidance.journal(c, data(), {}, today, c.home_region):
		if String(row["text"]).begins_with("Attend "):
			rows.append(row)
	return rows


func test_lecture_hint_and_journal_only_when_attendable() -> void:
	var c := _disciple()
	assert_true(_has_lecture_line(Guidance.hints(c, data(), 1.0, 40, {}, {}, c.home_region, 5)))
	assert_eq(_lecture_rows(c, 5).size(), 1)
	Sects.attend_lecture(c, data(), seeded_rng(), 5)
	assert_false(_has_lecture_line(Guidance.hints(c, data(), 1.0, 40, {}, {}, c.home_region, 6)))
	assert_eq(_lecture_rows(c, 6).size(), 0)
	assert_eq(_lecture_rows(c, Calendar.DAYS_PER_MONTH + 1).size(), 1, "next month")


func test_rogue_gets_no_lecture_hint() -> void:
	var c := new_character()
	assert_eq(_lecture_rows(c, 5).size(), 0)
	assert_false(_has_lecture_line(Guidance.hints(c, data(), 1.0, 40, {}, {}, c.home_region, 5)))


func test_lectures_attended_counts_and_milestone_at_twelve() -> void:
	var c := _disciple()
	for i in 12:
		assert_eq(LifeStats.get_stat(c, "lectures_attended"), i)
		assert_true(Sects.attend_lecture(c, data(), seeded_rng(), i * Calendar.DAYS_PER_MONTH)["ok"])
		var reached := Milestones.newly_reached(c, data(), {})
		assert_eq(reached.has("attentive_disciple"), i == 11)
		if i == 11:
			break
	assert_eq(LifeStats.get_stat(c, "lectures_attended"), 12)


func test_lecture_line_picks_by_month_and_fills_names() -> void:
	var lecture := {"elder": "Elder Wu", "topic": "rain", "lines": ["{elder} on {topic} one.", "two."]}
	assert_eq(Sects.lecture_line(lecture, 0), "Elder Wu on rain one.")
	assert_eq(Sects.lecture_line(lecture, 3), "Two.")
	assert_eq(Sects.lecture_line({"name": "x", "lines": ["{elder}: {topic}"]}, 0), "The elder: the lesson")
	assert_eq(Sects.lecture_line({"elder": "the Blood Elder", "lines": ["{elder} smiles."]}, 0), "The Blood Elder smiles.")


func test_lecture_line_falls_back_when_absent() -> void:
	assert_eq(Sects.lecture_line({"name": "x"}, 4), "")


func test_every_sect_lecture_has_enough_lines() -> void:
	for sect: SectDef in data().sects.values():
		if sect.lecture.is_empty():
			continue
		assert_true((sect.lecture.get("lines", []) as Array).size() >= 8, "%s needs 8+ lecture lines" % sect.id)
		var c := new_character()
		c.realm_index = 1
		Sects.join(c, data(), sect.id)
		assert_true(String(Sects.attend_lecture(c, data(), seeded_rng(), 5)["line"]) != "", sect.id)


## SECT-039: in the hall's region an open lecture leads the hints, ahead of the mission board and meditation lines.
func test_open_lecture_leads_hints_in_hall_region() -> void:
	var c := _disciple()
	var hall := Sects.home_region(data(), String(c.sect["id"]))
	var here := Array(Guidance.hints(c, data(), 1.0, 40, {}, {}, hall, 5))
	assert_true(_has_lecture_line(here))
	var elsewhere := ""
	for rid: String in data().regions:
		if rid != hall:
			elsewhere = rid
			break
	var away := Array(Guidance.hints(c, data(), 1.0, 40, {}, {}, elsewhere, 5))
	assert_true(_has_lecture_line(away), "still listed away from the hall, but not first")
	assert_true(_lecture_index(away) >= _lecture_index(here))
	var board_idx := -1
	for i in here.size():
		if String(here[i]).contains("mission"):
			board_idx = i
			break
	if board_idx >= 0:
		assert_true(_lecture_index(here) < board_idx)
	var count := 0
	for h: String in here:
		if h.begins_with("Lecture at the "):
			count += 1
	assert_eq(count, 1, "listed once")


## SECT-039: each start-region sect's rank-1 trial foe is a sparring foe tuned at or below full power.
func test_rank_one_trial_foes_are_tuned_sparring() -> void:
	for sect_id in ["azure_cloud_sect", "blood_lotus_sect", "myriad_treasure_pavilion"]:
		var def: SectDef = data().sects[sect_id]
		var foe: Dictionary = data().enemies[String(def.ranks[1]["trial"])]
		assert_false(bool(foe.get("lethal", true)), sect_id)
		assert_true(float(foe.get("power_mult", 1.0)) <= 1.0, sect_id)
		assert_true(int(def.ranks[1]["contribution"]) >= 250, sect_id)


## SIM-033: the lecture line names the hall and the month, for a member anywhere.
func _has_lecture_line(hints: Array) -> bool:
	for h: String in hints:
		if h.begins_with("Lecture at the ") and h.contains(": this month"):
			return true
	return false


func test_lecture_line_names_the_hall() -> void:
	var c := _disciple()
	var hall := Sects.hall_name(data(), Sects.home_region(data(), String(c.sect["id"])), c)
	var lines := Array(Guidance.hints(c, data(), 1.0, 40, {}, {}, "qingshi_village", 5))
	var found := ""
	for h: String in lines:
		if h.begins_with("Lecture at the "):
			found = h
	assert_true(found.begins_with("Lecture at the %s: this month" % hall), found)


func _lecture_index(hints: Array) -> int:
	for i in hints.size():
		if String(hints[i]).begins_with("Lecture at the "):
			return i
	return -1
