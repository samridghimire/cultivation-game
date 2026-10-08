extends TestCase


func test_describe_slot_includes_name_realm_date_and_age() -> void:
	var text := LoadScreen.describe_slot({"name": "Li Wei", "realm_label": "Qi Refining 3", "game_date": "Year 2, Spring 4", "age": 17, "alive": true})
	assert_true(text.contains("Li Wei"))
	assert_true(text.contains("Qi Refining 3"))
	assert_true(text.contains("Year 2, Spring 4"))
	assert_true(text.contains("age 17"))
	assert_false(text.contains("fallen at age"))


func test_describe_slot_marks_dead_characters() -> void:
	assert_true(LoadScreen.describe_slot({"name": "A", "alive": false}).contains("fallen at age"))
