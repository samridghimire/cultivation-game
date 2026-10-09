extends TestCase
## WU-099: "Give <item> (they asked in a letter)" in the NPC menu.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _entries(npc: Node) -> Array:
	return npc.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).ends_with("(they asked in a letter)"))


func test_letter_entry_present_disabled_and_absent() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Friend", gs.data, seeded_rng()))
	var man := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"gender": "male", "region": gs.current_region})
	var menu: Node = load("res://src/world/interactables/npc.gd").new()
	menu.npc_id = man.id
	assert_eq(_entries(menu).size(), 0, "no request, no entry")
	gs.player.letter_requests.append({"npc_id": man.id, "item": "qi_gathering_pill", "count": 1, "until": GameClock.total_days + 30, "favor": 10, "effects": {}})
	var entries := _entries(menu)
	assert_eq(entries.size(), 1)
	assert_true(String(entries[0]["label"]).contains("Qi Gathering Pill"), entries[0]["label"])
	assert_true(entries[0]["disabled"], "no pill carried")
	assert_true(String(entries[0]["reason"]) != "", "has a reason")
	gs.player.inventory["qi_gathering_pill"] = 1
	entries = _entries(menu)
	assert_false(entries[0]["disabled"])
	(entries[0]["action"] as Callable).call()
	assert_gt(int(gs.npc_favor.get(man.id, 0)), 0, "favor earned")
	assert_eq(_entries(menu).size(), 0, "answered request is gone")
	menu.free()
	gs.end_session()
