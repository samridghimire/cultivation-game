extends TestCase
## FAM-003e: the orphanage place and the "Adopt <name>" NPC menu entry.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _adopt_entries(menu: Node) -> Array:
	return menu.get_options().filter(func(o: Dictionary) -> bool: return String(o["label"]).begins_with("Adopt "))


func test_orphanage_is_placed_in_the_village() -> void:
	var gs: Node = _root().get_node("GameState")
	var found := false
	for place: Dictionary in gs.data.regions["qingshi_village"]["places"]:
		found = found or place["type"] == "orphanage"
	assert_true(found, "Qingshi Village has an orphanage")


func test_orphan_menu_entry_adopts() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Su Yan", gs.data, seeded_rng(), "female")
	gs.start_session(c)
	gs.current_region = "qingshi_village"
	var orphan := Npcs.spawn(gs.npcs, gs.data, seeded_rng(4), {"age_years": 4, "region": "qingshi_village"})
	var menu: Node = load("res://src/world/interactables/npc.gd").new()
	menu.npc_id = orphan.id
	var entries := _adopt_entries(menu)
	assert_eq(entries.size(), 1, str(entries))
	assert_false(entries[0]["disabled"], entries[0]["label"])
	(entries[0]["action"] as Callable).call()
	assert_true(c.children.has(orphan.id), "adopted")
	assert_eq(_adopt_entries(menu).size(), 0, "no adopting your own child")
	var teen := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 15, "region": "qingshi_village"})
	menu.npc_id = teen.id
	assert_eq(_adopt_entries(menu).size(), 0, "too old to be adopted: no entry")
	menu.free()
	gs.end_session()


func test_orphanage_foundling_needs_donation() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Su Yan", gs.data, seeded_rng(), "female")
	gs.start_session(c)
	c.inventory.erase("spirit_stone")
	var orphanage: Node = load("res://src/world/interactables/orphanage.gd").new()
	var options: Array[Dictionary] = orphanage.get_options()
	assert_eq(options.size(), 1)
	assert_true(options[0]["disabled"], options[0]["label"])
	assert_true(String(options[0]["label"]).contains("donation"), options[0]["label"])
	c.add_item("spirit_stone", Adoption.foundling_donation(gs.data))
	options = orphanage.get_options()
	assert_false(options[0]["disabled"], options[0]["label"])
	(options[0]["action"] as Callable).call()
	assert_eq(c.children.size(), 1, "foundling adopted")
	orphanage.free()
	gs.end_session()
