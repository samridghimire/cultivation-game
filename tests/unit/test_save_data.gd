extends TestCase


func test_character_round_trips_through_json() -> void:
	var c := new_character()
	c.realm_index = 2
	c.stage = 3
	c.qi = 1234.5
	c.alignment = -321
	c.sect = {"id": "blood_lotus_sect", "rank": 1, "contribution": 450}
	Professions.add_xp(c, data(), "alchemist", 250.0)
	c.add_item("qi_gathering_pill", 3)

	var json := JSON.stringify(c.to_dict())
	var restored := CharacterData.from_dict(JSON.parse_string(json))
	assert_eq(restored.to_dict(), c.to_dict())
	assert_eq(typeof(restored.realm_index), TYPE_INT)
	assert_eq(typeof(restored.inventory["qi_gathering_pill"]), TYPE_INT)


func test_calendar() -> void:
	assert_eq(Calendar.format_date(0), "Year 1, Month 1, Day 1")
	assert_eq(Calendar.format_date(Calendar.DAYS_PER_YEAR + Calendar.DAYS_PER_MONTH + 4), "Year 2, Month 2, Day 5")
	assert_eq(Calendar.format_duration(Calendar.DAYS_PER_YEAR + Calendar.DAYS_PER_MONTH), "1 year, 1 month")
	assert_eq(Calendar.format_duration(0), "0 days")
