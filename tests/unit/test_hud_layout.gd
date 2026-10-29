extends TestCase
## GFX-010: the HUD cards (status top-left, "Next steps" top-right, key strip, log) leave the world visible.

const DECK := Vector2(1280, 800)
const HudScript := preload("res://src/ui/hud.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _build() -> CanvasLayer:
	var root := _tree().root
	root.size = Vector2i(DECK)
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Lin", gs.data, seeded_rng(5), "male"))
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	for i in 4:
		await _tree().process_frame
	return hud


func _done(hud: CanvasLayer) -> void:
	hud.queue_free()
	var gs: Node = _tree().root.get_node("GameState")
	gs.end_session()


func test_cards_do_not_overlap_and_cover_little() -> void:
	var hud := await _build()
	hud.set("_target_name", "Elder Mo")
	hud.call("_refresh_key_hints")
	await _tree().process_frame
	var rects: Dictionary = {}
	for name: String in ["_status_panel", "_guide_panel", "_log_panel", "_key_bar", "_prompt"]:
		var c: Control = hud.get(name)
		assert_true(c.visible, name + " visible")
		rects[name] = c.get_global_rect()
	var names := rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			assert_false((rects[names[i]] as Rect2).intersects(rects[names[j]]), "%s %s overlaps %s %s" % [names[i], rects[names[i]], names[j], rects[names[j]]])
	var limit := DECK.y - HudScript.LOG_HEIGHT - HudScript.STATUS_MARGIN
	assert_true((rects["_status_panel"] as Rect2).end.y <= limit, "status card above the log")
	assert_true((rects["_guide_panel"] as Rect2).end.y <= limit, "guide card above the log")
	var area: float = 0.0
	for name: String in ["_status_panel", "_guide_panel", "_log_panel"]:
		area += (rects[name] as Rect2).get_area()
	assert_true(area < 0.18 * DECK.x * DECK.y, "cards cover %.1f%% %s" % [100.0 * area / (DECK.x * DECK.y), rects])
	_done(hud)


func test_lines_moved_into_their_rows() -> void:
	var hud := await _build()
	assert_false((hud.get("_status") as Label).text.contains("Qi: "))
	assert_true((hud.get("_qi_text") as Label).text.begins_with("Qi: "))
	assert_true((hud.get("_currency") as Label).text != "")
	var hints: PackedStringArray = hud.get("_hint_lines")
	if not hints.is_empty():
		assert_true((hud.get("_hint") as Label).text.contains(HudScript.cap_hint(hints[0])))
	_done(hud)


func test_key_help_setting() -> void:
	var old: Variant = Settings.get_value("key_help")
	var hud := await _build()
	Settings.set_value("key_help", false)
	assert_false((hud.get("_key_bar") as Label).visible)
	Settings.set_value("key_help", true)
	assert_true((hud.get("_key_bar") as Label).visible)
	assert_eq(Settings.sanitize("key_help", "yes"), true, "non-bool falls back to the default")
	Settings.set_value("key_help", old)
	_done(hud)


func test_hunt_line_shows_with_hints_off() -> void:
	var old: Variant = Settings.get_value("hud_hints")
	var hud := await _build()
	var gs: Node = _tree().root.get_node("GameState")
	var bounty_id: String = gs.data.bounties.keys()[0]
	gs.player.bounty = {"id": bounty_id, "until_day": GameClock.total_days + 10}
	Settings.set_value("hud_hints", 0)
	hud.call("_refresh")
	hud.call("_refresh_fair_fight")
	hud.call("_fit_panels")
	assert_true((hud.get("_hunt") as Label).visible, "hunt line")
	assert_true((hud.get("_guide_panel") as Control).visible, "the hunt deadline stays on screen with hints off")
	gs.player.bounty = {}
	hud.call("_refresh")
	hud.call("_refresh_fair_fight")
	hud.call("_fit_panels")
	assert_false((hud.get("_guide_panel") as Control).visible, "nothing to show with hints off")
	Settings.set_value("hud_hints", old)
	_done(hud)


func test_log_idle_alpha() -> void:
	assert_eq(HudScript.log_idle_alpha(0.0), 1.0)
	assert_true(HudScript.log_idle_alpha(9.0) <= 0.55)
