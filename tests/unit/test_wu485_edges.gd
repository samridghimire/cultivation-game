extends TestCase
const _W := preload("res://src/world/world.gd")
## WU-485: painted map margins, the Qi bar end cap.


func test_margin_rects_cover_outside_the_map() -> void:
	var size := Vector2(1600, 1200)
	var rects: Array[Rect2] = _W.margin_rects(size)
	assert_eq(rects.size(), 4)
	for p: Vector2 in [Vector2(800, -30), Vector2(800, size.y + 50), Vector2(-10, 600), Vector2(size.x + 10, 600), Vector2(-10, -30), Vector2(size.x + 10, size.y + 50)]:
		var hit := false
		for r in rects:
			hit = hit or r.has_point(p)
		assert_true(hit, "%s is painted" % p)
	for r in rects:
		assert_false(r.intersects(Rect2(Vector2.ZERO, size)), "no overlap with the map")


func test_end_cap_x() -> void:
	assert_eq(UIStyle.end_cap_x(300.0, 0.0, 100.0), -1.0)
	assert_eq(UIStyle.end_cap_x(300.0, 1.0, 100.0), 2.0)
	assert_eq(UIStyle.end_cap_x(300.0, 100.0, 100.0), 299.0)
