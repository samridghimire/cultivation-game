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
