extends TestCase
## WU-568: Elder Mo's first talk offers at most 4 choices; the rest appear once his favor grows.


func _choice_count(favor: int) -> int:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Tester", gs.data, seeded_rng(7))
	gs.start_session(c)
	gs.pending_event = ""
	gs.npc_favor["elder_mo"] = favor
	gs.start_dialogue("elder_mo")
	var n := 0
	for ch: Dictionary in gs.dialogue_view().get("choices", []):
		n += 1 if ch.has("label") else 0
	gs.end_dialogue()
	return n


func test_first_talk_lists_at_most_four() -> void:
	assert_true(_choice_count(0) <= 4, "first talk has <= 4 choices")


func test_later_talk_lists_more() -> void:
	assert_true(_choice_count(10) > _choice_count(0), "more choices once favor grows")
