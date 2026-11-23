extends TestCase
## GFX-241: disciples drilling on a sect court: pure positions, rain gating, data validation.


func test_positions_inside_court_clear_of_door_and_apart() -> void:
	var court := Rect2(300, 200, 260, 170)
	var hall := Rect2(350, 210, 160, 50)
	var door := hall.get_center().x
	var a := CourtDrill.positions(court, 6, hall)
	assert_eq(a.size(), 6)
	assert_eq(a, CourtDrill.positions(court, 6, hall))
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


## GFX-243: Azure's shallow south band (hall 160x110 at 980,730, court from SectCourt) puts figures beside the hall too.
func test_shallow_court_gets_flank_columns() -> void:
	var hall := Rect2(900, 675, 160, 110)
	var court := Rect2(860, 650, 240, 190)
	var a := CourtDrill.positions(court, 6, hall)
	assert_eq(a.size(), 6)
	var ys := {}
	for p in a:
		ys[snappedf(p.y, 0.5)] = true
		assert_true(absf(p.x - hall.get_center().x) >= CourtDrill.DOOR_CLEAR / 2.0 or p.y >= hall.end.y, "door column free")
	assert_gt(ys.size(), 1, "not one row")
	assert_eq(a, CourtDrill.positions(court, 6, hall), "deterministic")


func test_small_court_and_blockers() -> void:
	var hall := Rect2(370, 175, 160, 110)
	var court := Rect2(340, 150, 220, 170)
	var blockers: Array[Vector2] = [Vector2(450, 300)]
	var a := CourtDrill.positions(court, 4, hall, blockers)
	assert_gt(a.size(), 1)
	for p in a:
		assert_true(p.distance_to(blockers[0]) >= 24.0)
