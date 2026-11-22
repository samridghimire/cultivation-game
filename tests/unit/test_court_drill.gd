extends TestCase
## GFX-241: disciples drilling on a sect court: pure positions, rain gating, data validation.


func test_positions_inside_court_clear_of_door_and_apart() -> void:
	var court := Rect2(300, 200, 260, 170)
	var door := 430.0
	var a := CourtDrill.positions(court, 6, door, 290.0)
	assert_eq(a.size(), 6)
	assert_eq(a, CourtDrill.positions(court, 6, door, 290.0))
	for i in a.size():
		assert_true(court.grow(-CourtDrill.EDGE + 0.5).has_point(a[i]) or absf(a[i].y - (court.end.y - CourtDrill.EDGE)) < 0.5, "inside court")
		assert_true(absf(a[i].x - door) >= CourtDrill.DOOR_CLEAR / 2.0, "door column free")
		for j in range(i + 1, a.size()):
			assert_true(a[i].distance_to(a[j]) >= CourtDrill.MIN_GAP, "apart")


func test_pose_loop_and_row_lag() -> void:
	assert_eq(CourtDrill.pose_at(0.0, 0), 0)
	assert_eq(CourtDrill.pose_at(1.3, 0), 1)
	assert_eq(CourtDrill.pose_at(1.3, 1), 0)
	assert_eq(CourtDrill.pose_at(1.4, 1), 1)
	assert_eq(CourtDrill.pose_at(3.7, 0), 0)


func test_no_drill_in_rain_storm_or_festival() -> void:
	assert_true(CourtDrill.drill_today("clear", false))
	assert_false(CourtDrill.drill_today("rain", false))
	assert_false(CourtDrill.drill_today("storm", false))
	assert_false(CourtDrill.drill_today("clear", true))


func test_data_has_drills_and_rejects_bad_count() -> void:
	var data := GameData.load_from_dir()
	assert_eq(data.sects["azure_cloud_sect"].court_drill["count"], 6)
	assert_false(data.sects["myriad_treasure_pavilion"].court_drill.is_empty())
	data.sects["azure_cloud_sect"].court_drill = {"count": 9, "form": "sword"}
	data.load_errors.clear()
	data._validate()
	var found := false
	for e in data.load_errors:
		found = found or String(e).contains("court_drill.count")
	assert_true(found)
