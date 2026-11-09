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


## GFX-107: the layered backdrop is deterministic per region and keeps props off the fighters' feet.
func test_backdrop_layers_gfx107() -> void:
	for rid in ["qingshi_village", "misty_forest", "withered_bone_marsh", "azure_peak", "fallen_star_market", "other"]:
		var a := DuelStage.backdrop_layers(rid, 620.0)
		var b := DuelStage.backdrop_layers(rid, 620.0)
		assert_eq(a, b, "deterministic " + rid)
		assert_true(a["props"].size() >= 2 and a["props"].size() <= 4, "2-4 props " + rid)
		assert_true(a["far"].size() > 0 and a["near"].size() > 0, "layers " + rid)
		for p in a["props"]:
			var f: float = float(p["x"]) / 620.0
			assert_true(not (f >= 0.15 and f <= 0.30) and not (f >= 0.70 and f <= 0.85), "prop clear of feet " + rid)
