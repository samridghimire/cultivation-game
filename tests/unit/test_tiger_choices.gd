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
	assert_true(String(list[2]["reason"]).to_lower().contains("meat"), String(list[2]["reason"]))
	c.inventory["boar_meat"] = 2  # C-324: any meat fits
	list = Exploration.choices(c, d, enc, {})
	assert_false(list[2]["disabled"])


## C-324: the failed back-away is a real, light injury; the fevered child accepts any herbs.
func test_tiger_fail_injures_and_child_takes_any_herb() -> void:
	var d := GameData.load_from_dir()
	var fail: Dictionary = d.encounters["forest_crowned_tiger"]["choices"][1]["on_fail"]
	assert_eq(fail["effects"]["injury"], "torn_shoulder")
	assert_true(d.injuries.has("torn_shoulder"))
	var child: Dictionary = d.encounters["village_fevered_child"]["choices"][0]
	assert_eq(child["offer"]["tag"], "herb")
	assert_eq(int(child["offer"]["count"]), 2)
	var c := new_character()
	c.inventory["village_mugwort"] = 2
	var list := Exploration.choices(c, d, d.encounters["village_fevered_child"], {})
	assert_false(list[0]["disabled"])
