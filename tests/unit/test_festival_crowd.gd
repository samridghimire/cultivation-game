extends TestCase
## WU-457: villagers gather round the festival stall until you enter its contest.


func _npc_count_near(world: Node, centre: Vector2, radius: float) -> int:
	var n := 0
	for child in world.get_children():
		if child is Interactable and child.get("npc_id") != null and child.position.distance_to(centre) < radius + 40.0:
			n += 1
	return n


func test_caption_text() -> void:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	assert_eq(FestivalContest.crowd_caption(gs.data, "lantern_festival", true), "%s today" % FestivalContest.contest_of(gs.data, "lantern_festival")["name"])
	assert_eq(FestivalContest.crowd_caption(gs.data, "lantern_festival", false), "")
	assert_eq(FestivalContest.crowd_caption(gs.data, "", true), "")


func test_crowd_ring_is_capped_and_clear() -> void:
	var centre := Vector2(500, 400)
	var none: Array[Vector2] = []
	assert_eq(FestivalContest.crowd_positions(centre, 0, none).size(), 0)
	assert_eq(FestivalContest.crowd_positions(centre, 9, none).size(), FestivalContest.CROWD_MAX)
	var avoid: Array[Vector2] = [centre + Vector2(0, FestivalContest.CROWD_RADIUS)]
	var spots := FestivalContest.crowd_positions(centre, 4, avoid)
	assert_eq(spots.size(), 4)
	for i in spots.size():
		assert_true(spots[i].distance_to(avoid[0]) >= FestivalContest.CROWD_CLEAR)
		for j in range(i + 1, spots.size()):
			assert_true(spots[i].distance_to(spots[j]) >= 36.0)


func test_crowd_gathers_then_goes_home() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": 0, "end_day": 99999, "done": false}]
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	var stall: FestivalStall = null
	for child in world.get_children():
		if child is FestivalStall:
			stall = child
			break
	assert_true(stall != null)
	assert_true(stall.caption.ends_with(" today"))
	var before: int = _npc_count_near(world, stall.position + Vector2(0, 20), FestivalContest.CROWD_RADIUS + 36.0)
	var villagers := Npcs.in_region(gs.npcs, gs.data, "qingshi_village").size()
	assert_true(villagers == 0 or before > 0, "villagers stand round the stall")
	gs.festival_contest("lantern_festival")
	await (Engine.get_main_loop() as SceneTree).process_frame
	for child in world.get_children():
		if child is FestivalStall:
			assert_eq(child.caption, "")
	world.free()
	gs.end_session()
