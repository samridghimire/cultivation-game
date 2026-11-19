extends TestCase
## GFX-212: footsteps.

func test_mark_kind() -> void:
	assert_eq(Footprints.mark_kind(true, false, false, false), "print")
	assert_eq(Footprints.mark_kind(true, true, true, true), "print")
	assert_eq(Footprints.mark_kind(false, true, true, false), "ripple")
	assert_eq(Footprints.mark_kind(false, true, false, true), "dust")
	assert_eq(Footprints.mark_kind(false, false, true, true), "dust")
	assert_eq(Footprints.mark_kind(false, false, false, false), "")


func test_on_road_and_puddle() -> void:
	var rects: Array[Rect2] = [Rect2(0, 100, 500, 40)]
	assert_true(Footprints.on_road(rects, Vector2(10, 120)))
	assert_false(Footprints.on_road(rects, Vector2(10, 20)))
	var ps: Array[Dictionary] = [{"pos": Vector2(50, 50), "rx": 10.0, "ry": 5.0}]
	assert_true(Footprints.in_puddle(ps, Vector2(55, 50)))
	assert_false(Footprints.in_puddle(ps, Vector2(50, 60)))


func test_cap_holds_and_marks_expire() -> void:
	var f := Footprints.new()
	var none: Array[Dictionary] = []
	f.setup({"map": {"paths": []}}, {}, true, false, none, false)
	for i in 200:
		f.track(Vector2(i * 20.0, 0))
	assert_eq(f.mark_count(), Footprints.CAP)
	f.advance(7.0)
	assert_eq(f.mark_count(), 0)
	f.free()


func test_reduce_motion_keeps_prints_and_skips_dust() -> void:
	var none: Array[Dictionary] = []
	var f := Footprints.new()
	f.setup({"map": {"paths": []}}, {}, true, false, none, true)
	for i in 5:
		f.track(Vector2(i * 20.0, 0))
	f.advance(10.0)
	assert_eq(f.mark_count(), 4)
	f.free()
	var g := Footprints.new()
	g.setup({"map": {"paths": [[0, 0, 1000, 100]]}}, {}, false, false, none, true)
	for i in 5:
		g.track(Vector2(i * 20.0, 0))
	assert_eq(g.mark_count(), 0)
	g.free()
