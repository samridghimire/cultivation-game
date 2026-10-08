extends TestCase
## WU-042: new-feature notices show a "New" banner besides the log line.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _hud() -> CanvasLayer:
	var c := new_character(778)
	c.realm_index = 1
	_root().get_node("GameState").start_session(c)
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	return hud


func test_notice_emits_one_banner() -> void:
	var hud := _hud()
	var gs: Node = _root().get_node("GameState")
	var settings: Node = _root().get_node("Settings")
	var old: Variant = settings.get_value("hud_hints")
	settings.set_value("hud_hints", 2)
	var banner: Banner = hud.get("_banner")
	banner.finish_current()
	gs.world_flags.erase("notice_body_tempering")
	gs.check_unlock_notices()
	assert_true(banner.visible)
	assert_eq(banner.title_text(), "New")
	assert_true(banner.subtitle_text().contains("temper your body"))
	assert_eq(banner.queued_count(), 0)
	settings.set_value("hud_hints", old)
	hud.free()
	gs.end_session()


func test_two_notices_queue_two() -> void:
	var hud := _hud()
	var gs: Node = _root().get_node("GameState")
	var settings: Node = _root().get_node("Settings")
	var old: Variant = settings.get_value("hud_hints")
	settings.set_value("hud_hints", 1)
	var banner: Banner = hud.get("_banner")
	banner.finish_current()
	var bus: Node = _root().get_node("EventBus")
	bus.feature_unlocked.emit("First thing.")
	bus.feature_unlocked.emit("Second thing.")
	assert_eq(banner.subtitle_text(), "First thing.")
	assert_eq(banner.queued_count(), 1)
	settings.set_value("hud_hints", old)
	hud.free()
	gs.end_session()


func test_no_banner_with_hints_off() -> void:
	var hud := _hud()
	var gs: Node = _root().get_node("GameState")
	var settings: Node = _root().get_node("Settings")
	var old: Variant = settings.get_value("hud_hints")
	settings.set_value("hud_hints", 0)
	var banner: Banner = hud.get("_banner")
	banner.finish_current()
	gs.world_flags.erase("notice_body_tempering")
	var before := EventBus.posted_count
	gs.check_unlock_notices()
	assert_gt(EventBus.posted_count, before, "the log line still posts")
	assert_false(banner.visible)
	settings.set_value("hud_hints", old)
	hud.free()
	gs.end_session()
