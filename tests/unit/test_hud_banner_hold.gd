extends TestCase
## WU-523: banners wait while any HUD modal is open and play after the last one closes.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_milestone_banner_waits_for_help_screen() -> void:
	var root := _tree().root
	root.size = Vector2i(1280, 800)
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	for i in 4:
		await _tree().process_frame
	var banner: Control = hud.get("_banner")
	banner.finish_current()
	hud.set("_help_from_key", true)
	hud.get("_help").open()
	await _tree().process_frame
	hud.call("_update_modal")
	root.get_node("EventBus").milestone_reached.emit("test_id", "Paired Hearts")
	assert_false(banner.visible, "banner hidden while help is open")
	hud.get("_help").close()
	hud.call("_update_modal")
	assert_true(banner.visible, "banner plays after the modal closes")
	root.gui_release_focus()
	hud.free()
	await _tree().process_frame
	gs.end_session()
