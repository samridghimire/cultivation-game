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
	assert_false(layer.is_processing())
	layer.free()
