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


func _first_roamer(world: Node) -> Roamer:
	for c in world.get_children():
		if c is Roamer:
			return c
	return null


func _still_player(world: Node, pos: Vector2) -> void:
	world.player.position = pos
	world.player.set_physics_process(false)


func test_fleeing_beast_gains_distance() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("misty_forest")
	var node := _first_roamer(world)
	node.temper = "flees"
	_still_player(world, node.position + Vector2(60, 0))
	var before := node.position.distance_to(world.player.position)
	for i in 60:
		node._wander(1.0 / 60.0)
	assert_true(node.position.distance_to(world.player.position) > before + 20.0)
	assert_true(node.position.x >= 24.0 and node.position.y >= 24.0)
	world.free()
	gs.end_session()


func test_bold_beast_closes_in_and_asks_once() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("misty_forest")
	var node := _first_roamer(world)
	node.temper = "bold"
	_still_player(world, node.position + Vector2(140, 0))
	var before := node.position.distance_to(world.player.position)
	node._wander(1.0 / 60.0)
	assert_true(node.noticed)
	var asks := [0]
	var cb := func(_s: Node) -> void: asks[0] += 1
	EventBus.interaction_menu_requested.connect(cb)
	for i in 120:
		node._wander(1.0 / 60.0)
	assert_true(node.position.distance_to(world.player.position) < before)
	assert_eq(asks[0], 1)
	EventBus.interaction_menu_requested.disconnect(cb)
	world.free()
	gs.end_session()


func test_charged_fight_passes_charged_flag() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("misty_forest")
	var node := _first_roamer(world)
	var plain: Callable = node.get_options()[0]["action"]
	assert_eq(plain.get_bound_arguments(), [node.slot, false])
	node.charged = true
	var charged_action: Callable = node.get_options()[0]["action"]
	assert_eq(charged_action.get_bound_arguments(), [node.slot, true])
	assert_false(node.charged, "reset once the menu is read")
	world.free()
	gs.end_session()


func test_beasts_keep_apart() -> void:
	var blocked: Array[Rect2] = []
	var avoid: Array[Vector2] = []
	var spots: Array[Vector2] = []
	for slot in 4:
		var s := Roamer.pick_spot("misty_forest", 7, slot, Vector2(1600, 1000), blocked, avoid)
		avoid.append(s)
		spots.append(s)
	for i in 4:
		for j in range(i + 1, 4):
			assert_true(spots[i].distance_to(spots[j]) >= 72.0, "beasts %d and %d" % [i, j])


func test_taking_bounty_spawns_quarry_at_once() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("misty_forest")
	gs.data.bounties["t_bounty"] = {"id": "t_bounty", "enemy": "wild_boar", "region": "misty_forest", "reward_stones": 25, "days": 30, "cooldown_days": 10, "text": "Test posting."}
	var before := _count(world)
	gs.take_bounty("t_bounty")
	var found := false
	for c in world.get_children():
		if c is Roamer and c.slot == Wildlife.BOUNTY_SLOT and not c.is_queued_for_deletion():
			found = true
	assert_true(found, "quarry node present")
	assert_eq(_count(world), before + 1)
	gs.data.bounties.erase("t_bounty")
	world.free()
	gs.end_session()


## WU-429: a fleeing step into a blocked rect slides or stops, over 60 physics steps.
func test_flee_does_not_enter_blocked_rect() -> void:
	var blocked: Array[Rect2] = [Rect2(200, 100, 100, 100)]
	var pos := Vector2(180, 150)
	for i in 60:
		pos = Roamer.flee_position(pos, Vector2(2.2, 0.5), Vector2(1000, 1000), blocked)
		assert_false(blocked[0].has_point(pos), str(pos))
	assert_true(pos.y > 150.0, "slid along the free axis")


## WU-429: water effects sit with the ground layer, below the player.
func test_water_life_below_player() -> void:
	var w := WaterLife.new()
	w.setup({"id": "t", "map": {}}, false, false, true)
	assert_true(w.z_index <= 0)
	w.free()


func test_great_roamer_is_gold_and_labelled() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("misty_forest")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var plain := Roamer.new()
	plain.setup(1, "wild_boar", Vector2(100, 100), 1)
	var great := Roamer.new()
	great.setup(101, "fog_antler_stag", Vector2(200, 200), 1, true)
	assert_false(plain.display_name.ends_with("(great)"))
	assert_true(great.display_name.contains("(great)"), great.display_name)
	assert_eq(great.label_color(), Roamer.GREAT_GOLD)
	assert_eq(plain.label_color(), Color.WHITE)
	assert_eq(Roamer.GREAT_SCALE, 1.5)
	plain.free()
	great.free()
	world.free()
	gs.end_session()
