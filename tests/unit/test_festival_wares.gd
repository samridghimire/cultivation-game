extends TestCase
## GUIDE-221: Today and the calendar say what a festival stall sells, and announce it on the eve.


func _first_of_month(month: int) -> int:
	var d := 400
	while Calendar.month_of(d) != month or Calendar.day_of(d) != 1:
		d += 1
	return d


func _gd() -> GameData:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	return gs.data


func _lines(data: GameData, events: Array, day: int, region: String = "qingshi_village") -> PackedStringArray:
	var c := CharacterFactory.create("Lin Feng", data, seeded_rng(), "male")
	return Guidance.today_lines(c, data, {}, events, day, region)


func test_festival_day_lists_two_real_wares() -> void:
	var data := _gd()
	var day := _first_of_month(5)
	var events: Array = [{"id": "dragon_boat_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 5, "done": false}]
	var place: Dictionary = {}
	for p: Dictionary in data.regions["qingshi_village"]["places"]:
		if p.get("festival_only", "") == "dragon_boat_festival":
			place = p
	var wares := Places.festival_wares(data, events, place, "qingshi_village", 2)
	assert_eq(wares.size(), 2)
	var found := ""
	for l in _lines(data, events, day):
		if " sells " in l:
			found = l
	assert_true(found != "", "a wares line")
	assert_true(found.begins_with("Dragon Boat Dumpling Stall sells %s, %s and more" % [wares[0], wares[1]]))
	assert_true(found.length() <= 160)
	var names: Array = data.items.values().map(func(i: Dictionary) -> String: return String(i.get("name", "")))
	for w in wares:
		assert_true(names.has(w))


func test_eve_line_only_the_day_before() -> void:
	var data := _gd()
	var day := _first_of_month(5)
	var eve := ""
	for l in _lines(data, [], day - 1):
		if l.begins_with("Tomorrow:"):
			eve = l
	assert_true("Dragon Boat" in eve and "Dumpling Stall opens" in eve, eve)
	for l in _lines(data, [], day - 2):
		assert_false(l.begins_with("Tomorrow:"))
	for l in _lines(data, [], day - 1, "misty_forest"):
		assert_false(l.begins_with("Tomorrow:"))


func test_no_wares_line_without_a_stall() -> void:
	var data := _gd()
	var day := _first_of_month(5)
	var events: Array = [{"id": "dragon_boat_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 5, "done": false}]
	assert_eq(Places.festival_wares_line(data, events, "misty_forest", day), "")
	assert_eq(Places.festival_eve_line(data, [], "misty_forest", day - 1), "")


func test_calendar_entry_lists_up_to_four_wares() -> void:
	var data := _gd()
	var day := _first_of_month(5)
	var events: Array = [{"id": "dragon_boat_festival", "region": "qingshi_village", "start_day": day, "end_day": day + 5, "done": false}]
	var wares := Places.open_stall_wares(data, events, "qingshi_village", day, 4)
	assert_true(wares.size() >= 1 and wares.size() <= 4)
	assert_eq(Places.open_stall_wares(data, [], "qingshi_village", day, 4).size(), 0)
