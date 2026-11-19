extends TestCase
## GFX-214: grass puffs and falling leaves.

func _fx(season: String, reduce: bool, enabled: bool = true, paths: Array = [], style: String = "grass", ambient: Dictionary = {}) -> FoliageFx:
	var f := FoliageFx.new()
	var decor: Array[Dictionary] = []
	for i in 12:
		decor.append({"kind": "tree", "pos": Vector2(100 + i * 30, 200), "scale": 1.0, "color": Color.GREEN})
	f.setup({"map": {"paths": paths, "ground_style": style, "ambient": ambient, "decor": {"flowers": 4}}}, {}, decor, season, false, enabled, reduce)
	return f


func test_pool_never_exceeds_cap() -> void:
	var f := _fx("Autumn", false)
	f.set_view(Rect2(0, 0, 1280, 800))
	for i in 2000:
		f.track(Vector2(i * 10.0, 100))
		f.advance(0.05)
		assert_true(f.live_count() <= FoliageFx.CAP)
		assert_true(f.leaf_count() <= FoliageFx.MAX_LEAVES)


func test_no_puff_on_road() -> void:
	var f := _fx("Summer", false, true, [[0, 80, 2000, 60]])
	for i in 50:
		f.track(Vector2(i * 30.0, 100))
	assert_eq(f.live_count(), 0)
	var g := _fx("Summer", false)
	for i in 5:
		g.track(Vector2(i * 30.0, 100))
	assert_true(g.live_count() > 0)


func test_no_leaves_in_summer_and_leaves_in_autumn() -> void:
	var s := _fx("Summer", false)
	s.set_view(Rect2(0, 0, 1280, 800))
	for i in 400:
		s.advance(0.1)
	assert_eq(s.leaf_count(), 0)
	var a := _fx("Autumn", false)
	a.set_view(Rect2(0, 0, 1280, 800))
	for i in 100:
		a.advance(0.1)
	assert_true(a.leaf_count() > 0)
	var amb := _fx("Summer", false, true, [], "grass", {"any": "leaves"})
	assert_true(amb.leaves_enabled())


func test_off_and_scree_do_nothing() -> void:
	var off := _fx("Autumn", false, false)
	off.set_view(Rect2(0, 0, 1280, 800))
	for i in 100:
		off.track(Vector2(i * 30.0, 100))
		off.advance(0.1)
	assert_eq(off.live_count(), 0)
	assert_false(FoliageFx.grass_ground("scree", false))
	assert_false(FoliageFx.grass_ground("grass", true))


func test_reduce_motion_leaves_lie_still_no_puffs() -> void:
	var f := _fx("Autumn", true)
	f.set_view(Rect2(0, 0, 1280, 800))
	for i in 20:
		f.track(Vector2(i * 30.0, 100))
	for i in 60:
		f.advance(0.1)
	var before: Array = []
	for s in f._pool:
		before.append(s.duplicate())
	f.advance(0.1)
	f.advance(0.1)
	for i in f._pool.size():
		if bool(before[i]["on"]) and before[i]["kind"] == "leaf":
			assert_eq(f._pool[i]["pos"], before[i]["pos"])
			assert_eq(f._pool[i]["age"], before[i]["age"])
	for s in f._pool:
		if bool(s["on"]):
			assert_eq(s["kind"], "leaf")
