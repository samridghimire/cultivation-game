extends TestCase
## SEASON-019: year 1 uses the first_year set, later years cycle the others.


func _gd() -> GameData:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data


func _day_in_year(year: int, season_idx: int) -> int:
	var d := 5 + 90 * season_idx
	while Calendar.year_of(d) < year:
		d += 30
	return d


func test_year_one_uses_first_year_set() -> void:
	var gd := _gd()
	for i in 4:
		var day := _day_in_year(1, i)
		var tasks := SeasonTasks.tasks_for(gd, day)
		assert_true(SeasonTasks._is_first_year(tasks), "year 1 %d" % i)


func test_later_years_cycle_other_sets() -> void:
	var gd := _gd()
	for i in 4:
		var seen := {}
		for y in range(2, 8):
			var tasks := SeasonTasks.tasks_for(gd, _day_in_year(y, i))
			assert_false(SeasonTasks._is_first_year(tasks), "year %d never first set" % y)
			seen[String(tasks[0]["id"])] = true
		assert_eq(seen.size(), 2, "two other sets cycle (season %d)" % i)
	var a := String(SeasonTasks.tasks_for(gd, _day_in_year(2, 0))[0]["id"])
	var b := String(SeasonTasks.tasks_for(gd, _day_in_year(3, 0))[0]["id"])
	var c := String(SeasonTasks.tasks_for(gd, _day_in_year(4, 0))[0]["id"])
	assert_true(a != b)
	assert_eq(a, c)


func test_first_year_must_be_bool() -> void:
	var gd := _gd()
	var saved: Dictionary = gd.season_tasks.duplicate(true)
	gd.season_tasks["seasons"]["spring"]["sets"][0][0]["first_year"] = "yes"
	assert_true(SeasonTasks.validate(gd).size() > 0)
	gd.season_tasks = saved
	assert_eq(SeasonTasks.validate(gd).size(), 0)
