extends TestCase
## C-320: the Mist-Crowned Tiger can be fought, stepped around, or bought off with meat.


func test_tiger_has_three_ways_out() -> void:
	var d := GameData.load_from_dir()
	var enc: Dictionary = d.encounters["forest_crowned_tiger"]
	assert_false(enc.has("enemy"))
	var c := new_character()
	c.inventory.erase("venison")
	var list := Exploration.choices(c, d, enc, {})
	assert_eq(list.size(), 3)
	assert_false(list[0]["disabled"], "fighting is always possible")
	assert_true(list[0]["fight"])
	assert_true(list[1]["roll"], "backing away is a spirit check")
	assert_false(list[1]["disabled"])
	assert_true(list[2]["disabled"], "no meat, no offering")
	assert_true(String(list[2]["reason"]).contains("Venison"))
	c.inventory["venison"] = 2
	list = Exploration.choices(c, d, enc, {})
	assert_false(list[2]["disabled"])
