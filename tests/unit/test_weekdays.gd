extends TestCase
## CAL-005: named weekdays.


func test_weekday_names() -> void:
	assert_eq(Calendar.weekday_name(0), "Sunday")
	assert_eq(Calendar.weekday_name(6), "Earthday")
	assert_eq(Calendar.weekday_name(7), "Sunday")
	assert_eq(Calendar.weekday_of(365), 1)
	assert_eq(Calendar.weekday_name(365), "Moonday")
	assert_eq(Calendar.weekday_label(2), "Fireday")


func test_days_until_weekday_wraps() -> void:
	assert_eq(Calendar.days_until_weekday(9, 2), 0)
	assert_eq(Calendar.days_until_weekday(9, 3), 1)
	assert_eq(Calendar.days_until_weekday(9, 1), 6)


func test_weekday_matches_great_day() -> void:
	var def := {"weekday": 4}
	var gd := Wildlife.great_day("misty_forest", def)
	assert_eq(Calendar.weekday_of(7 * 30 + gd), gd)
