extends TestCase
## FriendSceneCard (WU-467): builds from a fixed scene, shows the text, button takes focus, closing emits.

func test_card_builds_and_takes_focus() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var card := FriendSceneCard.new()
	root.add_child(card)
	var closed: Array = []
	card.closed.connect(func() -> void: closed.append(true))
	card.open("xiao_ling", "Xiao Ling", "Xiao Ling shows you the old swing.")
	assert_true(card.visible)
	assert_eq(card.scene_text(), "Xiao Ling shows you the old swing.")
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(card.button().has_focus(), "the Close button holds focus for the gamepad")
	card.close()
	assert_false(card.visible)
	assert_eq(closed.size(), 1)
	card.queue_free()


func test_hud_shows_card_on_signal() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	for i in 4:
		await (Engine.get_main_loop() as SceneTree).process_frame
	EventBus.friend_scene.emit("Xiao Ling", "A quiet moment.")
	EventBus.friend_scene.emit("Xiao Ling", "A second moment.")
	for i in 4:
		await (Engine.get_main_loop() as SceneTree).process_frame
	var card: FriendSceneCard = hud.get("_friend_card")
	var dialogue = hud.get("_dialogue")
	if dialogue.visible:
		assert_false(card.visible, "the card waits behind an open conversation")
		dialogue.close()
		for i in 4:
			await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(card.visible, "pending=%s dlg=%s" % [hud.get("_pending_friend_scenes"), dialogue.visible])
	assert_eq(card.scene_text(), "A quiet moment.")
	card.close()
	assert_true(card.visible, "the second scene follows the first")
	assert_eq(card.scene_text(), "A second moment.")
	card.close()
	assert_false(card.visible)
	root.remove_child(hud)
	hud.free()
	gs.end_session()
