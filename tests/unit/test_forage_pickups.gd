extends TestCase
## WU-427: the world draws today's forage as pickup nodes and picks them without a menu.


func _world(region: String) -> Node:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = region
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	return world


func _pickups(world: Node) -> Array:
	var out := []
	for c in world.get_children():
		if c is ForagePickup and not c.is_queued_for_deletion():
			out.append(c)
	return out


func test_spawns_as_many_as_forage_here() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("qingshi_village")
	var n: int = gs.forage_here().size()
	assert_true(n >= 2)
	assert_eq(_pickups(world).size(), n)
	var first: ForagePickup = _pickups(world)[0]
	assert_true(first.display_name.begins_with("Pick "), first.display_name)
	world.free()
	gs.end_session()


func test_interacting_picks_and_removes() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var world := _world("qingshi_village")
	var before: int = gs.forage_here().size()
	var node: ForagePickup = _pickups(world)[0]
	var have: int = gs.player.item_count(node.item_id)
	assert_true(node.use_directly())
	assert_true(gs.player.item_count(node.item_id) > have)
	assert_eq(gs.forage_here().size(), before - 1)
	assert_eq(_pickups(world).filter(func(p: ForagePickup) -> bool: return not p.taken).size(), before - 1)
	world.free()
	gs.end_session()


func test_spots_keep_their_distance() -> void:
	var blocked: Array[Rect2] = [Rect2(100, 100, 300, 300)]
	var paths: Array[Rect2] = [Rect2(0, 500, 1600, 60)]
	var trees: Array[Vector2] = [Vector2(800, 300)]
	var avoid: Array[Vector2] = [Vector2(700, 700)]
	var spots := ForagePickup.pick_spots("r", 4, 6, Vector2(1600, 1000), blocked, paths, trees, avoid)
	assert_eq(spots.size(), 6)
	for i in spots.size():
		assert_false(blocked[0].has_point(spots[i]))
		assert_true(absf(spots[i].y - 530.0) >= 16.0 or spots[i].x < 0.0, "off the path centre")
		for j in range(i + 1, spots.size()):
			assert_true(spots[i].distance_to(spots[j]) >= ForagePickup.MIN_GAP)
	assert_eq(spots, ForagePickup.pick_spots("r", 4, 6, Vector2(1600, 1000), blocked, paths, trees, avoid))


func test_sprite_kinds_by_tag() -> void:
	assert_eq(ForagePickup.sprite_kind(["herb"]), "herb")
	assert_eq(ForagePickup.sprite_kind(["ore"]), "ore")
	assert_eq(ForagePickup.sprite_kind(["fish"]), "sack")
	assert_true(ForagePickup.texture_for("herb") != null)
