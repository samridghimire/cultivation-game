extends TestCase
## WU-450: a great beast's prints on the ground (BeastTracks) on its tracks day and its own day.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _world(region: String, day: int) -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := _gs()
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = region
	GameClock.total_days = day
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	return world


func _day_of(weekday: int, from: int) -> int:
	var d := from
	while d % 7 != weekday:
		d += 1
	return d


func test_shape_by_beast() -> void:
	assert_eq(BeastTracks.shape_for("old_tusker_boar"), "hoof")
	assert_eq(BeastTracks.shape_for("thunder_horn_ram"), "hoof")
	assert_eq(BeastTracks.shape_for("cloud_crane"), "three_toed")
	assert_eq(BeastTracks.shape_for("bog_king_toad"), "webbed")
	assert_eq(BeastTracks.shape_for("mist_wolf"), "paw")


func test_trail_size_deterministic_and_clear() -> void:
	var blocked: Array[Rect2] = [Rect2(700, 400, 200, 200)]
	var clear: Array[Rect2] = [Rect2(300, 300, 150, 150)]
	var a := BeastTracks.trail("r", 9, Vector2(1600, 1000), Vector2(1200, 800), blocked, clear)
	var b := BeastTracks.trail("r", 9, Vector2(1600, 1000), Vector2(1200, 800), blocked, clear)
	assert_eq(a, b)
	assert_true(a.size() <= BeastTracks.COUNT_MAX)
	assert_true(a.size() >= 3, str(a.size()))
	for t: Dictionary in a:
		assert_false(blocked[0].has_point(t["pos"]))
		assert_false(clear[0].has_point(t["pos"]))
	# fades with distance: the print nearest the beast is the strongest
	assert_true(float(a[a.size() - 1]["alpha"]) > float(a[0]["alpha"]))


func test_beast_for_only_on_tracks_and_beast_days() -> void:
	var gs := _gs()
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var c: CharacterData = gs.player
	var beast_day := _day_of(3, 28)
	assert_eq(BeastTracks.beast_for(gs.data, c, "misty_forest", beast_day - 1), "old_tusker_boar")
	assert_eq(BeastTracks.beast_for(gs.data, c, "misty_forest", beast_day), "old_tusker_boar")
	assert_eq(BeastTracks.beast_for(gs.data, c, "misty_forest", beast_day - 3), "")
	assert_eq(BeastTracks.beast_for(gs.data, c, "qingshi_village", beast_day), "")
	c.great_beasts["old_tusker_boar"] = 1  # beaten: the return beast walks, so prints show for it
	assert_eq(BeastTracks.beast_for(gs.data, c, "misty_forest", beast_day), "scarred_old_tusker")
	c.great_beasts["scarred_old_tusker"] = 1
	assert_eq(BeastTracks.beast_for(gs.data, c, "misty_forest", beast_day), "")
	gs.end_session()


func test_world_draws_prints_only_on_tracks_day() -> void:
	var beast_day := _day_of(3, 28)
	var world := _world("misty_forest", beast_day - 1)
	assert_true(world._tracks.size() >= 4, str(world._tracks.size()))
	assert_eq(world._tracks_shape, "hoof")
	world.free()
	world = _world("misty_forest", beast_day - 3)
	assert_eq(world._tracks.size(), 0)
	world.free()
	world = _world("misty_forest", beast_day)
	assert_true(world._tracks.size() >= 4, str(world._tracks.size()))
	world.free()
	_gs().end_session()


func test_stride_trail() -> void:  # GFX-072
	for region in ["misty_forest", "withered_bone_marsh", "azure_peak", "r"]:
		for day in [5, 12, 40]:
			var t := BeastTracks.trail(region, day, Vector2(1600, 1000), Vector2(1100, 700), [], [])
			assert_true(t.size() >= BeastTracks.COUNT_MIN and t.size() <= BeastTracks.COUNT_MAX, "%s %d: %d" % [region, day, t.size()])
			for i in range(1, t.size()):
				var d: float = (t[i]["pos"] - t[i - 1]["pos"]).length()
				assert_true(d >= 26.0 and d <= 40.0, "stride %f" % d)
			assert_eq(t, BeastTracks.trail(region, day, Vector2(1600, 1000), Vector2(1100, 700), [], []))


func test_gap_keeps_stride_and_snow_colour() -> void:
	var blocked: Array[Rect2] = [Rect2(700, 400, 120, 120)]
	var t := BeastTracks.trail("r", 9, Vector2(1600, 1000), Vector2(1200, 800), blocked, [])
	assert_true(t.size() >= BeastTracks.FLOOR_COUNT)
	assert_true(BeastTracks.print_color(0.5, true) != BeastTracks.print_color(0.5, false))


func test_market_twinkle() -> void:
	var lo := 2.0
	var hi := 0.0
	for i in 120:
		var a: float = load("res://src/world/interactables/merchant.gd").twinkle_alpha(float(i) * 0.01, false)
		lo = minf(lo, a)
		hi = maxf(hi, a)
	assert_true(lo >= 0.399 and hi <= 1.001 and hi > 0.95 and lo < 0.45)
	assert_eq(load("res://src/world/interactables/merchant.gd").twinkle_alpha(0.3, true), 1.0)
