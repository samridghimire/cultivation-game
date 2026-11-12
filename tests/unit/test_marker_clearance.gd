extends TestCase
## WU-526: market marks stay inside their stall, the sect gate avoids landmarks and places, realm tags refresh on any stage change.


func test_market_mark_inside_stall_body() -> void:
	var merchant := load("res://src/world/interactables/merchant.gd")
	for sz: Vector2 in [Vector2(60, 50), Vector2(48, 40), Vector2(90, 70)]:
		var body := Rect2(-sz / 2.0, sz)
		var mark: Rect2 = merchant.market_mark_rect(sz)
		assert_true(body.encloses(mark), "mark %s inside body %s" % [mark, body])


func test_gate_clear_of_landmarks_and_places() -> void:
	var data: GameData = (Engine.get_main_loop() as SceneTree).root.get_node("GameState").data
	var rd: Dictionary = data.regions["azure_peak"]
	var g := SectCourt.gate(rd)
	assert_false(g.is_empty())
	var keeps: Array[Rect2] = Scenery.landmark_rects(rd)
	for place: Dictionary in rd.get("places", []):
		keeps.append(SectCourt.place_footprint(place))
	assert_true(SectCourt.gate_is_clear(g, keeps), "Azure Peak's gate covers nothing")


func test_realm_tags_refresh_on_stage_change() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male"))
	var world: Node = load("res://src/world/world.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	gs.player.stage += 1
	EventBus.player_changed.emit()
	assert_eq(world._tag_key, Vector2i(gs.player.realm_index, gs.player.stage))
	world.queue_free()
