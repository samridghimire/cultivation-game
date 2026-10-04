extends TestCase
## DialogueWindow renders GameState.dialogue_view() and drives choose_dialogue.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_choice_label_shows_lock_reason() -> void:
	assert_eq(DialogueWindow.choice_label({"label": "Hi", "disabled": false, "reason": ""}), "Hi")
	assert_eq(DialogueWindow.choice_label({"label": "Gift", "disabled": true, "reason": "Need 10 stones"}), "Gift  (Need 10 stones)")


func test_window_renders_and_advances_conversation() -> void:
	var gs := _gs()
	gs.start_session(new_character())
	gs.start_dialogue("elder_mo")
	var window := DialogueWindow.new()
	window.open()
	assert_true(window.visible)
	var view: Dictionary = gs.dialogue_view()
	assert_eq(window.speaker_text(), view["speaker"])
	assert_eq(window.line_text(), view["text"])
	var buttons := window.choice_buttons()
	assert_eq(buttons.size(), view["choices"].size())
	# "What lies beyond the village?" leads to another node, so the window stays open with new text.
	var world_index := -1
	for i in view["choices"].size():
		if view["choices"][i]["label"].begins_with("What lies beyond"):
			world_index = i
	assert_true(world_index >= 0)
	buttons[world_index].pressed.emit()
	assert_true(window.visible)
	assert_eq(window.line_text(), gs.dialogue_view()["text"])
	assert_true(window.line_text() != view["text"])
	gs.end_dialogue()
	window.open()
	assert_false(window.visible)
	window.free()


func test_window_closes_when_conversation_ends() -> void:
	var gs := _gs()
	gs.start_session(new_character())
	gs.start_dialogue("elder_mo")
	var window := DialogueWindow.new()
	window.open()
	var closed := [false]
	window.closed.connect(func(): closed[0] = true)
	var view: Dictionary = gs.dialogue_view()
	for i in view["choices"].size():
		if view["choices"][i]["label"].begins_with("Farewell"):
			window.choice_buttons()[i].pressed.emit()
	assert_eq(gs.dialogue_npc, "")
	assert_false(window.visible)
	assert_true(closed[0])
	window.free()


func test_window_plays_a_story_event() -> void:
	var gs := _gs()
	gs.start_session(new_character())
	gs.start_pending_event()
	var window := DialogueWindow.new()
	window.open()
	assert_true(window.visible, "an event without an NPC opens the window")
	assert_eq(window.line_text(), gs.dialogue_view()["text"])
	window.choice_buttons()[0].pressed.emit()
	assert_true(window.visible, "the event continues to its next node")
	assert_eq(window.speaker_text(), "The Creation Artifact")
	gs.end_dialogue()
	gs.end_session()
	window.free()
