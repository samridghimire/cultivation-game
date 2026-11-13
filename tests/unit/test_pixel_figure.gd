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


func test_accessories_by_role() -> void:
	assert_eq(PixelFigure.accessories_for({"id": "a", "name": "Farmer Tian", "age_years": 40}), PackedStringArray(["straw_hat"]))
	assert_eq(PixelFigure.accessories_for({"id": "b", "title": "Village Hunter", "age_years": 44}), PackedStringArray(["fur_cap"]))
	assert_eq(PixelFigure.accessories_for({"id": "c", "name": "Village Herb Seller", "age_years": 40}), PackedStringArray(["apron"]))
	assert_eq(PixelFigure.accessories_for({"id": "d", "name": "Elder Mo", "age_years": 70}), PackedStringArray(["white_hair", "cane"]))
	assert_eq(PixelFigure.accessories_for({"id": "e", "age_years": 8}).size(), 0, "children wear none")


func test_headscarf_is_seeded_one_in_three() -> void:
	var scarves := 0
	for i in 60:
		var npc := {"id": "villager_%d" % i, "age_years": 30}
		var a := PixelFigure.accessories_for(npc)
		assert_eq(a, PixelFigure.accessories_for(npc), "deterministic")
		if a.has("headscarf"):
			scarves += 1
	assert_true(scarves > 8 and scarves < 35, "about a third wear a scarf: %d" % scarves)


func test_overlays_keep_row_width_and_change_pixels() -> void:
	for dir in ["down", "right"]:
		var base := PixelFigure.rows(dir, 0, "bun", false)
		for acc in PixelFigure.ACCESSORIES:
			var out := PixelFigure.overlay(base, PackedStringArray([acc]), dir == "right")
			for r in out:
				assert_eq(r.length(), PixelFigure.SIZE.x, "%s %s width" % [dir, acc])
			if acc != "white_hair":
				assert_true(out != base, "%s %s changes the figure" % [dir, acc])
	var plain := PixelFigure.frame(LOOK, "down", 0)
	var hat := PixelFigure.frame({"robe": Color("336699"), "sash": Color("ff0000"), "accessories": PackedStringArray(["straw_hat"])}, "down", 0)
	assert_true(plain != hat)
