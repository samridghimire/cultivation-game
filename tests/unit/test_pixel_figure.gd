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


## GFX-196: opaque-pixel mask of a beast frame.
func _beast_mask(kind: String, index: int) -> Dictionary:
	var img := PixelFigure.beast_frame(Color("8a8a8a"), index, kind).get_image()
	var mask := {}
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				mask[Vector2i(x, y)] = true
	return mask


func test_beast_silhouettes_differ_pairwise() -> void:
	var kinds := ["wolf", "boar", "tiger", "deer", "fox"]
	for a in kinds.size():
		for b in range(a + 1, kinds.size()):
			var ma := _beast_mask(kinds[a], 0)
			var mb := _beast_mask(kinds[b], 0)
			var diff := 0
			for p: Vector2i in ma:
				if not mb.has(p):
					diff += 1
			for p: Vector2i in mb:
				if not ma.has(p):
					diff += 1
			var larger := maxi(ma.size(), mb.size())
			assert_true(diff >= larger * 0.15, "%s vs %s differ by %d of %d" % [kinds[a], kinds[b], diff, larger])


func test_wolf_is_leggier_with_a_higher_head_than_boar() -> void:
	var wolf := _beast_mask("wolf", 0)
	var boar := _beast_mask("boar", 0)
	var wolf_top := 99
	var boar_top := 99
	var wolf_head_x := 0
	for p: Vector2i in wolf:
		if p.y < wolf_top:
			wolf_top = p.y
			wolf_head_x = p.x
	var boar_head_y := 0
	for p: Vector2i in boar:
		boar_top = mini(boar_top, p.y)
		if p.x >= 20:
			boar_head_y = maxi(boar_head_y, p.y)
	assert_true(wolf_head_x >= 16, "the wolf's highest pixel is its head (front third): x=%d" % wolf_head_x)
	assert_true(wolf_top < boar_top, "the wolf holds its head higher than the boar's hump")
	assert_true(boar_head_y >= 8, "the boar's snout hangs in the bottom half")


func test_beast_frames_stand_on_the_ground_and_differ_only_in_legs() -> void:
	for kind in PixelFigure.BEAST_KINDS:
		var m0 := _beast_mask(kind, 0)
		var m1 := _beast_mask(kind, 1)
		var bottom0 := 0
		var bottom1 := 0
		for p: Vector2i in m0:
			assert_true(p.x < 24 and p.y < 16, "%s inside the canvas" % kind)
			bottom0 = maxi(bottom0, p.y)
		for p: Vector2i in m1:
			bottom1 = maxi(bottom1, p.y)
		assert_true(bottom0 >= 12 and bottom0 == bottom1, "%s feet on the same bottom row (%d/%d)" % [kind, bottom0, bottom1])
		if kind in ["wolf", "boar", "tiger", "deer", "fox"]:
			for p: Vector2i in m0:
				if p.y < bottom0 - (2 if kind == "deer" else 1) and not m1.has(p):
					assert_true(false, "%s frames differ above the leg rows at %s" % [kind, p])
					return
