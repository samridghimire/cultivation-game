extends TestCase
## GFX-007: generated pixel-style ground and path tiles.

const BASE := Color("4d6b3c")


func _bytes(t: ImageTexture) -> PackedByteArray:
	return t.get_image().get_data()


func test_tile_size_and_determinism() -> void:
	var a := GroundTiles.make_tile(BASE, "qingshi_village", "ground")
	var b := GroundTiles.make_tile(BASE, "qingshi_village", "ground")
	assert_eq(a.get_width(), 16)
	assert_eq(a.get_height(), 16)
	assert_true(_bytes(a) == _bytes(b))


func test_seed_changes_tile_and_base_share() -> void:
	var a := GroundTiles.make_tile(BASE, "qingshi_village", "ground")
	var b := GroundTiles.make_tile(BASE, "misty_forest", "ground")
	assert_true(_bytes(a) != _bytes(b))
	for kind in ["ground", "path"]:
		var img := GroundTiles.make_tile(BASE, "qingshi_village", kind).get_image()
		var same := 0
		for y in 16:
			for x in 16:
				if img.get_pixel(x, y).is_equal_approx(BASE):
					same += 1
		var share := float(same) / 256.0
		assert_true(share >= 0.6 and share <= 0.9, "%s share %f" % [kind, share])


func test_cached_same_object() -> void:
	assert_true(GroundTiles.cached(BASE, "x", "path") == GroundTiles.cached(BASE, "x", "path"))
	assert_true(GroundTiles.cached(BASE, "x", "path") != GroundTiles.cached(BASE, "x", "ground"))


func test_blades_do_not_cross_the_edge() -> void:
	# A blade is two vertical pixels; a lone blade colour in the last row would mean it continues off-tile.
	var light := BASE.lightened(0.18)
	for s in ["a", "b", "c", "d", "e", "f"]:
		var img := GroundTiles.make_tile(BASE, s, "ground").get_image()
		for x in 16:
			if img.get_pixel(x, 15).is_equal_approx(light):
				assert_true(img.get_pixel(x, 14).is_equal_approx(light), "blade at edge " + s)


func test_edge_color_darker() -> void:
	assert_true(GroundTiles.edge_color(BASE).get_luminance() < BASE.get_luminance())


func test_variant_choice_deterministic_and_mostly_plain() -> void:
	var plain := 0
	var seen := {}
	for cy in 25:
		for cx in 40:
			var v := GroundTiles.variant_for("qingshi_village", cx, cy)
			assert_eq(v, GroundTiles.variant_for("qingshi_village", cx, cy))
			seen[v] = true
			if v == 0:
				plain += 1
	assert_true(plain >= 600 and plain <= 800, "about 70%% plain, got %d of 1000" % plain)
	assert_eq(seen.size(), 4)


func test_ground_texture_size_cached_and_flowers_by_season() -> void:
	var a := GroundTiles.ground_texture(BASE, "t_region", Vector2i(100, 70), true)
	assert_eq(a.get_size(), Vector2(100, 70))
	assert_true(a == GroundTiles.ground_texture(BASE, "t_region", Vector2i(100, 70), true))
	var b := GroundTiles.ground_texture(BASE, "t_region", Vector2i(100, 70), false)
	assert_true(_bytes(a) != _bytes(b), "flowers change the lawn")


func test_path_texture_has_fringe_and_rounded_corners() -> void:
	var img := GroundTiles.path_texture(Color("8a7350"), "t_region", Vector2i(60, 30)).get_image()
	assert_eq(img.get_pixel(0, 0).a, 0.0)
	assert_eq(img.get_pixel(30, 0).a, 0.0)
	assert_eq(img.get_pixel(30, 15).a, 1.0)
	assert_eq(img.get_pixel(30, 4).a, 1.0)


## GFX-039: the ground follows the season.
func _mean(t: ImageTexture) -> Dictionary:
	var img := t.get_image()
	var sum := 0.0
	var hue := 0.0
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			sum += c.v
			hue += c.h
			n += 1
	return {"v": sum / n, "h": hue / n}


func _season_ground(season: String) -> ImageTexture:
	return GroundTiles.ground_texture(BASE, "qingshi_village", Vector2i(160, 160), true, season)


func test_winter_ground_is_brighter_than_summer() -> void:
	assert_true(_mean(_season_ground("Winter"))["v"] > _mean(_season_ground("Summer"))["v"] + 0.1)


func test_autumn_hue_shifts_toward_yellow() -> void:
	# Green is ~0.28 hue; ochre/yellow is ~0.13, so the mean hue drops.
	assert_true(_mean(_season_ground("Autumn"))["h"] < _mean(_season_ground("Summer"))["h"])


func test_spring_adds_flower_pixels() -> void:
	assert_true(_bytes(_season_ground("Spring")) != _bytes(_season_ground("Summer")))


func test_season_ground_is_deterministic_and_cached_per_season() -> void:
	for s in ["Spring", "Summer", "Autumn", "Winter"]:
		var a := GroundTiles.ground_texture(BASE, "misty_forest", Vector2i(96, 80), false, s)
		GroundTiles._cache.clear()
		var b := GroundTiles.ground_texture(BASE, "misty_forest", Vector2i(96, 80), false, s)
		assert_true(_bytes(a) == _bytes(b), s)
	assert_true(_bytes(_season_ground("Winter")) != _bytes(_season_ground("Autumn")))


func test_no_snow_region_keeps_summer_ground_in_winter() -> void:
	var map := {"no_snow": true}
	assert_eq(GroundTiles.ground_season("Winter", map), "")
	assert_eq(GroundTiles.ground_season("Winter", {}), "Winter")
	assert_eq(GroundTiles.ground_season("Autumn", map), "Autumn")
	var winter := GroundTiles.ground_texture(BASE, "bog", Vector2i(64, 64), false, GroundTiles.ground_season("Winter", map))
	var summer := GroundTiles.ground_texture(BASE, "bog", Vector2i(64, 64), false, "Summer")
	assert_true(_bytes(winter) == _bytes(summer))


func test_winter_path_is_lighter() -> void:
	var path := Color("8a7350")
	var summer := GroundTiles.path_texture(path, "qingshi_village", Vector2i(48, 32), "")
	var winter := GroundTiles.path_texture(path, "qingshi_village", Vector2i(48, 32), "Winter")
	assert_true(_mean(winter)["v"] > _mean(summer)["v"])

