extends TestCase
## WU-097: festival stalls beside merchants while a festival runs in the region.


func _count_stalls(world: Node) -> int:
	var n := 0
	for child in world.get_children():
		if child is FestivalStall:
			n += 1
	return n


func test_stall_decor_by_festival() -> void:
	assert_eq(FestivalStall.decor_for("qingming_festival"), "willow")
	assert_eq(FestivalStall.decor_for("lantern_festival"), "lanterns")
	assert_eq(FestivalStall.decor_for("mystery_festival"), "lanterns")


func test_stalls_follow_active_festival() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	gs.current_region = "qingshi_village"
	gs.world_events = []
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	assert_eq(_count_stalls(world), 0)
	gs.world_events = [{"id": "lantern_festival", "region": "qingshi_village", "start_day": 0, "end_day": 99999, "done": false}]
	world._on_days_advanced(1)
	var merchants := 0
	for place: Dictionary in gs.data.regions["qingshi_village"]["places"]:
		if place["type"] == "merchant":
			merchants += 1
	assert_true(merchants > 0)
	assert_eq(_count_stalls(world), merchants)
	gs.world_events = [{"id": "lantern_festival", "region": "elsewhere", "start_day": 0, "end_day": 99999, "done": false}]
	world._on_days_advanced(1)
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_eq(_count_stalls(world), 0)
	world.free()
	gs.end_session()
