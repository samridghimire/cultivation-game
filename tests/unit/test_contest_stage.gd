extends TestCase
## GFX-253: the contest stage shows only in the sect's contest month and lays out clear of the door and blockers.


func test_shown_only_in_contest_month() -> void:
	var data := GameData.load_from_dir()
	var azure: Dictionary = data.sects["azure_cloud_sect"].contest
	assert_eq(int(azure["month"]), 3)
	assert_true(ContestStage.shown(azure, 2 * Calendar.DAYS_PER_MONTH))
	assert_false(ContestStage.shown(azure, 1 * Calendar.DAYS_PER_MONTH))
	assert_false(ContestStage.shown(azure, 3 * Calendar.DAYS_PER_MONTH))
	assert_false(ContestStage.shown({}, 2 * Calendar.DAYS_PER_MONTH))


func test_layout_clear_of_hall_blockers_and_platform() -> void:
	var court := Rect2(300, 200, 300, 200)
	var hall := Rect2(360, 210, 180, 50)
	var map := Vector2(1000, 800)
	var blocker := Vector2(470, 470)
	var lay := ContestStage.layout(court, hall, 10, [blocker], map)
	var platform: Rect2 = lay["platform"]
	var spots: Array = lay["spots"]
	assert_true(Rect2(Vector2.ZERO, map).encloses(platform), "platform on the map")
	assert_false(platform.intersects(hall), "not over the hall")
	assert_true(spots.size() >= ContestStage.MIN_FIGURES, "enough disciples")
	assert_true(spots.size() <= ContestStage.MAX_FIGURES)
	for i in spots.size():
		assert_false(platform.has_point(spots[i]))
		assert_false(hall.has_point(spots[i]))
		assert_true((spots[i] as Vector2).distance_to(blocker) >= ContestStage.BLOCKER_CLEAR)
	assert_eq(lay["spots"], ContestStage.layout(court, hall, 10, [blocker], map)["spots"])


func test_layout_falls_back_into_court_on_a_short_map() -> void:
	var court := Rect2(300, 200, 300, 200)
	var hall := Rect2(360, 210, 180, 50)
	var lay := ContestStage.layout(court, hall, 8, [], Vector2(1000, 420))
	assert_true(court.encloses(lay["platform"]), "platform inside court")


func test_shallow_court_never_puts_stage_south_of_it() -> void:
	var court := Rect2(300, 200, 300, 70)  # shallow: no room under the hall
	var hall := Rect2(360, 210, 180, 50)
	var map := Vector2(1000, 800)
	var label := Rect2(250, 185, 90, 24)
	var lay := ContestStage.layout(court, hall, 8, [], map, [label])
	var platform: Rect2 = lay["platform"]
	assert_true(platform.end.y <= court.end.y + 0.1 or platform.position.y < court.end.y, "not south of the court")
	assert_false(platform.intersects(hall.grow(14.0)), "clear of the hall")
	assert_false(platform.intersects(label), "clear of the label")
	for s: Vector2 in lay["spots"]:
		assert_false(hall.grow(10.0).has_point(s), "disciples off the hall wall")


func test_month_change_toggles_stage() -> void:
	var data := GameData.load_from_dir()
	var stage := ContestStage.new()
	var court := Rect2(300, 200, 300, 200)
	var hall := Rect2(360, 210, 180, 50)
	var def: SectDef = data.sects["azure_cloud_sect"]
	var none: Array[Vector2] = []
	stage.setup(def, court, hall, none, Vector2(1000, 800), 1 * Calendar.DAYS_PER_MONTH, false, false)
	assert_false(stage.visible)
	stage.setup(def, court, hall, none, Vector2(1000, 800), 2 * Calendar.DAYS_PER_MONTH, false, false)
	assert_true(stage.visible)
	stage.free()
