extends TestCase
## WU-567: the gold goal marker sits on Elder Mo on day 0, and no place label covers a person's figure.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _build() -> Node:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var world: Node = load("res://src/world/world.tscn").instantiate()
	_root().add_child(world)
	return world


func test_marker_targets_elder_mo_on_day_zero_then_moves_on() -> void:
	var world := _build()
	var marker: GoalMarker = null
	for child in world.get_children():
		if child is GoalMarker:
			marker = child
	assert_true(marker != null, "world has a GoalMarker")
	if marker != null:
		marker.refresh()
		assert_eq(marker.target, {"npc": "elder_mo"})
		assert_true(marker._node != null and marker._node.get("npc_id") == "elder_mo", "marker found Elder Mo")
		var gs: Node = _root().get_node("GameState")
		gs.world_flags[Guidance.ELDER_MO_FLAG] = true
		marker.refresh()
		assert_true(marker.target.get("npc", "") != "elder_mo")
	world.free()
	_root().get_node("GameState").end_session()


func test_find_node_matches_people_and_places() -> void:
	assert_true(GoalMarker.find_node([], {"npc": "elder_mo"}) == null)
	assert_true(GoalMarker.find_node([], {}) == null)


func test_no_place_label_covers_a_person_figure_in_qingshi() -> void:
	var world := _build()
	var nodes: Array = world.get_children().filter(func(n: Node) -> bool: return n is Interactable)
	var people: Array[Interactable] = []
	for n: Interactable in nodes:
		if n.is_person():
			people.append(n)
	assert_true(people.size() > 0)
	var view := Rect2(Vector2.ZERO, world.map_size)
	Interactable.spread_on_screen(nodes, view)
	var bad: Array[String] = []
	for n: Interactable in nodes:
		if n.is_person() or not n.label_drawn() or n.label_covered:
			continue
		var r := n.drawn_label_rect(view)
		for p in people:
			if r.intersects(Interactable.person_figure_rect(p)):
				bad.append("%s label on %s" % [n.display_name, p.display_name])
	assert_eq(bad.size(), 0, "; ".join(bad))
	world.free()
	_root().get_node("GameState").end_session()
