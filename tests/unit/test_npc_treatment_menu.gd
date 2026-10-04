extends TestCase
## G-007d: "Treat <name>'s <injury>" in the NPC menu and injuries in "Look".


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _npc_menu(npc_id: String) -> Node:
	var npc: Node = load("res://src/world/interactables/npc.gd").new()
	npc.npc_id = npc_id
	return npc


func _treat_entries(npc: Node) -> Array:
	return npc.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Treat "))


func test_injured_generated_npc_can_be_treated() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Healer", gs.data, seeded_rng()))
	var man := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"gender": "male", "region": gs.current_region})
	man.age_days = 30 * Calendar.DAYS_PER_YEAR
	man.injuries.clear()
	var menu := _npc_menu(man.id)
	assert_eq(_treat_entries(menu).size(), 0, "healthy NPCs offer no treatment")
	man.injuries["broken_bones"] = 5
	man.injuries["internal_injury"] = 100
	var entries := _treat_entries(menu)
	assert_eq(entries.size(), 1, str(entries))
	assert_true(String(entries[0]["label"]).contains("internal injury"), "worst injury first: %s" % entries[0]["label"])
	assert_false(entries[0]["disabled"])
	var posted: Array[String] = []
	var collect := func(text: String, _category: String) -> void: posted.append(text)
	EventBus.message_posted.connect(collect)
	var look: Dictionary = menu.get_options().filter(func(o: Dictionary) -> bool: return o["label"] == "Look")[0]
	(look["action"] as Callable).call()
	assert_true(posted.size() > 0 and posted[-1].contains("Broken Bones"), str(posted))
	var day: int = gs.player.age_days
	(entries[0]["action"] as Callable).call()
	EventBus.message_posted.disconnect(collect)
	assert_gt(int(gs.npc_favor.get(man.id, 0)), 0, "treatment earns favor")
	assert_gt(gs.player.age_days, day, "treatment takes time")
	assert_true(int(man.injuries.get("internal_injury", 0)) < 100, "worst injury was treated")
	menu.free()
	gs.end_session()
