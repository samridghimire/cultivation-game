extends TestCase
## FH-013: creation screen explains the talent multiplier and focuses Begin after a reroll.


func test_talent_text_names_grade_and_average() -> void:
	var c := new_character()
	var text: String = load("res://src/ui/character_creation.gd").talent_text(c.spiritual_roots, data())
	assert_true(text.contains("average"), text)
	assert_true(text.contains(String(SpiritualRoots.grade_for(c.spiritual_roots, data())["name"])), text)


func test_reroll_focuses_begin() -> void:
	var scene: Control = (load("res://src/ui/character_creation.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	await (Engine.get_main_loop() as SceneTree).process_frame
	scene._reroll()
	assert_true(scene._begin_button.has_focus())
	scene.queue_free()


func test_talent_verdict_tiers() -> void:
	var cc: GDScript = load("res://src/ui/character_creation.gd")
	assert_eq(cc.talent_verdict(0.5)["label"], "Poor")
	assert_eq(cc.talent_verdict(1.0)["label"], "Average")
	assert_eq(cc.talent_verdict(1.5)["label"], "Good")
	assert_eq(cc.talent_verdict(2.0)["label"], "Excellent")
	assert_eq(cc.talent_verdict(3.0)["label"], "Heaven-sent")


func test_creation_fits_720p_and_first_control_focused() -> void:
	var scene: Control = (load("res://src/ui/character_creation.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var panel: Control = scene._root_box.get_parent().get_parent().get_parent().get_parent()
	assert_true(panel.get_combined_minimum_size().y <= 720.0, str(panel.get_combined_minimum_size()))
	assert_true(scene.get_viewport().gui_get_focus_owner() is Button)
	var has_backdrop := false
	for ch in scene.get_children():
		has_backdrop = has_backdrop or ch is TitleBackdrop
	assert_true(has_backdrop)
	scene.queue_free()


func _scene() -> Control:
	var scene: Control = (load("res://src/ui/character_creation.tscn") as PackedScene).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(scene)
	await (Engine.get_main_loop() as SceneTree).process_frame
	return scene


func test_root_rows_match_rolled_roots() -> void:
	var scene: Control = await _scene()
	scene._roll(false)
	var roots: Dictionary = scene._candidate.spiritual_roots
	var expected := 0
	for id in roots:
		if int(roots[id]) > 0:
			expected += 1
	assert_eq(scene._root_box.get_child_count(), expected)
	for row in scene._root_box.get_children():
		var id: String = row.name.trim_prefix("root_")
		var bar: ProgressBar = row.get_child(2)
		assert_eq(int(bar.value), int(roots[id]))
	scene.queue_free()


func test_sex_change_rebuilds_portrait_and_keeps_name() -> void:
	var scene: Control = await _scene()
	scene._name_edit.text = "Mei"
	var before: Texture2D = scene._portrait.texture
	scene._gender.select(1 - scene._gender.selected)
	scene._on_gender_changed()
	assert_true(scene._portrait.texture != before)
	assert_eq(scene._name_edit.text, "Mei")
	scene.queue_free()


func test_attribute_rows_have_tooltips() -> void:
	var scene: Control = await _scene()
	assert_eq(scene._attr_box.get_child_count(), 5)
	for row in scene._attr_box.get_children():
		assert_true((row as Control).tooltip_text != "")
	scene.queue_free()


func test_focus_reroll_and_buttons_reachable() -> void:
	var scene: Control = await _scene()
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(scene._reroll_button.has_focus())
	var next: Control = scene._reroll_button.find_valid_focus_neighbor(SIDE_RIGHT)
	assert_true(next == scene._begin_button)
	assert_true(scene._begin_button.find_valid_focus_neighbor(SIDE_RIGHT) is Button)
	scene.queue_free()
