extends TestCase
## WU-601: friendship moments (oath, tend card, gift card) queue behind open screens and play in order.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _make_hud() -> CanvasLayer:
	var root := _tree().root
	root.size = Vector2i(1280, 800)
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	gs.npc_favor["hunter_ma"] = 90
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	for i in 4:
		await _tree().process_frame
	return hud


func _finish(hud: CanvasLayer) -> void:
	_tree().root.gui_release_focus()
	hud.free()
	await _tree().process_frame
	_tree().root.get_node("GameState").end_session()


func _open_help(hud: CanvasLayer) -> void:
	hud.set("_help_from_key", true)
	hud.call("_help_screen").open()
	hud.call("_update_modal")


func _close_help(hud: CanvasLayer) -> void:
	hud.call("_help_screen").close()
	hud.call("_update_modal")
	for i in 3:
		await _tree().process_frame


func test_oath_waits_for_open_screen() -> void:
	var hud: CanvasLayer = await _make_hud()
	var bus: Node = _tree().root.get_node("EventBus")
	var oath: Control = hud.get("_sworn_oath")
	_open_help(hud)
	bus.friendship_reached.emit("hunter_ma", "Hunter Ma: Sworn friend")
	assert_false(oath.visible, "oath held behind the screen")
	assert_eq(hud.get("_pending_moments").size(), 1)
	await _close_help(hud)
	assert_true(oath.visible, "oath starts once the screen closes")
	assert_eq(hud.get("_pending_moments").size(), 0)
	oath.end()
	await _finish(hud)


func test_tend_not_dropped_behind_report() -> void:
	var hud: CanvasLayer = await _make_hud()
	var bus: Node = _tree().root.get_node("EventBus")
	var skip: Control = hud.get("_time_skip")
	hud.get("_combat_report").show_fight("Wolf", true, PackedStringArray(["You win."]))
	hud.call("_update_modal")
	bus.friend_tended.emit("hunter_ma", 3)
	assert_false(skip.visible, "tend card waits")
	assert_eq(hud.get("_pending_moments").size(), 1)
	hud.get("_combat_report").close()
	hud.call("_update_modal")
	for i in 3:
		await _tree().process_frame
	assert_true(skip.visible, "tend card plays after the report")
	skip.close()
	await _finish(hud)


func test_two_moments_play_in_order() -> void:
	var hud: CanvasLayer = await _make_hud()
	var bus: Node = _tree().root.get_node("EventBus")
	var oath: Control = hud.get("_sworn_oath")
	var skip: Control = hud.get("_time_skip")
	_open_help(hud)
	bus.friendship_reached.emit("hunter_ma", "Hunter Ma: Sworn friend")
	bus.friend_tended.emit("hunter_ma", 2)
	assert_eq(hud.get("_pending_moments").size(), 2)
	await _close_help(hud)
	assert_true(oath.visible, "oath first")
	assert_false(skip.visible, "tend card waits for the oath")
	assert_eq(hud.get("_pending_moments").size(), 1)
	oath.end()
	for i in 3:
		await _tree().process_frame
	assert_true(skip.visible, "tend card after the oath")
	skip.close()
	await _finish(hud)


func test_return_to_menu_empties_queue() -> void:
	var hud: CanvasLayer = await _make_hud()
	var bus: Node = _tree().root.get_node("EventBus")
	_open_help(hud)
	bus.friend_tended.emit("hunter_ma", 2)
	assert_eq(hud.get("_pending_moments").size(), 1)
	hud.get("_pending_moments").clear()  # mirrors _return_to_menu without changing scene
	assert_eq(hud.get("_pending_moments").size(), 0)
	hud.call("_help_screen").close()
	await _finish(hud)


func test_queued_tend_keeps_its_own_line() -> void:
	# [REVIEW] two tendings queued on one arrival: each card shows its own friend's line, not the last one written.
	var hud: CanvasLayer = await _make_hud()
	var gs: Node = _tree().root.get_node("GameState")
	var bus: Node = _tree().root.get_node("EventBus")
	var skip: Control = hud.get("_time_skip")
	_open_help(hud)
	gs.last_tend_line = "first line"
	bus.friend_tended.emit("hunter_ma", 2)
	gs.last_tend_line = "second line"
	bus.friend_tended.emit("hunter_ma", 3)
	await _close_help(hud)
	assert_true(skip.visible)
	assert_eq(String(skip.call("summary_text")).split("\n")[0], "first line")
	skip.close()
	gs.last_tend_line = ""
	await _finish(hud)
