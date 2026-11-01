extends TestCase
## WU-423: the world draws today's roamers as beast nodes.


func _world(region: String) -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = region
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	return world


func _count(world: Node) -> int:
	var n := 0
	for c in world.get_children():
		if c is Roamer and not c.is_queued_for_deletion():
			n += 1
	return n


func test_spawns_as_many_as_roamers_here() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("misty_forest")
	assert_true(gs.roamers_here().size() >= 2)
	assert_eq(_count(world), gs.roamers_here().size())
	world.free()
	world = _world("qingshi_village")
	assert_eq(_count(world), 0)
	world.free()
	gs.end_session()


func test_engaging_removes_one_and_menu_options() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("misty_forest")
	var node: Roamer = null
	for c in world.get_children():
		if c is Roamer:
			node = c
			break
	var labels: Array = node.get_options().map(func(o: Dictionary) -> String: return o["label"])
	assert_eq(labels, ["Fight", "Leave"])
	assert_true(node.display_name.ends_with(")"), node.display_name)
	gs.engage_roamer(node.slot)
	# The fight may take days, which rebuilds the set: the engaged beast's node is gone either way.
	assert_true(node.is_queued_for_deletion() or node._fading, "engaged beast leaves")
	world.free()
	gs.end_session()


func test_spots_are_deterministic_and_clear() -> void:
	var blocked: Array[Rect2] = [Rect2(100, 100, 400, 400)]
	var avoid: Array[Vector2] = [Vector2(50, 50)]
	var a := Roamer.pick_spot("r", 3, 1, Vector2(1600, 1000), blocked, avoid)
	var b := Roamer.pick_spot("r", 3, 1, Vector2(1600, 1000), blocked, avoid)
	assert_eq(a, b)
	assert_false(blocked[0].grow(48.0).has_point(a))


func test_stays_within_radius_of_home() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("misty_forest")
	var node: Roamer = null
	for c in world.get_children():
		if c is Roamer:
			node = c
			break
	for i in 1200:
		node._wander(1.0 / 20.0)
		assert_true(node.position.distance_to(node.home) <= Roamer.WANDER_RADIUS + 1.0)
	world.free()
	gs.end_session()
