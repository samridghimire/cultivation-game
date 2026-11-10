extends TestCase
## GFX-086: ambient village critters (hens, ducks, butterflies).


func _region() -> Dictionary:
	return {"id": "t", "map": {"size": [800, 600], "landmarks": [{"kind": "pond", "pos": [400, 200], "size": [150, 100]}],
		"ambient_critters": [{"kind": "hen", "pos": [100, 400]}, {"kind": "duck", "pos": [400, 200]}, {"kind": "butterfly", "pos": [200, 450]}]}}


func test_validation() -> void:
	assert_eq(Critters.validate(_region()).size(), 0)
	var bad := _region()
	bad["map"]["ambient_critters"] = [{"kind": "dragon", "pos": [1, 1]}, {"kind": "hen", "pos": [900, 10]}, {"kind": "duck", "pos": [50, 50]}, {"kind": "hen"}]
	assert_eq(Critters.validate(bad).size(), 4)


func test_real_data_is_valid() -> void:
	var data := data()
	for e in data.load_errors:
		assert_true(not String(e).contains("ambient_critters"), e)
	var qingshi: Dictionary = data.regions["qingshi_village"]
	assert_true(not (qingshi["map"]["ambient_critters"] as Array).is_empty())


func test_kinds_by_season() -> void:
	var kinds := func(season: String) -> Array:
		return Critters.today(_region(), season, 5, true).map(func(c: Dictionary) -> String: return c["kind"])
	assert_eq(kinds.call("Spring"), ["hen", "duck", "butterfly"])
	assert_eq(kinds.call("Autumn"), ["hen", "duck"])
	assert_eq(kinds.call("Winter"), ["hen"])


func test_none_when_setting_off() -> void:
	assert_eq(Critters.today(_region(), "Spring", 5, false).size(), 0)


func test_deterministic_and_ducks_stay_on_water() -> void:
	assert_eq(Critters.today(_region(), "Summer", 9, true), Critters.today(_region(), "Summer", 9, true))
	var duck: Dictionary = Critters.today(_region(), "Summer", 9, true)[1]
	for i in 40:
		var p := Critters.position_at(duck, i * 0.9, false)
		assert_true(Critters.pond_at(_region(), p).size != Vector2.ZERO, "duck at %s is on the pond" % p)
	assert_eq(Critters.position_at(duck, 7.0, true), duck["pos"])


func test_layer_hidden_without_critters_and_still_when_reduced() -> void:
	var layer := CritterLayer.new()
	layer.setup(_region(), "Winter", 1, false, false)
	assert_false(layer.visible)
	layer.setup(_region(), "Spring", 1, true, true)
	assert_true(layer.visible)
	assert_true(layer.is_processing(), "processes so critters can startle, even when still")
	layer.free()


func test_flee_offset_math() -> void:
	var beyond := Critters.flee_offset(Vector2(100, 0), Vector2.ZERO, 48.0, 60.0)
	assert_eq(beyond, Vector2.ZERO)
	var near := Critters.flee_offset(Vector2(20, 0), Vector2.ZERO, 48.0, 60.0)
	assert_true(near.x > 0.0 and absf(near.y) < 0.001, "points away")
	var nearer := Critters.flee_offset(Vector2(5, 0), Vector2.ZERO, 48.0, 60.0)
	assert_true(nearer.length() > near.length(), "grows toward contact")
	assert_almost_eq(Critters.flee_offset(Vector2.ZERO, Vector2.ZERO, 48.0, 60.0).length(), 60.0)


func test_fleeing_duck_stays_in_pond() -> void:
	var pond := Critters.pond_at(_region(), Vector2(400, 200))
	var p := Critters.clamp_to_pond(Vector2(9999, -50), pond)
	assert_true(pond.grow(0.01).has_point(p))
	var duck: Dictionary = Critters.today(_region(), "Summer", 9, true)[1]
	var layer := CritterLayer.new()
	layer.setup(_region(), "Summer", 9, true, false)
	layer.player_pos = duck["pos"] + Vector2(-10, 0)
	for i in 30:
		layer._process(0.05)
	assert_true(pond.grow(0.01).has_point(layer.critter_pos(1)), "duck stays on the water")
	layer.free()


func test_hen_runs_from_player() -> void:
	var layer := CritterLayer.new()
	layer.setup(_region(), "Spring", 1, true, false)
	var start: Vector2 = layer.critter_pos(0)
	layer.player_pos = start + Vector2(-12, 0)
	for i in 10:
		layer._process(0.05)
	assert_true(layer.critter_pos(0).x > start.x + 8.0, "hen moved away after 0.5 s")
	layer.free()


func test_coop_cluster_inside_front_rect() -> void:
	var coop := Rect2(60, 455, 80, 50)
	var front := Critters.coop_front_rect(coop)
	assert_true(front.position.y >= coop.end.y, "front is below the coop")
	for n in [1, 3, 5]:
		for i in n:
			assert_true(front.has_point(Critters.cluster_pos(front, i, n)), "slot %d of %d inside" % [i, n])


func test_fed_hens_gather_at_coop() -> void:
	var region := _region()
	region["places"] = [{"type": "coop", "pos": [100, 480], "size": [80, 50]}]
	var front := Critters.coop_front_rect(Critters.coop_rect(region))
	var fed := Critters.today(region, "spring", 3, true, true)
	assert_true(front.grow(4.0).has_point(fed[0]["pos"]), "fed hen clusters at the coop")
	var plain := Critters.today(region, "spring", 3, true, false)
	assert_eq(plain[0]["pos"], Vector2(100, 400))


func test_coop_pixel_art_exists() -> void:
	assert_true(PixelPlace.supports("coop"))
	var rows := PixelPlace.rows("coop")
	assert_true(rows.size() > 0)
	for r in rows:
		assert_eq(r.length(), rows[0].length())
