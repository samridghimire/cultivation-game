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


## SEASON-020: the elder's next asks, previewed in the last week of a season.
func test_preview_line_window_and_content() -> void:
	var gd := _gd()
	var c := new_character()
	assert_eq(SeasonTasks.preview_line(c, gd, 10), "", "mid-season")
	# spring year 1, day 85 is within 7 days of the end; summer year 1 asks for the year-1 set
	var day := 90 - 3
	assert_eq(Calendar.season_of(day), "Spring")
	var line := SeasonTasks.preview_line(c, gd, day)
	assert_true(line.begins_with("Next season the elder asks:"), line)
	assert_true(line.contains("a Lotus Bass"), line)
	assert_true(line.contains("2 Qi Condensing Grass"), line)
	assert_true(line.contains("the Dragon Boat Festival"), line)
	assert_eq(SeasonTasks.preview_line(c, gd, 90 - 9), "", "just outside the window")


func test_preview_winter_uses_next_years_spring_set() -> void:
	var gd := _gd()
	var c := new_character()
	var day := 360 - 2
	assert_eq(Calendar.season_of(day), "Winter")
	var line := SeasonTasks.preview_line(c, gd, day)
	assert_true(line.contains("Fog-Antler Stag") or line.contains("Silver Carp"), line)
	assert_false(line.contains("Peach-Blossom Bream"), "year 2 never asks the year-1 set: " + line)


func test_preview_in_today_lines() -> void:
	var gd := _gd()
	var c := new_character()
	var lines := Guidance.today_lines(c, gd, {}, [], 87, "qingshi_village")
	var found := false
	for l in lines:
		if String(l).begins_with("Next season the elder asks"):
			found = true
	assert_true(found, str(lines))
	var far := Guidance.today_lines(c, gd, {}, [], 87, "misty_forest")
	for l in far:
		assert_false(String(l).begins_with("Next season the elder asks"), "not nagged far away")


func test_preview_counts_hunts() -> void:  # REVIEW: a hunt of 2 is not "a Wild Boar"
	var gd := _gd()
	var c := new_character()
	var saved: Dictionary = gd.season_tasks.duplicate(true)
	var set0: Array = SeasonTasks.tasks_for(gd, 90 + 5)
	set0[0] = {"id": "review_hunt", "first_year": true, "text": "Hunt two boars.", "kind": "hunt", "target": "wild_boar", "count": 2}
	var line := SeasonTasks.preview_line(c, gd, 90 - 3)
	gd.season_tasks = saved
	assert_true(line.contains("2 Wild Boars"), line)
	assert_false(line.contains("a Wild Boar"), line)
