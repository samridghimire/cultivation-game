extends TestCase
## WU-008 / GFX-105: the title screen's pixel backdrop and menu fit the screen.


func test_ridges_stay_on_screen_and_layer_downward() -> void:
	for i in TitleBackdrop.RANGES.size():
		for x in range(0, TitleBackdrop.W, 8):
			var h := TitleBackdrop.ridge_row(i, x)
			assert_true(h > 40 and h < TitleBackdrop.H, "range %d at %d is on screen" % [i, x])
	assert_true(TitleBackdrop.ridge_row(2, 160) > TitleBackdrop.ridge_row(0, 160), "front range is lower")


func test_scene_has_low_res_size_and_is_deterministic() -> void:
	var a := TitleBackdrop.build_scene()
	var b := TitleBackdrop.build_scene()
	assert_eq(a.get_size(), Vector2i(320, 200))
	assert_true(a.get_data() == b.get_data(), "same pixels every build")


func test_integer_scale_and_letterbox() -> void:
	assert_eq(TitleBackdrop.pixel_scale(Vector2(1280, 800)), 4)
	assert_eq(TitleBackdrop.pixel_scale(Vector2(1920, 1080)), 5)
	assert_eq(TitleBackdrop.canvas_origin(Vector2(1280, 800)), Vector2.ZERO)
	assert_eq(TitleBackdrop.canvas_origin(Vector2(1920, 1080)), Vector2(160, 40))
	assert_eq(TitleBackdrop.pixel_scale(Vector2(100, 100)), 1)


func test_stars_are_fixed_and_clear_of_the_moon() -> void:
	var stars := TitleBackdrop.star_positions()
	assert_eq(stars.size(), 36)
	assert_true(stars == TitleBackdrop.star_positions(), "fixed seed")


func test_reduced_motion_freezes_clouds() -> void:
	var was: Variant = Settings.get_value("reduce_motion")
	Settings.set_value("reduce_motion", true)
	var tree := Engine.get_main_loop() as SceneTree
	var bd := TitleBackdrop.new()
	tree.root.add_child(bd)
	var before := bd._cloud_shift
	bd._process(1.0)
	assert_eq(bd._cloud_shift, before)
	Settings.set_value("reduce_motion", false)
	bd._process(1.0)
	assert_true(bd._cloud_shift > before, "clouds drift when motion is on")
	Settings.set_value("reduce_motion", was)
	bd.queue_free()


func test_main_menu_has_backdrop_and_buttons_fit() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var menu: Control = (load("res://src/ui/main_menu.tscn") as PackedScene).instantiate()
	tree.root.add_child(menu)
	menu.size = Vector2(1280, 800)
	for i in 3:
		await tree.process_frame
	var found := false
	for child in menu.get_children():
		if child is TitleBackdrop:
			found = true
	assert_true(found, "backdrop present")
	for b in menu.find_children("*", "Button", true, false):
		var r := (b as Button).get_global_rect()
		assert_true(r.position.y >= 0 and r.end.y <= 800, "button %s inside viewport" % (b as Button).text)
		assert_true(r.end.x <= 480, "button %s stays in the left column" % (b as Button).text)
	menu.queue_free()


func test_clouds_are_soft_deterministic_and_wrap_through_the_edges() -> void:
	for i in 3:
		var a := TitleBackdrop.cloud_image(i)
		assert_true(a.get_data() == TitleBackdrop.cloud_image(i).get_data(), "cloud %d deterministic" % i)
		var covered := 0
		for y in a.get_height():
			for x in a.get_width():
				var al := a.get_pixel(x, y).a
				assert_true(al < 1.0, "no opaque cloud pixel")
				if al > 0.0:
					covered += 1
		assert_true(covered > 100, "cloud %d has body" % i)
		var xs: Array[int] = []
		for step in 400:
			xs.append(TitleBackdrop.cloud_x(i, float(step)))
		assert_true(xs.min() < 0, "cloud %d enters from off-screen left" % i)
		assert_true(xs.max() + a.get_width() > TitleBackdrop.W - 1 and xs.max() > 0, "cloud %d reaches the right side" % i)


func test_pines_stay_right_of_the_menu_column() -> void:
	var xs := TitleBackdrop.pine_xs()
	assert_true(xs.size() >= 4, "still a treeline")
	for x in xs:
		assert_true(x >= TitleBackdrop.MENU_COLUMN_X, "pine at %d clear of the menu" % x)


func test_seated_figure_is_at_least_7_by_10() -> void:
	var img := TitleBackdrop.build_scene()
	var cols := [TitleBackdrop.ROBE, TitleBackdrop.ROBE_FOLD, TitleBackdrop.HAIR, TitleBackdrop.SKIN]
	var r := Rect2i()
	var first := true
	for y in range(TitleBackdrop.figure_top() - 2, TitleBackdrop.ROCK_GROUND):
		for x in range(TitleBackdrop.FIGURE_X - 8, TitleBackdrop.FIGURE_X + 9):
			var px := img.get_pixel(x, y)
			var hit := false
			for c: Color in cols:
				if absf(px.r - c.r) < 0.01 and absf(px.g - c.g) < 0.01 and absf(px.b - c.b) < 0.01:
					hit = true
			if hit:
				if first:
					r = Rect2i(x, y, 1, 1)
					first = false
				else:
					r = r.expand(Vector2i(x, y))
	assert_true(r.size.x + 1 >= 7 and r.size.y + 1 >= 10, "figure box %s" % str(r))


func test_motes_freeze_under_reduced_motion() -> void:
	var was: Variant = Settings.get_value("reduce_motion")
	Settings.set_value("reduce_motion", true)
	var tree := Engine.get_main_loop() as SceneTree
	var bd := TitleBackdrop.new()
	tree.root.add_child(bd)
	var before := TitleBackdrop.mote_positions(bd._time, true)
	bd._process(0.5)
	bd._process(0.5)
	assert_true(before == TitleBackdrop.mote_positions(bd._time, true), "motes stay put")
	assert_eq(before.size(), TitleBackdrop.MOTE_COUNT)
	Settings.set_value("reduce_motion", was)
	bd.queue_free()
