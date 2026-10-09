extends TestCase
## WU-059: pointers and spar entries in the NPC menu.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _find(options: Array, prefix: String) -> Dictionary:
	for o: Dictionary in options:
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


func _setup(gs: Node, realm: int, favor: int) -> Array:
	var c := CharacterFactory.create("Hero", gs.data, seeded_rng())
	gs.start_session(c)
	c.realm_index = 1
	c.stage = 1
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(3), {"gender": "female", "region": gs.current_region})
	npc.age_days = 30 * Calendar.DAYS_PER_YEAR
	npc.realm_index = realm
	npc.stage = 5
	gs.npc_favor[npc.id] = favor
	var menu: Node = load("res://src/world/interactables/npc.gd").new()
	menu.npc_id = npc.id
	return [menu, npc]


func test_senior_friend_lists_both() -> void:
	var gs: Node = _root().get_node("GameState")
	var r := _setup(gs, 1, 100)
	var opts: Array = r[0].get_options()
	assert_false(_find(opts, "Ask ").is_empty(), "pointers listed")
	assert_false(_find(opts, "Spar with ").is_empty(), "spar listed")
	assert_false(_find(opts, "Spar with ")["disabled"], _find(opts, "Spar with ")["reason"])
	r[0].free()
	gs.end_session()


func test_stranger_spar_disabled_and_far_realm_hidden() -> void:
	var gs: Node = _root().get_node("GameState")
	var r := _setup(gs, 1, 0)
	var spar := _find(r[0].get_options(), "Spar with ")
	assert_true(spar["disabled"], "needs favor")
	assert_true(String(spar["reason"]).contains("favor"))
	r[0].free()
	r = _setup(gs, 1 + 3, 100)
	var opts: Array = r[0].get_options()
	assert_true(_find(opts, "Spar with ").is_empty(), "realm gap too big")
	r[0].free()
	gs.end_session()
