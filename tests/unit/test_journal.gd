extends TestCase
## Guidance.journal (GUIDE-001): sectioned "what can I do now?" entries.


func _fresh() -> CharacterData:
	var c := new_character()
	c.realm_index = 0
	c.stage = 0
	c.qi = 0.0
	c.inventory = {}
	return c


func _entries(c: CharacterData, today: int = 0, events: Array = [], region: String = "qingshi_village") -> Array[Dictionary]:
	return Guidance.journal(c, data(), {}, today, region, 1.0, {}, events)


func _sections(entries: Array[Dictionary]) -> Dictionary:
	var out := {}
	for e in entries:
		out[e["section"]] = true
	return out


func _find(entries: Array[Dictionary], needle: String) -> Dictionary:
	for e in entries:
		if String(e["text"]).contains(needle):
			return e
	return {}


func test_newcomer_has_core_sections_and_no_sect() -> void:
	var sections := _sections(_entries(_fresh()))
	assert_true(sections.has("Next steps"))
	assert_true(sections.has("Breakthrough"))
	assert_true(sections.has("Milestones"))
	assert_false(sections.has("Sect"))
	assert_false(sections.has("Deeds"))
	assert_false(sections.has("World events"))


func test_sect_duty_is_a_warning_when_unmet_late_in_the_month() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 2
	var found := ""
	for sect: SectDef in d.sects.values():
		for r in sect.ranks.size():
			if int(sect.ranks[r].get("monthly_duty", 0)) > 0 and found == "":
				found = sect.id
				c.sect = {"id": sect.id, "rank": r, "contribution": 0, "spent": 0, "month_earned": 0}
	assert_true(found != "")
	var duty := Sects.monthly_duty(c, d)
	c.sect["month_earned"] = duty - 1
	c.age_days = 365 * 20 * 0 + 6000 + 24  # day 24 of the month: 6 days left
	c.age_days -= c.age_days % Calendar.DAYS_PER_MONTH
	c.age_days += 24
	var line := _find(_entries(c), "Monthly duty")
	assert_eq(line["text"], "Monthly duty: %d / %d contribution, 6 days left this month." % [duty - 1, duty])
	assert_eq(line["tone"], "warning")
	c.sect["month_earned"] = duty
	assert_eq(_find(_entries(c), "Monthly duty")["tone"], "normal")


func test_missions_ready_and_on_cooldown() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 2
	c.sect = {"id": d.sects.keys()[0], "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0}
	var ids := Sects.available_missions(c, d)
	var ready := ""
	for id in ids:
		if Sects.check_mission(c, d, id) == "":
			ready = id
			break
	assert_true(ready != "")
	assert_true(_find(_entries(c), "Ready:")["tone"] == "normal")
	c.mission_cooldowns[ready] = c.age_days + 9
	var line := _find(_entries(c), "again in 9 days")
	assert_eq(line["tone"], "dim")
	assert_eq(line["section"], "Sect")


func test_deed_cooldown_matches_deeds_check() -> void:
	var d := data()
	var c := _fresh()
	var deed: Dictionary = d.deeds["donate_stones"]
	c.deed_days["donate_stones"] = 100
	assert_eq(Deeds.cooldown_left(c, deed, 103), 27)
	var line := _find(_entries(c, 103), "again in 27 days")
	assert_eq(line["section"], "Deeds")
	assert_eq(line["tone"], "dim")
	assert_true(Deeds.check(c, d, deed, {}, 103).contains("27 days"))
	assert_eq(Deeds.cooldown_left(c, deed, 200), 0)


func test_tournament_in_region_can_be_entered_by_cultivators_only() -> void:
	var d := data()
	if not d.world_events.has("sect_tournament"):
		return
	var events: Array = [{"id": "sect_tournament", "region": "qingshi_village", "start_day": 0, "end_day": 20}]
	var c := _fresh()
	c.realm_index = 1
	assert_true(_find(_entries(c, 5, events), "you can enter").size() > 0)
	assert_true(_find(_entries(c, 5, events), "Sect Tournament here (15 days left)").size() > 0)
	c.realm_index = 0
	assert_true(_find(_entries(c, 5, events), "Only cultivators").size() > 0)
	assert_true(_find(_entries(c, 5, events, "misty_forest"), "Sect Tournament").is_empty())


func test_breakthrough_and_milestone_lines() -> void:
	var c := _fresh()
	c.qi = 12.0
	var entries := _entries(c)
	assert_true(_find(entries, "Qi: 12 / ").size() > 0)
	assert_true(_find(entries, "Milestones: 0 of ").size() > 0)


func test_journal_does_not_mutate_character() -> void:
	var c := _fresh()
	c.deed_days["donate_stones"] = 1
	var before := c.to_dict()
	_entries(c, 5)
	assert_eq(c.to_dict(), before)
