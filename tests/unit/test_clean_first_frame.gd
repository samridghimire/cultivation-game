extends TestCase
## WU-522: NPC labels sit above their own figure, and far labels' realm tags follow the player's realm.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


## The 16x16 head rect of a figure standing at `node` (above the feet).
func _head(node: Interactable) -> Rect2:
	var feet := node.position.y + node.size.y / 2.0
	return Rect2(node.position.x - 8.0, feet - 28.0, 16.0, 16.0)


func test_no_person_label_sits_on_a_figures_head_in_qingshi() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var world: Node = load("res://src/world/world.tscn").instantiate()
	_root().add_child(world)
	var people: Array[Interactable] = []
	for child in world.get_children():
		if child is Interactable and child.is_person():
			people.append(child)
	assert_true(people.size() > 3)
	var bad: Array[String] = []
	for a in people:
		var rect := a.label_rect(a.label_text())
		for b in people:
			if rect.intersects(_head(b)) and a != b:
				continue  # another person's head: reported by the spread, not a layout rule here
			if a == b and rect.intersects(_head(b)):
				bad.append("%s label on its own head" % a.display_name)
		assert_true(a.label_offset.y <= 0.0, "%s label moved down (%s)" % [a.display_name, a.label_offset])
	assert_eq(bad.size(), 0, "; ".join(bad))
	world.queue_free()
	gs.end_session()


func test_realm_tags_refresh_when_the_player_advances() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var cult := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"age_years": 30, "region": gs.current_region})
	cult.realm_index = 2
	var world: Node = load("res://src/world/world.tscn").instantiate()
	_root().add_child(world)
	var node: Interactable = null
	for child in world.get_children():
		if child is Interactable and child.get("npc_id") == cult.id:
			node = child
	assert_true(node != null)
	assert_true(String(node.short_name).contains("·"), "stronger cultivator carries a tag: %s" % node.short_name)
	gs.player.realm_index = 3
	world._on_player_realm_changed(true, "")
	assert_false(String(node.short_name).contains("·"), "weaker now: %s" % node.short_name)
	world.queue_free()
	gs.end_session()
