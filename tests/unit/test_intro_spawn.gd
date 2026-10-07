extends TestCase
## FH-011: a new game starts beside Meditation Rock; loading a save does not move the player.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _rock(world: Node) -> Node2D:
	for child in world.get_children():
		if child is Interactable and child.anchor_id == "qingshi_rock":
			return child
	return null


func test_new_session_spawns_next_to_meditation_rock() -> void:
	var gs := _gs()
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var world: Node = load("res://src/world/world.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	var rock := _rock(world)
	assert_true(rock != null)
	assert_true(world.player.position.distance_to(rock.position) < 120.0, "player starts by the rock")
	assert_gt(world.player.position.distance_to(rock.position), 40.0, "but not on top of it")
	assert_eq(gs.spawn_anchor, "", "the anchor is consumed")
	world.free()
	gs.end_session()


func test_loaded_save_keeps_default_spawn() -> void:
	var gs := _gs()
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var saved: Dictionary = gs.to_save_dict()
	gs.spawn_anchor = ""
	gs.load_save_dict(saved)
	assert_eq(gs.spawn_anchor, "", "loads do not reposition the player")
	gs.end_session()


func test_wake_text_mentions_elder_mo() -> void:
	var text := FileAccess.get_file_as_string("res://data/dialogue/artifact_awakening.json")
	assert_true(text.contains("Elder Mo"))
