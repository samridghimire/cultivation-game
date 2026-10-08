extends TestCase
## WU-008: the title screen's painted backdrop and menu fit 1280x800.


func test_ridges_stay_on_screen_and_layer_downward() -> void:
	for i in TitleBackdrop.RIDGES.size():
		for k in 21:
			var h := TitleBackdrop.ridge_height(i, float(k) / 20.0)
			assert_true(h > 0.2 and h < 1.0, "ridge %d at %d is on screen" % [i, k])
	assert_true(TitleBackdrop.ridge_height(3, 0.5) > TitleBackdrop.ridge_height(0, 0.5), "front ridge is lower")


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
	menu.queue_free()
