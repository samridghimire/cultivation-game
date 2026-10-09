extends TestCase
## WU-091: with every HUD line on at once (goal, hunt, festival, injuries, secret realm, 3 hints,
## key bar) the status panel must stay inside the window and clear of the log and prompt.

const DECK := Vector2(1280, 800)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 4) -> void:
	for i in n:
		await _tree().process_frame


func test_status_panel_clear_of_log_and_prompt() -> void:
	await _check(1.0)


func test_status_panel_clear_of_log_and_prompt_at_115_percent() -> void:
	await _check(1.15)


func _check(scale: float) -> void:
	var root := _tree().root
	var old_size := root.size
	root.size = Vector2i(DECK)
	Settings.set_value("ui_scale", scale)
	Settings.set_value("hud_hints", 3)
	var gs: Node = root.get_node("GameState")
	var c := CharacterFactory.create("Lin Feng Of The Long Name", gs.data, seeded_rng(5), "male")
	gs.start_session(c)
	gs.pending_event = ""
	for injury_id: String in gs.data.injuries:
		Injuries.inflict(c, gs.data, injury_id)
	gs.join_sect("azure_cloud_sect")
	var offers := Bounties.offers(c, gs.data, GameClock.total_days)
	if not offers.is_empty():
		Bounties.take(c, gs.data, String(offers[0]["id"]), GameClock.total_days)
	for event_id: String in gs.data.world_events:
		if WorldEvents.is_festival(gs.data, event_id):
			gs.world_events.append({"id": event_id, "region": gs.current_region, "start_day": 0, "end_day": 99999, "done": false})
			break
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	for i in 30:
		EventBus.post("Message %d: a long line of news that wraps across the log so it takes room." % i)
	await _frames()
	var view := Rect2(Vector2.ZERO, DECK / scale)
	var status: Control = hud.get("_status_panel")
	var log_panel: Control = hud.get("_log_panel")
	var prompt: Control = hud.get("_prompt")
	var rect := status.get_global_rect()
	assert_true(view.encloses(rect), "status panel inside the window: %s" % rect)
	assert_false(rect.intersects(log_panel.get_global_rect()), "status panel %s overlaps the log %s" % [rect, log_panel.get_global_rect()])
	hud.set("_target_name", "Elder Mo")
	hud.call("_refresh_key_hints")
	await _frames()
	assert_false(rect.intersects(prompt.get_global_rect()), "status panel %s overlaps the prompt %s" % [rect, prompt.get_global_rect()])
	hud.queue_free()
	Settings.set_value("ui_scale", 1.0)
	root.size = old_size
