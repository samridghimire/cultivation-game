extends TestCase
## GFX-036: fallen beasts lie on the ground, the backdrop varies per region, forced weather sticks.


func test_fallen_beast_lies_flat_on_the_ground() -> void:
	var r := DuelStage.fallen_rect(Vector2(96, 60), Vector2(100, 150), true)
	assert_true(absf(r.end.y - 150.0) <= 2.0)
	assert_true(r.size.y <= 62.0)


func test_fallen_person_rests_on_the_ground() -> void:
	var r := DuelStage.fallen_rect(Vector2(28, 72), Vector2(100, 150), false)
	assert_true(absf(r.end.y - 150.0) <= 2.0)
	assert_true(r.size.y <= 30.0)


func test_silhouettes_vary_by_region_but_are_stable() -> void:
	var a := DuelStage.silhouette_shapes("qingshi_village", "roofs", 620.0)
	var b := DuelStage.silhouette_shapes("qingshi_village", "roofs", 620.0)
	var c := DuelStage.silhouette_shapes("fallen_star_market", "roofs", 620.0)
	assert_eq(a, b)
	assert_true(a != c)
	assert_true(a.size() >= 3)


func test_force_weather_survives_clock_advance() -> void:
	var world: Node = load("res://src/world/world.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	world.call("force_weather", "storm")
	GameClock.advance(1)
	assert_eq(world.get("_weather_kind"), "storm")
	world.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
