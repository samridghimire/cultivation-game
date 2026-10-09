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


func test_load_recap_shows_on_card_once() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	assert_true(gs.load_recap.is_empty(), "a new session has no recap")
	var d: Dictionary = gs.to_save_dict()
	gs.load_save_dict(d)
	assert_false(gs.load_recap.is_empty(), "loading builds the recap")
	var first: String = gs.load_recap[0]
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	var banner: Banner = hud.get("_banner")
	assert_true(banner.visible, "recap card shows on boot after a load")
	assert_eq(banner.title_text(), first)
	assert_true(gs.load_recap.is_empty(), "consumed so it shows once")
	hud.free()
	var hud2: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud2)
	assert_false((hud2.get("_banner") as Banner).visible, "no card on a later boot")
	hud2.free()
	gs.pending_respawn = {"cause": "test", "anchor_id": "x", "lives_left": 1, "qi_lost": 0}
	gs.load_save_dict(d)
	gs.pending_respawn = {"cause": "test", "anchor_id": "x", "lives_left": 1, "qi_lost": 0}
	var hud3: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud3)
	assert_false((hud3.get("_banner") as Banner).visible, "not over the respawn screen")
	hud3.free()
	gs.end_session()


## WU-031: the year review shows as a banner card, honours the setting and waits for the respawn screen.
func test_year_review_banner_and_setting() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := root.get_node("GameState")
	var bus := root.get_node("EventBus")
	var settings := root.get_node("Settings")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(4)))
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	var banner: Banner = hud.get("_banner")
	var lines := PackedStringArray(["You did 2 deeds.", "You grew a stage."])
	bus.year_reviewed.emit(3, lines, 0)
	hud.call("_flush_year_review")
	assert_true(banner.visible)
	assert_eq(banner.title_text(), "Year 2 of your journey")
	assert_true(banner.subtitle_text().contains("You did 2 deeds."))
	banner.visible = false
	gs.pending_respawn = {"cause": "test", "anchor_id": "x", "lives_left": 1, "qi_lost": 0}
	bus.year_reviewed.emit(4, lines, 0)
	hud.call("_flush_year_review")
	assert_false(banner.visible, "held back while the respawn screen is up")
	gs.pending_respawn = {}
	hud.call("_flush_year_review")
	assert_true(banner.visible, "shows once the screen is free")
	banner.visible = false
	var old: Variant = settings.get_value("yearly_recap")
	settings.set_value("yearly_recap", false)
	bus.year_reviewed.emit(5, lines, 0)
	hud.call("_flush_year_review")
	assert_false(banner.visible, "nothing with the setting off")
	settings.set_value("yearly_recap", old)
	hud.free()
	gs.end_session()
