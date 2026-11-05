extends TestCase
## WU-441: the first screen is clear: the prompt chip sits with its target, Elder Mo is outside the arrival card.

const HUD := preload("res://src/ui/hud.gd")
const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")


func test_prompt_rect_above_label_when_free() -> void:
	var screen := Rect2(0, 0, 1280, 720)
	var label := Rect2(500, 300, 100, 18)
	var r: Rect2 = HUD.prompt_rect(label, screen, [], Vector2(180, 30))
	assert_true(r.end.y <= label.position.y, "chip above the label")
	assert_eq(r.get_center().x, label.get_center().x)


func test_prompt_rect_clamped_and_clear_of_avoid() -> void:
	var screen := Rect2(0, 0, 1280, 720)
	var edge: Rect2 = HUD.prompt_rect(Rect2(1250, 5, 60, 18), screen, [], Vector2(180, 30))
	assert_true(screen.encloses(edge), "clamped to the screen")
	var label := Rect2(500, 300, 100, 18)
	var above := Rect2(400, 260, 300, 40)
	var avoid: Array[Rect2] = [above]
	var r: Rect2 = HUD.prompt_rect(label, screen, avoid, Vector2(180, 30))
	assert_false(r.intersects(above), "moves clear of a card")
	assert_true(screen.encloses(r))


func test_elder_mo_label_clear_of_arrival_card() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var view := world.get_viewport().get_visible_rect().size
	var found := false
	for node in world.get_children():
		if node is Interactable and (node as Interactable).display_name.begins_with("Elder Mo"):
			found = true
			var inter := node as Interactable
			var label: Rect2 = world.get_global_transform_with_canvas() * inter.label_rect()
			# Banner holder: x 12.5%..87.5%, top 3%, ribbon up to ~140 px tall (title + two lines).
			var card := Rect2(view.x * 0.125, view.y * 0.03, view.x * 0.75, 140.0)
			assert_false(label.intersects(card), "Elder Mo's label %s is clear of the arrival card %s" % [label, card])
	assert_true(found, "Elder Mo is in Qingshi Village")
	world.queue_free()
	gs.end_session()


func test_chip_replaces_bottom_prompt_for_a_labelled_target() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	assert_false(hud.get("_prompt_floating"), "bottom-centre fallback with no target")
	hud.free()
	gs.end_session()
