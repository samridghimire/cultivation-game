extends TestCase
## Calendar.format_rough (GUIDE-038): long waits read in months or years.


func test_format_rough() -> void:
	assert_eq(Calendar.format_rough(1), "1 day")
	assert_eq(Calendar.format_rough(45), "45 days")
	assert_eq(Calendar.format_rough(60), "2 months")
	assert_eq(Calendar.format_rough(719), "24 months")
	assert_eq(Calendar.format_rough(720), "2 years")
	assert_eq(Calendar.format_rough(8709), "24 years")
