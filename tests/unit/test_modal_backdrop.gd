extends TestCase
## GFX-017: an open modal dims the world and hides the interact prompt; the log card fits its lines.

const HudScript := preload("res://src/ui/hud.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 4) -> void:
	for i in n:
		await _tree().process_frame


func test_panel_is_opaque() -> void:
	assert_eq(UIStyle.PANEL.a, 1.0)


func test_log_card_height_clamps_to_one_to_four_lines() -> void:
	assert_eq(HudScript.log_card_height(0), 20.0)
	assert_eq(HudScript.log_card_height(40), 40.0)
	assert_eq(HudScript.log_card_height(400), 80.0)


func test_backdrop_and_prompt_follow_modals() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	hud.call("_update_modal")
	var backdrop: ColorRect = hud.get("_backdrop")
	var prompt: Label = hud.get("_prompt")
	hud.call("_on_target_changed", "Elder Mo")
	assert_true(not backdrop.visible)
	assert_true(prompt.visible)
	for action: String in ["toggle_inventory", "toggle_map"]:
		var screen: Control = hud.get("_screens")[action]
		screen.open()
		hud.call("_update_modal")
		assert_true(backdrop.visible, action + " dims the world")
		assert_true(not prompt.visible, action + " hides the prompt")
		screen.close()
		hud.call("_update_modal")
		assert_true(not backdrop.visible, action + " closed")
		assert_true(prompt.visible)
	hud.queue_free()
	gs.end_session()


func test_log_card_grows_with_lines() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var panel: Control = hud.get("_log_panel")
	hud.call("_on_message", "First line.", "info")
	await _frames()
	var one := panel.size.y
	hud.call("_on_message", "Second line.", "info")
	hud.call("_on_message", "Third line.", "info")
	await _frames()
	assert_true(panel.size.y > one, "three lines make a taller card than one (%s vs %s)" % [panel.size.y, one])
	hud.queue_free()
	gs.end_session()
