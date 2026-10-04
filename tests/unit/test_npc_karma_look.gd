extends TestCase
## RIV-001b: an NPC's "Look" text says whether they hate or owe the player.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _look_text(gs: Node, npc_id: String) -> String:
	var menu: Node = load("res://src/world/interactables/npc.gd").new()
	menu.npc_id = npc_id
	var look: Dictionary = {}
	for o: Dictionary in menu.get_options():
		if o["label"] == "Look":
			look = o
	if look.is_empty():
		menu.free()
		return "<no Look entry>"
	var posted: Array[String] = []
	var grab := func(text: String, _category: String = "") -> void: posted.append(text)
	EventBus.message_posted.connect(grab)
	(look["action"] as Callable).call()
	EventBus.message_posted.disconnect(grab)
	menu.free()
	return "\n".join(posted)


func test_look_mentions_grudge_and_gratitude() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Watcher", gs.data, seeded_rng()))
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"gender": "female", "region": gs.current_region})
	npc.age_days = 30 * Calendar.DAYS_PER_YEAR
	var text := _look_text(gs, npc.id)
	assert_true(text.contains(npc.name), text)
	assert_false(text.contains("resent"), "no grudge yet: %s" % text)
	Karma.add_grudge(gs.player, gs.data, npc.id, 50)
	assert_true(_look_text(gs, npc.id).contains("hates you"), _look_text(gs, npc.id))
	Karma.add_gratitude(gs.player, gs.data, "xiao_ling", 20)
	assert_true(_look_text(gs, "xiao_ling").contains("grateful"), "named NPCs can be looked at too")
	gs.end_session()
