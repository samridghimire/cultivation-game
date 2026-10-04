extends TestCase
## Guidance: next-step hints built from player state.


func _fresh() -> CharacterData:
	var c := new_character()
	c.realm_index = 0
	c.stage = 0
	c.qi = 0.0
	c.inventory = {}
	return c


func _has(hints: PackedStringArray, fragment: String) -> bool:
	for h in hints:
		if h.contains(fragment):
			return true
	return false


func test_new_character_gets_qi_and_starter_hints() -> void:
	var c := _fresh()
	c.professions = {}
	c.techniques = {}
	var hints := Guidance.hints(c, data(), 1.0, 10)
	assert_true(_has(hints, "more qi to reach the next stage"))
	assert_true(_has(hints, "learn a profession"))
	assert_true(_has(hints, "Learn a technique"))


func test_limit_caps_hint_count() -> void:
	var c := _fresh()
	c.professions = {}
	c.techniques = {}
	assert_eq(Guidance.hints(c, data(), 1.0, 2).size(), 2)


func test_bottleneck_shows_breakthrough_odds_and_held_pills() -> void:
	var c := _fresh()
	var realm: RealmDef = data().realms[0]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	var hints := Guidance.hints(c, data(), 1.0, 10)
	var pct := roundi(Cultivation.breakthrough_chance(c, data()) * 100)
	assert_true(_has(hints, "(%d%% chance)" % pct))
	assert_true(_has(hints, "Breakthrough pills raise the odds"))
	var pill := ""
	for item: Dictionary in data().items.values():
		if float(item.get("effects", {}).get("breakthrough_bonus", 0.0)) > 0.0:
			pill = item["id"]
			break
	c.add_item(pill, 1)
	assert_eq(Guidance.breakthrough_items(c, data()), PackedStringArray([data().items[pill]["name"]]))
	assert_true(_has(Guidance.hints(c, data(), 1.0, 10), "Using %s first" % data().items[pill]["name"]))


func test_urgent_hints_come_first() -> void:
	var c := _fresh()
	c.age_days = (Cultivation.lifespan_years(c, data()) - 3) * Calendar.DAYS_PER_YEAR
	Injuries.inflict(c, data(), "qi_deviation")
	var hints := Guidance.hints(c, data())
	assert_true(hints[0].begins_with("Only 3 years of life remain"))
	assert_true(hints[1].begins_with("Treat your injuries"))


func test_pregnancy_and_low_artifact_lives() -> void:
	var c := _fresh()
	c.pregnancy = {"partner": "x", "days_left": 30}
	c.artifact_lives = 1
	var hints := Guidance.hints(c, data(), 1.0, 10)
	assert_true(_has(hints, "A child is due in %s." % Calendar.format_duration(30)))
	assert_true(_has(hints, "holds 1 life"))


func test_sect_hints_for_rogue_and_member() -> void:
	var c := _fresh()
	c.alignment = -500
	var rogue := Guidance.hints(c, data(), 1.0, 10)
	var open_sects: PackedStringArray = []
	for sect: SectDef in data().sects.values():
		if Sects.check_join(c, data(), sect.id)["ok"]:
			open_sects.append(sect.name)
	assert_eq(_has(rogue, "As a rogue cultivator"), not open_sects.is_empty())
	var sect: SectDef = data().sects.values()[0]
	c.alignment = 0
	c.sect = {"id": sect.id, "rank": 0, "contribution": 100, "spent": 0}
	var need := int(sect.ranks[1]["contribution"]) - 100
	assert_true(_has(Guidance.hints(c, data(), 1.0, 10), "Earn %d more sect contribution" % need))
