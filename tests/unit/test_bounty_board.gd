extends TestCase
## WU-076: the bounty board place lists offers, takes and abandons hunts.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _board() -> Node:
	return load("res://src/world/interactables/bounty_board.gd").new()


func _find(options: Array, prefix: String) -> Dictionary:
	for o: Dictionary in options:
		if String(o["label"]).begins_with(prefix):
			return o
	return {}


func _start() -> Node:
	var gs: Node = _root().get_node("GameState")
	var c := new_character(41)
	c.realm_index = 1
	c.stage = 4
	gs.start_session(c)
	return gs


func test_regions_have_boards() -> void:
	for region_id in ["qingshi_village", "fallen_star_market"]:
		var found := false
		for place: Dictionary in data().regions[region_id]["places"]:
			found = found or place["type"] == "bounty_board"
		assert_true(found, region_id)


func test_take_disables_others_and_abandon_reenables() -> void:
	var gs := _start()
	var board := _board()
	var options: Array = board.get_options()
	var hunt := _find(options, "Hunt: ")
	assert_false(hunt.is_empty(), "a fresh Qi Refining 4 character is offered a hunt")
	assert_false(hunt["disabled"])
	(hunt["action"] as Callable).call()
	assert_false(gs.player.bounty.is_empty())
	options = board.get_options()
	for o: Dictionary in options:
		if String(o["label"]).begins_with("Hunt: "):
			assert_true(o["disabled"])
			assert_eq(o["reason"], "You are already on a hunt.")
	var abandon := _find(options, "Abandon your hunt")
	assert_false(abandon.is_empty())
	(abandon["action"] as Callable).call()
	assert_true(gs.player.bounty.is_empty())
	gs.end_session()
