extends TestCase
## WU-641: the lecture scene stages only for a member whose home-hall region is here and whose lecture is open.

const HUD := preload("res://src/ui/hud.gd")


func _member() -> Array:
	var data := GameData.load_from_dir()
	var c := CharacterData.new()
	c.sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	return [c, data, Sects.home_region(data, "azure_cloud_sect")]


func test_staged_when_open_in_home_region() -> void:
	var m := _member()
	assert_true(LectureHallScene.staged(m[0], m[1], m[2], 40))
	assert_false(LectureHallScene.staged(m[0], m[1], "no_such_region", 40))
	assert_false(LectureHallScene.staged(null, m[1], m[2], 40))


func test_not_staged_after_attending_or_as_rogue() -> void:
	var m := _member()
	var c: CharacterData = m[0]
	c.sect["lecture_month"] = Sects._month_index(40)
	assert_false(LectureHallScene.staged(c, m[1], m[2], 40))
	assert_true(LectureHallScene.staged(c, m[1], m[2], 40 + 12 * Calendar.DAYS_PER_MONTH))
	assert_false(LectureHallScene.staged(CharacterData.new(), m[1], m[2], 40))


func test_layout_in_front_of_hall_clear_of_blockers() -> void:
	var hall := Rect2(360, 210, 180, 50)
	var map := Vector2(1000, 800)
	var blocker := Vector2(406, 330)
	var lay := LectureHallScene.layout(hall, map, [blocker])
	var mat: Rect2 = lay["mat"]
	assert_false(mat.intersects(hall))
	assert_true(mat.position.y >= hall.end.y)
	assert_true(Rect2(Vector2.ZERO, map).encloses(mat))
	assert_true((lay["seats"] as Array).size() >= 3)
	for s: Vector2 in lay["seats"]:
		assert_true(s.distance_to(blocker) >= LectureHallScene.BLOCKER_CLEAR)
		assert_false(mat.has_point(s))
	assert_eq(lay["seats"], LectureHallScene.layout(hall, map, [blocker])["seats"])


func test_arrival_subtitle_mentions_lecture_only_when_open() -> void:
	var m := _member()
	assert_true(HUD.arrival_subtitle(m[0], m[1], m[2], 1.0, "Calm", false, 40).contains("Lecture today"))
	assert_false(HUD.arrival_subtitle(m[0], m[1], m[2], 1.0, "Calm", false).contains("Lecture today"))
	assert_false(HUD.arrival_subtitle(m[0], m[1], "no_such_region", 1.0, "Calm", false, 40).contains("Lecture today"))


func test_mate_sits_in_front_row_with_name() -> void:  # WU-647
	var m := _member()
	var sect: SectDef = (m[1] as GameData).sects["azure_cloud_sect"]
	var scene := LectureHallScene.new()
	var hall := Rect2(360, 210, 180, 50)
	scene.setup(true, sect, hall, [], Vector2(1000, 800), false)
	assert_eq(scene.mate_name(), "", "no mate, no label")
	scene.setup(true, sect, hall, [], Vector2(1000, 800), false, "xiao_ling", "Xiao Ling")
	assert_eq(scene.mate_name(), "Xiao Ling")
	assert_true(scene.mate_seat_pos().y > scene.mat_rect().end.y, "south of the mat")
	scene.setup(false, null, Rect2(), [], Vector2(1000, 800), false, "xiao_ling", "Xiao Ling")
	assert_eq(scene.mate_name(), "", "hidden scene keeps no mate")
	scene.free()
