extends TestCase
## GFX-011: generated 16x20 pixel figures.

const LOOK := {"robe": Color("336699"), "sash": Color("ff0000")}


func test_templates_are_well_formed() -> void:
	for dir in ["down", "up", "right"]:
		for style in ["bun", "long"]:
			for child in [false, true]:
				for i in 3:
					var rows := PixelFigure.rows(dir, i, style, child)
					assert_eq(rows.size(), PixelFigure.SIZE.y, "%s %s %d rows" % [dir, style, i])
					for r in rows:
						assert_eq(r.length(), PixelFigure.SIZE.x, "%s row width: %s" % [dir, r])
						for ch in r:
							assert_true(PixelFigure.PALETTE.contains(ch), "unknown char " + ch)


func test_frame_size_and_cache() -> void:
	var a := PixelFigure.frame(LOOK, "down", 0)
	assert_eq(a.get_width(), 16)
	assert_eq(a.get_height(), 20)
	assert_true(a == PixelFigure.frame(LOOK, "down", 3), "index % 3 shares the cache")
	assert_true(a != PixelFigure.frame({"robe": Color("993333")}, "down", 0))


func test_robe_colour_and_transparent_corners() -> void:
	var img := PixelFigure.frame(LOOK, "down", 0).get_image()
	var found := false
	for y in 20:
		for x in 16:
			if img.get_pixel(x, y).is_equal_approx(LOOK["robe"]):
				found = true
	assert_true(found)
	for p in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 19), Vector2i(15, 19)]:
		assert_eq(img.get_pixelv(p).a, 0.0)


func test_left_mirrors_right() -> void:
	var l := PixelFigure.frame(LOOK, "left", 1).get_image()
	var r := PixelFigure.frame(LOOK, "right", 1).get_image()
	for y in 20:
		for x in 16:
			assert_true(l.get_pixel(x, y).is_equal_approx(r.get_pixel(15 - x, y)))


func test_child_leaves_top_rows_empty() -> void:
	var img := PixelFigure.frame({"robe": LOOK["robe"], "child": true}, "down", 0).get_image()
	for y in 4:
		for x in 16:
			assert_eq(img.get_pixel(x, y).a, 0.0)
	assert_gt(img.get_pixel(7, 4).a + img.get_pixel(8, 4).a + img.get_pixel(6, 4).a + img.get_pixel(9, 4).a, 0.0)


func test_player_look_style_by_gender() -> void:
	var c := CharacterFactory.create("Look", data(), seeded_rng())
	c.gender = "female"
	assert_eq(PlayerLook.of(c, data())["style"], "long")
	c.gender = "male"
	assert_eq(PlayerLook.of(c, data())["style"], "bun")
