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



func _styled(style: String, rid: String = "styled") -> ImageTexture:
	return GroundTiles.ground_texture(BASE, rid, Vector2i(96, 96), false, "", style)


func _edge_count(tex: ImageTexture) -> int:
	var img := tex.get_image()
	var n := 0
	for y in img.get_height():
		for x in img.get_width() - 1:
			# Strong edges only: grass speckle is subtle, mortar lines are not.
			if absf(img.get_pixel(x, y).get_luminance() - img.get_pixel(x + 1, y).get_luminance()) > 0.08:
				n += 1
	return n


func test_ground_styles_are_deterministic_and_differ() -> void:
	for s in GroundTiles.STYLES:
		var a := _styled(s)
		GroundTiles._cache.clear()
		var b := _styled(s)
		assert_true(_bytes(a) == _bytes(b), s)
	assert_true(_bytes(_styled("paved")) != _bytes(_styled("grass")))
	assert_true(_bytes(_styled("scree")) != _bytes(_styled("grass")))
	assert_true(_bytes(_styled("litter")) != _bytes(_styled("grass")))


func test_paved_has_more_edges_than_grass() -> void:
	assert_true(_edge_count(_styled("paved")) > _edge_count(_styled("grass")))


func test_bog_is_darker_than_grass() -> void:
	assert_true(_mean(_styled("bog"))["v"] < _mean(_styled("grass"))["v"])


func test_paved_path_differs_from_plain_path() -> void:
	var c := Color("9c917a")
	var a := GroundTiles.path_texture(c, "styled", Vector2i(60, 48), "", "paved")
	var b := GroundTiles.path_texture(c, "styled", Vector2i(60, 48), "", "grass")
	assert_true(_bytes(a) != _bytes(b))


func test_unknown_ground_style_is_rejected() -> void:
	var d := GameData.load_from_dir()
	d.regions["qingshi_village"]["map"]["ground_style"] = "lava"
	d.load_errors.clear()
	d._validate()
	assert_true(", ".join(d.load_errors).contains("ground_style"))


## GFX-064: snow on paved ground is thinner, so the flagstone grid stays visible in winter.
func test_paved_winter_keeps_the_grid() -> void:
	var summer := GroundTiles.ground_texture(BASE, "fallen_star_market", Vector2i(64, 64), false, "", "paved").get_image()
	var plain := GroundTiles.ground_texture(BASE, "fallen_star_market", Vector2i(64, 64), false, "Winter", "grass").get_image()
	var paved := GroundTiles.ground_texture(BASE, "fallen_star_market", Vector2i(64, 64), false, "Winter", "paved").get_image()
	# Mortar row y=16: how far it sits from a stone pixel (y=20) in the same column.
	var gap_paved := absf(paved.get_pixel(5, 20).v - paved.get_pixel(5, 16).v)
	var gap_summer := absf(summer.get_pixel(5, 20).v - summer.get_pixel(5, 16).v)
	assert_true(gap_paved > gap_summer * 0.4, "mortar still reads through the snow")
	assert_true(paved.get_pixel(5, 20).v < plain.get_pixel(5, 20).v + 0.5)
	assert_eq(GroundTiles.PAVED_SNOW < GroundTiles.WINTER_SNOW, true)


## GFX-158: in a winter market the swept streets stay darker than the snowy earth lots.
func test_winter_market_streets_darker_than_lots() -> void:
	assert_eq(GroundTiles.winter_street_amount(true, false, "m", 1, 1), 0.2)
	assert_eq(GroundTiles.winter_street_amount(true, true, "m", 1, 1), 0.7)
	var bare := 0
	for i in 1600:
		if GroundTiles.winter_street_amount(false, false, "m", (i % 40) * 20, (i / 40) * 20) < 0.5:
			bare += 1
	assert_true(bare >= 160 and bare <= 640, "some, not most, of the lots are bare, got %d of 1600" % bare)
	var zones := [Rect2(0, 24, 96, 24)]
	var tex := GroundTiles.ground_texture(BASE, "winter_mkt", Vector2i(96, 72), false, "Winter", "paved", zones).get_image()
	assert_true(tex.get_pixel(48, 36).v < tex.get_pixel(48, 4).v + 0.3, "street centre is not paler than the lot")


## GFX-175: the ridge's scree ground gets alpine detail that differs by season and is deterministic.
func test_alpine_ground_varies_by_season() -> void:
	var size := Vector2i(400, 300)
	var spring := GroundTiles.ground_texture(BASE, "alp_t", size, false, "Spring", "scree").get_image().get_data()
	var summer := GroundTiles.ground_texture(BASE, "alp_t", size, false, "Summer", "scree").get_image().get_data()
	var autumn := GroundTiles.ground_texture(BASE, "alp_t", size, false, "Autumn", "scree").get_image().get_data()
	assert_true(spring != summer and summer != autumn)
	assert_true(GroundTiles.alpine_blobs("alp_t", "hollow", 5, size) == GroundTiles.alpine_blobs("alp_t", "hollow", 5, size))
	for b in GroundTiles.alpine_blobs("alp_t", "fan", 20, size):
		assert_true(b.x < size.x and b.y < size.y)


## GFX-181: meadow blobs are deterministic and avoid rects; autumn grass has more rust/straw than summer.
func test_meadow_blobs_and_autumn_rust() -> void:
	var size := Vector2i(400, 300)
	var avoid: Array = [Rect2(50, 50, 200, 150)]
	var a := GroundTiles.meadow_blobs("mdw_t", "lone", 200, size, avoid)
	assert_true(a == GroundTiles.meadow_blobs("mdw_t", "lone", 200, size, avoid))
	assert_true(a.size() > 20)
	for b in a:
		assert_false(avoid[0].has_point(Vector2(b.x, b.y)), "blob inside avoid rect")
	var rust := func(season: String) -> int:
		var img := GroundTiles.ground_texture(BASE, "mdw_t", size, false, season, "grass", [], 1.0, {"avoid": avoid}).get_image()
		var n := 0
		for y in size.y:
			for x in size.x:
				var c := img.get_pixel(x, y)
				if c.r > c.g + 0.05 and c.r > 0.5:
					n += 1
		return n
	assert_true(rust.call("Autumn") > rust.call("Summer"), "autumn has more rust pixels")


## PERF-008: the cached zone jitter answers exactly as the per-pixel hash does (70x50 is not a multiple of 8).
func test_paved_zone_grid_matches_per_pixel_hash() -> void:
	var zones: Array = [Rect2(0, 16, 70, 24), Rect2(30, 0, 24, 50)]
	var grid := GroundTiles.zone_jitter_grid("zg", 70, 50)
	var cols := ceili(70.0 / 8.0)
	for y in 50:
		for x in 70:
			for inset in [0.0, 4.0]:
				assert_true(GroundTiles.in_paved_zone(zones, "zg", x, y, inset) == GroundTiles.in_paved_zone_grid(zones, grid, cols, x, y, inset), "zone differs at %d,%d" % [x, y])


## GFX-187: an alpine meadow ground differs from plain scree, by season, and is deterministic.
func test_alpine_meadow_ground() -> void:
	var size := Vector2i(400, 300)
	var life := {"alpine_meadow": true}
	for season in ["Spring", "Summer", "Winter"]:
		var plain := GroundTiles.ground_texture(BASE, "alm_t", size, false, season, "scree").get_image().get_data()
		var meadow := GroundTiles.ground_texture(BASE, "alm_t", size, false, season, "scree", [], 1.0, life).get_image().get_data()
		assert_true(plain != meadow, "meadow differs from scree in " + season)
	var s := GroundTiles.ground_texture(BASE, "alm_t", size, false, "Spring", "scree", [], 1.0, life).get_image().get_data()
	var u := GroundTiles.ground_texture(BASE, "alm_t", size, false, "Summer", "scree", [], 1.0, life).get_image().get_data()
	assert_true(s != u)


## GFX-187: neighbouring alpine blobs are spread out (they once stacked into one dark smear).
func test_alpine_blobs_are_spread() -> void:
	var size := Vector2i(800, 500)
	var blobs := GroundTiles.alpine_blobs("azure_peak", "hollow", 6, size)
	for i in blobs.size():
		for j in range(i + 1, blobs.size()):
			assert_true(Vector2(blobs[i].x, blobs[i].y).distance_to(Vector2(blobs[j].x, blobs[j].y)) > 20.0, "blobs %d and %d overlap" % [i, j])
