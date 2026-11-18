extends TestCase
## GFX-130: soft light/dark ground patches, clover spots and worn ground.

const BASE := Color("4d6b3c")


func test_patch_shade_deterministic_and_ranged() -> void:
	var seen_light := false
	var seen_dark := false
	for gy in 25:
		for gx in 40:
			var a := GroundTiles.patch_shade("qingshi_village", gx * 96, gy * 96)
			assert_eq(a, GroundTiles.patch_shade("qingshi_village", gx * 96, gy * 96))
			assert_true(a >= -1.0 and a <= 1.0, "in range")
			seen_light = seen_light or a > 0.35
			seen_dark = seen_dark or a < -0.35
	assert_true(seen_light and seen_dark, "both patch kinds occur")


func test_patch_shade_has_no_seams() -> void:
	var rng := seeded_rng(7)
	for i in 200:
		var x := rng.randi_range(0, 3000)
		var y := rng.randi_range(0, 2000)
		assert_true(absf(GroundTiles.patch_shade("misty_forest", x, y) - GroundTiles.patch_shade("misty_forest", x + 1, y)) < 0.08, "smooth")


func test_grid_matches_function() -> void:
	var g := GroundTiles.shade_grid_for("qingshi_village", Vector2i(120, 90))
	assert_almost_eq(g[50 * 120 + 70], GroundTiles.patch_shade("qingshi_village", 70, 50), 0.001)


func test_clover_avoids_paths() -> void:
	var avoid: Array = [Rect2(200, 0, 40, 600), Rect2(0, 250, 600, 40)]
	var rects := GroundTiles.clover_rects("qingshi_village", Vector2i(600, 600), avoid)
	assert_gt(rects.size(), 0)
	assert_true(rects.size() <= 12)
	for r in rects:
		for a: Rect2 in avoid:
			assert_false(a.intersects(r), "clover off the path")


func test_paved_and_scree_unchanged_by_life() -> void:
	for style in ["paved", "scree"]:
		var a := GroundTiles.ground_texture(BASE, "life_" + style, Vector2i(96, 96), false, "", style)
		var b := GroundTiles.ground_texture(BASE, "life_" + style, Vector2i(96, 96), false, "", style, [], 1.0, {"avoid": [], "worn": [Rect2(0, 0, 90, 90)]})
		assert_true(a.get_image().get_data() == b.get_image().get_data(), style + " ignores life")


func test_grass_gets_patches() -> void:
	var tex := GroundTiles.ground_texture(BASE, "qingshi_village", Vector2i(400, 300), false)
	var img := tex.get_image()
	var lo := 9.0
	var hi := 0.0
	for y in range(0, 300, 5):
		for x in range(0, 400, 5):
			var l := img.get_pixel(x, y).get_luminance()
			lo = minf(lo, l)
			hi = maxf(hi, l)
	assert_gt(hi - lo, 0.04, "tonal variety")


## GFX-193: patch tint is hard-edged: steps in -2..2 and a patch edge never ramps over more than 2 px.
func test_patch_step_is_quantised() -> void:
	for i in 41:
		var s := -1.0 + float(i) * 0.05
		for c in 4:
			var st := GroundTiles.patch_step(s, c, 0)
			assert_true(absi(st) <= 2, "two steps at most")
			assert_true(st == 0 or (st > 0) == (s > 0.0), "sign follows the shade")
	assert_eq(GroundTiles.patch_step(0.0, 0, 0), 0)
	assert_eq(GroundTiles.patch_step(0.9, 1, 0), 2)
	assert_eq(GroundTiles.patch_step(-0.9, 1, 0), -2)


func test_ground_patches_have_few_colours_and_are_deterministic() -> void:
	var a := GroundTiles.ground_texture(BASE, "gfx193_test", Vector2i(192, 192), false, "Summer", "grass").get_image()
	GroundTiles._cache.clear()
	var b := GroundTiles.ground_texture(BASE, "gfx193_test", Vector2i(192, 192), false, "Summer", "grass").get_image()
	assert_true(a.get_data() == b.get_data(), "identical across two builds")
	# No smooth ramp: along any 8 px row run the patch layer adds at most the base + 2 tint steps, so
	# count distinct colours across the whole image stays bounded far below a continuous gradient.
	var seen := {}
	for y in 192:
		for x in 192:
			seen[a.get_pixel(x, y).to_html()] = true
	assert_true(seen.size() < 400, "no alpha gradient: %d colours" % seen.size())
