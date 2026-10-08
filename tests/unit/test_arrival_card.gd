extends TestCase
## WU-003: arrival banner on travel, not on session start/load.

func test_arrival_banner_on_region_change_only() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var bus := root.get_node("EventBus")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	var banner: Banner = hud.get("_banner")
	bus.session_started.emit()
	assert_false(banner.visible, "no banner at session start/load")
	var dest: String = String(gs.data.regions[gs.current_region]["routes"][0]["to"])
	bus.region_changed.emit(dest)
	assert_true(banner.visible)
	assert_eq(banner.title_text(), Exploration.region_name(gs.data, dest))
	assert_true(banner.subtitle_text().begins_with("Qi x"))
	assert_true(banner.subtitle_text().contains("Danger: "))
	banner.visible = false
	gs.pending_respawn = {"cause": "test", "anchor_id": "x", "lives_left": 1, "qi_lost": 0}
	bus.region_changed.emit(dest)
	assert_false(banner.visible, "no arrival card while the respawn screen is up")
	gs.pending_respawn = {}
	bus.region_changed.emit(dest)
	assert_true(banner.visible, "card shows once the respawn is chosen")
	hud.free()
	gs.end_session()
