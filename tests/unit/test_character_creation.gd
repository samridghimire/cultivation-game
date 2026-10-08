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
