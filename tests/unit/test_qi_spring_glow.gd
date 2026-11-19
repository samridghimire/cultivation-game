extends TestCase
## GFX-215: the qi shimmer where qi pools.

func test_count_rises_with_density_within_range() -> void:
	assert_eq(QiSpringGlow.mote_count(1.0), 0)
	assert_eq(QiSpringGlow.mote_count(0.5), 0)
	var last := 0
	for d in [1.1, 1.5, 2.0, 2.5, 4.0]:
		var n := QiSpringGlow.mote_count(d)
		assert_true(n >= 3 and n <= 8)
		assert_true(n >= last)
		last = n
	assert_true(QiSpringGlow.mote_count(2.5) > QiSpringGlow.mote_count(1.1))
	assert_eq(QiSpringGlow.mote_count(4.0), 8)


func test_plain_place_gets_no_motes() -> void:
	var g := QiSpringGlow.new()
	g.setup(Vector2(80, 60), 1.0, false)
	assert_eq(g.motes(), 0)
	g.free()


func test_reduce_motion_freezes_positions() -> void:
	var a := QiSpringGlow.mote_at(2, 6, 0.0, Vector2(80, 60), true)
	var b := QiSpringGlow.mote_at(2, 6, 7.3, Vector2(80, 60), true)
	assert_eq(a["pos"], b["pos"])
	assert_eq(QiSpringGlow.breath(0.0, true), QiSpringGlow.breath(2.0, true))
	var c := QiSpringGlow.mote_at(2, 6, 0.0, Vector2(80, 60), false)
	var d := QiSpringGlow.mote_at(2, 6, 1.5, Vector2(80, 60), false)
	assert_true(c["pos"] != d["pos"])


func test_motes_stay_near_the_footprint() -> void:
	for i in 8:
		for t in [0.0, 1.0, 3.3]:
			var m := QiSpringGlow.mote_at(i, 8, t, Vector2(80, 60), false)
			var p: Vector2 = m["pos"]
			assert_true(absf(p.x) <= 80.0 and p.y <= 30.0 and p.y >= -30.0 - QiSpringGlow.RISE)
