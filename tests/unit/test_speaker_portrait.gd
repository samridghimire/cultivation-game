extends TestCase
## WU-558: an event dialogue's speaker ({rival} or a named NPC) gets a portrait; an unknown speaker none.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func test_rival_and_named_npc_resolve_unknown_does_not() -> void:
	var gs := _gs()
	gs.start_session(new_character())
	var rival: CharacterData = Rivals.rival_of(gs.player, gs.npcs)
	if rival == null:
		var id := String(gs.npcs.keys()[0])
		gs.player.rival = id
		rival = gs.npcs[id]
	assert_true(SpeakerPortrait.texture_for(rival.name) != null, "rival resolves")
	assert_eq(SpeakerPortrait.npc_id_for(rival.name), rival.id)
	var other_id := ""
	for id: String in gs.npcs:
		if id != rival.id and gs.npcs[id].alive and gs.npcs[id].name != rival.name:
			other_id = id
			break
	assert_true(other_id != "")
	assert_true(SpeakerPortrait.texture_for(gs.npcs[other_id].name) != null, "named NPC resolves")
	assert_true(SpeakerPortrait.texture_for("Nobody At All") == null)
	assert_true(SpeakerPortrait.texture_for("") == null)


func test_event_dialogue_window_shows_rival_face() -> void:
	var gs := _gs()
	gs.start_session(new_character())
	var rival: CharacterData = Rivals.rival_of(gs.player, gs.npcs)
	if rival == null:
		gs.player.rival = String(gs.npcs.keys()[0])
	gs.world_flags.erase("rival_meeting_from")
	assert_true(gs.start_event("rival_first_meeting"))
	var window := DialogueWindow.new()
	window.set_portrait(null)
	window.open()
	assert_true(window.portrait_visible(), "rival's face shows")
	gs.end_dialogue()
	window.free()
