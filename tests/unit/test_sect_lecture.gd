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
	var hint := "Your sect's elder lectures this month; attend at the sect hall."
	assert_true(Array(Guidance.hints(c, data(), 1.0, 40, {}, {}, c.home_region, 5)).has(hint))
	assert_eq(_lecture_rows(c, 5).size(), 1)
	Sects.attend_lecture(c, data(), seeded_rng(), 5)
	assert_false(Array(Guidance.hints(c, data(), 1.0, 40, {}, {}, c.home_region, 6)).has(hint))
	assert_eq(_lecture_rows(c, 6).size(), 0)
	assert_eq(_lecture_rows(c, Calendar.DAYS_PER_MONTH + 1).size(), 1, "next month")


func test_rogue_gets_no_lecture_hint() -> void:
	var c := new_character()
	assert_eq(_lecture_rows(c, 5).size(), 0)
	assert_false(Array(Guidance.hints(c, data(), 1.0, 40, {}, {}, c.home_region, 5)).has("Your sect's elder lectures this month; attend at the sect hall."))


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
