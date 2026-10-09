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
	assert_true(_find(_entries(c, 5, events, "misty_forest"), "Sect Tournament here").is_empty())


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


func test_peak_of_highest_realm_is_not_a_bottleneck_warning() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = d.realms.size() - 1
	c.stage = d.realms[c.realm_index].stage_count() - 1
	c.qi = Cultivation.qi_required(c, d)
	var texts: Array = _entries(c).filter(func(e: Dictionary) -> bool: return e["section"] == "Breakthrough").map(func(e: Dictionary) -> String: return e["text"])
	assert_false(texts.has("You are at a bottleneck: break through to go further."))
	if Cultivation.is_at_bottleneck(c, d):
		assert_true(texts.has("You stand at the peak of the highest realm known."))


func test_pill_bonus_and_sect_status_lines() -> void:
	var d := data()
	var c := _fresh()
	c.breakthrough_bonus = 0.15
	assert_eq(_find(_entries(c), "Pill bonus active")["text"], "Pill bonus active: +15%")
	var sect: SectDef = d.sects.values()[0]
	c.sect = {"id": sect.id, "rank": 0, "contribution": 42, "spent": 0, "month_earned": 0}
	var line := _find(_entries(c), "42 contribution")
	assert_true(String(line["text"]).contains(sect.name))


func test_duty_reminder_only_in_sect_section_and_grace_is_not_warned() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 2
	for sect: SectDef in d.sects.values():
		for r in sect.ranks.size():
			if int(sect.ranks[r].get("monthly_duty", 0)) > 0 and c.is_rogue():
				c.sect = {"id": sect.id, "rank": r, "contribution": 0, "spent": 0, "month_earned": 0}
	assert_false(c.is_rogue())
	c.age_days = 6000 - 6000 % Calendar.DAYS_PER_MONTH + 25
	var reminder := Sects.duty_reminder(c, d)
	assert_true(reminder != "")
	for e in _entries(c):
		if e["section"] == "Next steps":
			assert_false(e["text"] == reminder)
	assert_eq(_find(_entries(c), "Monthly duty")["tone"], "warning")
	c.sect["duty_grace"] = true
	assert_eq(_find(_entries(c), "Monthly duty")["tone"], "normal")


func _flags_journal(c: CharacterData, flags: Dictionary, today: int) -> Array[Dictionary]:
	return Guidance.journal(c, data(), flags, today, "qingshi_village")


func _has_section(entries: Array[Dictionary], section: String) -> bool:
	return _sections(entries).has(section)


func test_open_admitting_secret_realm_is_an_opportunity() -> void:
	var c := _fresh()
	c.realm_index = data().realm_index_of("qi_refining")
	var open_day: int = int(data().secret_realms["peach_blossom_grotto"]["offset_years"]) * Calendar.DAYS_PER_YEAR + 10
	var entry := _find(_flags_journal(c, {}, open_day), "Peach Blossom")
	assert_eq(entry.get("section", ""), "Opportunities")
	assert_true(String(entry.get("text", "")).contains("is open"))
	var mortal := _fresh()
	assert_true(_find(_flags_journal(mortal, {}, open_day), "Peach Blossom").is_empty())


func test_claimed_inheritance_is_not_listed() -> void:
	var c := _fresh()
	c.realm_index = data().realm_index_of("qi_refining")
	var id: String = data().inheritances.keys()[0]
	var def: Dictionary = data().inheritances[id]
	var today := Inheritances.appears_day(def)
	var name_text := String(def["name"])
	assert_false(_find(_flags_journal(c, {}, today), name_text).is_empty())
	var flags := {Inheritances.claimed_flag(id): true}
	assert_true(_find(_flags_journal(c, flags, today), name_text).is_empty())


func test_errand_listed_until_done() -> void:
	var c := _fresh()
	assert_false(_has_section(_flags_journal(c, {}, 0), "Errands"))
	var asked := {"errand_lan_asked": true}
	assert_false(_find(_flags_journal(c, asked, 0), "Herbalist Lan").is_empty())
	asked["errand_lan_done"] = true
	assert_false(_has_section(_flags_journal(c, asked, 0), "Errands"))


func test_errand_with_unknown_npc_is_a_load_error() -> void:
	var d := GameData.load_from_dir()
	d.errands = [{"npc": "nobody", "asked_flag": "a", "done_flag": "b", "text": "x"}]
	d.load_errors.clear()
	d._validate()
	assert_true(", ".join(d.load_errors).contains("unknown npc 'nobody'"))


func _household(c: CharacterData, people: Dictionary = {}) -> Array[Dictionary]:
	return Guidance.journal(c, data(), {}, 0, "qingshi_village", 1.0, people, []).filter(func(e: Dictionary) -> bool: return e["section"] == "Household")


func test_household_is_empty_for_a_loner() -> void:
	assert_true(_household(_fresh()).is_empty())


func test_household_lists_untrained_children_only() -> void:
	var c := _fresh()
	var child := new_character(99)
	child.id = "gen_child"
	child.name = "Lin Bao"
	child.age_days = 12 * Calendar.DAYS_PER_YEAR
	c.children.append(child.id)
	child.parents = [c.id]
	var people := {child.id: child}
	assert_true(String(_household(c, people)[0]["text"]).contains("Lin Bao (age 12) can be trained"))
	child.training = {"assignment": "cultivate"}
	assert_true(_household(c, people).is_empty())
	child.training = {}
	child.age_days = 2 * Calendar.DAYS_PER_YEAR
	assert_true(_household(c, people).is_empty(), "too young")


func test_household_garden_beast_and_pregnancy_lines() -> void:
	var c := _fresh()
	c.garden = [{"item": "spirit_herb", "days_left": 0}, {"item": "spirit_herb", "days_left": 9}]
	assert_eq(_household(c)[0]["text"], "1 spirit garden plot ready to harvest.")
	c.garden = [{"item": "spirit_herb", "days_left": 9}]
	assert_true(_household(c).is_empty())
	c.companions = ["boar"] as Array[String]
	assert_true(_household(c).is_empty(), "no food, not outgrown")
	c.inventory = {"spirit_beast_pellet": 1}
	assert_eq(_household(c)[0]["text"], "Your Fields Boar can be fed.")
	c.inventory = {}
	c.realm_index = 6
	assert_true(String(_household(c)[0]["text"]).begins_with("You have outgrown your Fields Boar"))
	assert_eq(_household(c)[0]["tone"], "dim")
	c.pregnancy = {"partner": "", "days_left": 30}
	assert_true(_household(c).any(func(e: Dictionary) -> bool: return String(e["text"]).contains("with child")))


func test_events_in_other_regions_are_listed() -> void:
	if not data().world_events.has("sect_tournament"):
		return
	var events: Array = [{"id": "sect_tournament", "region": "azure_peak", "start_day": 0, "end_day": 20}]
	var c := _fresh()
	c.realm_index = 1
	var line := _find(_entries(c, 5, events), "Sect Tournament in Azure Peak")
	assert_eq(line["text"], "Sect Tournament in Azure Peak: you can enter, 15 days left")
	assert_eq(line["tone"], "normal")
	c.realm_index = 0
	line = _find(_entries(c, 5, events), "Sect Tournament in Azure Peak")
	assert_eq(line["tone"], "dim")
	assert_true(_find(_entries(c, 5, events, "azure_peak"), "Sect Tournament in").is_empty(), "current region keeps the old lines")


## QA-028: a busy sect disciple fills every section; no line leaks format junk or repeats.
func test_busy_disciple_journal_is_complete_clean_and_unrepeated() -> void:
	var d := data()
	var c := _fresh()
	c.realm_index = 0
	c.stage = 8
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0, "spent": 0, "month_earned": 0}
	var flags := {"sect_call_azure_cloud_sect": true, "sect_call_day_azure_cloud_sect": 5, "errand_mo_asked": true}
	c.commissions.append({"profession": "alchemist", "recipe": "qi_gathering_pill", "item": "qi_gathering_pill", "count": 3, "reward": 54, "xp": 30.0, "due_day": 40})
	var entries := Guidance.journal(c, d, flags, 10, "qingshi_village", 1.0, {}, [])
	var sections := _sections(entries)
	for name in ["Sect", "Commissions", "Errands", "Opportunities"]:
		assert_true(sections.has(name), "section %s present" % name)
	var seen := {}
	for e in entries:
		var text := String(e["text"])
		for bad in ["%", "{", "<null>"]:
			assert_false(text.contains(bad), "'%s' in: %s" % [bad, text])
		assert_false(seen.has(text), "repeated line: %s" % text)
		seen[text] = true
