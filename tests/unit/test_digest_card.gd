extends TestCase
## WU-416: the "While you were away" card.

const DIGEST := {"days": 15, "lines": ["A storm passes.", "Your crops are ready to harvest."]}


func _hud() -> CanvasLayer:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	return hud


func _finish(hud: CanvasLayer) -> void:
	hud.queue_free()
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.last_digest = {}
	gs.end_session()


func test_should_show_only_for_five_plus_days() -> void:
	assert_true(DigestCard.should_show(DIGEST))
	assert_false(DigestCard.should_show({"days": 4, "lines": ["x"]}))
	assert_false(DigestCard.should_show({}))
	assert_false(DigestCard.should_show({"days": 9, "lines": []}))


func test_title_and_line_cap() -> void:
	assert_eq(DigestCard.title_for(15), "15 days pass")
	var many: Array = ["a", "b", "c", "d", "e", "f", "g"]
	assert_eq(DigestCard.shown_lines({"days": 9, "lines": many}).size(), DigestCard.MAX_LINES)
	var card := DigestCard.new()
	card.show_digest(DIGEST)
	assert_true(card.is_showing())
	assert_eq(card.title_text(), "15 days pass")
	assert_eq(card.line_count(), 2)
	card.dismiss()
	assert_false(card.is_showing())
	card.free()


func test_closes_on_input() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var card := DigestCard.new()
	tree.root.add_child(card)
	card.show_digest(DIGEST)
	card._age = 1.0
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_SPACE
	card._input(ev)
	assert_false(card.is_showing())
	card.queue_free()


func test_hud_shows_digest_and_hides_behind_modal() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	var hud := _hud()
	await tree.process_frame
	var card: DigestCard = hud.get("_digest_card")
	hud.get("_banner").visible = false
	gs.last_digest = DIGEST
	await tree.process_frame
	await tree.process_frame
	assert_true(card.is_showing(), "shown after a long action")
	card.dismiss()
	# A modal open: nothing new shows.
	gs.last_digest = {}
	await tree.process_frame
	hud.get("_choice_menu").visible = true
	hud.call("_update_modal")
	gs.last_digest = DIGEST
	await tree.process_frame
	await tree.process_frame
	assert_false(card.is_showing(), "hidden while a modal is open")
	hud.get("_choice_menu").visible = false
	hud.call("_update_modal")
	await tree.process_frame
	await tree.process_frame
	assert_true(card.is_showing(), "queued card shows once the modal closes")
	_finish(hud)
