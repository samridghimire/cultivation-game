extends TestCase
## FAM-002d: Court / Propose entries in the NPC menu, for named and generated NPCs.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _start(gs: Node, gender: String) -> CharacterData:
	var c := CharacterFactory.create("Suitor", gs.data, seeded_rng())
	c.gender = gender
	gs.start_session(c)
	return c


func _npc_menu(npc_id: String) -> Node:
	var npc: Node = load("res://src/world/interactables/npc.gd").new()
	npc.npc_id = npc_id
	return npc


func _family_entries(npc: Node) -> Array:
	return npc.get_options().filter(func(o: Dictionary) -> bool:
		var label := String(o["label"])
		return label.begins_with("Court ") or label.begins_with("Propose "))


func test_named_npc_court_and_propose_follow_favor() -> void:
	var gs: Node = _root().get_node("GameState")
	_start(gs, "male")
	var menu := _npc_menu("xiao_ling")
	var entries := _family_entries(menu)
	assert_eq(entries.size(), 3, "court + wife + concubine: %s" % str(entries))
	for e: Dictionary in entries:
		assert_true(e["disabled"], "no favor yet: %s" % e["label"])
		assert_true(String(e["label"]).contains("("), "disabled entries show a reason")
	gs.npc_favor["xiao_ling"] = 20
	entries = _family_entries(menu)
	assert_false(entries[0]["disabled"], "court unlocks at min_favor")
	assert_true(String(entries[0]["label"]).contains("favor 20"), entries[0]["label"])
	assert_true(entries[1]["disabled"], "proposal still needs more favor")
	var before := int(gs.npc_favor["xiao_ling"])
	(entries[0]["action"] as Callable).call()
	assert_gt(int(gs.npc_favor["xiao_ling"]), before, "courting raises favor")
	gs.npc_favor["xiao_ling"] = 60
	entries = _family_entries(menu)
	assert_true(String(entries[1]["label"]).contains("wife"), entries[1]["label"])
	assert_false(entries[1]["disabled"], entries[1]["label"])
	(entries[1]["action"] as Callable).call()
	assert_true(gs.player.spouses.has("xiao_ling"), "proposal accepted")
	assert_eq(_family_entries(menu).size(), 0, "no courting your own spouse")
	menu.free()
	gs.end_session()


func test_generated_npc_offers_entries_and_ineligible_ones_do_not() -> void:
	var gs: Node = _root().get_node("GameState")
	_start(gs, "female")
	var man := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"gender": "male", "region": gs.current_region})
	man.age_days = 20 * Calendar.DAYS_PER_YEAR
	var menu := _npc_menu(man.id)
	var labels: Array = menu.get_options().map(func(o: Dictionary) -> String: return o["label"])
	assert_true(labels.has("Look"), str(labels))
	var entries := _family_entries(menu)
	assert_eq(entries.size(), 1 + Family.ranks(gs.data, "female").size(), str(entries))
	man.gender = "female"
	assert_eq(_family_entries(menu).size(), 0, "partner_genders rule hides the entries")
	man.gender = "male"
	man.age_days = 5 * Calendar.DAYS_PER_YEAR
	assert_eq(_family_entries(menu).size(), 0, "children are not courted")
	menu.free()
	gs.end_session()
