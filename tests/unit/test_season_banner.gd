extends TestCase
## WU-062: the turn of the seasons shows one low-priority banner.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _hud() -> CanvasLayer:
	var c := new_character(779)
	_root().get_node("GameState").start_session(c)
	_root().get_node("GameClock").total_days = 0
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	_root().add_child(hud)
	(hud.get("_banner") as Banner).finish_current()
	return hud


func _frame() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame


func test_crossing_a_boundary_queues_one_banner() -> void:
	var hud := _hud()
	var clock: Node = _root().get_node("GameClock")
	var banner: Banner = hud.get("_banner")
	clock.advance(10)
	await _frame()
	assert_false(banner.visible)
	clock.advance(Calendar.DAYS_PER_YEAR / 4)
	await _frame()
	assert_true(banner.visible)
	assert_eq(banner.title_text(), "Summer arrives")
	assert_eq(banner.queued_count(), 0)
	hud.free()
	_root().get_node("GameState").end_session()
	clock.reset()


func test_long_seclusion_shows_one_banner() -> void:
	var hud := _hud()
	var clock: Node = _root().get_node("GameClock")
	var banner: Banner = hud.get("_banner")
	clock.advance(300)
	await _frame()
	assert_true(banner.visible)
	assert_eq(banner.queued_count(), 0)
	hud.free()
	_root().get_node("GameState").end_session()
	clock.reset()


func test_low_banner_never_waits_behind_another() -> void:
	var b := Banner.new()
	b.announce("Breakthrough!", "x", Color.WHITE)
	b.announce("Summer arrives", "y", Color.WHITE, 1.0, true)
	assert_eq(b.queued_count(), 0)
	assert_eq(b.title_text(), "Breakthrough!")
	b.free()


func test_days_left_in_season() -> void:
	assert_eq(Calendar.days_left_in_season(0), 89)
	assert_eq(Calendar.days_left_in_season(89), 0)
	assert_eq(Calendar.days_left_in_season(90), 89)
	assert_eq(Calendar.days_left_in_season(Calendar.DAYS_PER_YEAR - 1), 0)


func test_date_line_near_season_end_only() -> void:
	var hud_script: GDScript = load("res://src/ui/hud.gd")
	assert_eq(hud_script.season_label(40), "Spring")
	assert_eq(hud_script.season_label(79), "Spring (10 days left)")
	assert_eq(hud_script.season_label(88), "Spring (1 day left)")
	assert_eq(hud_script.season_label(89), "Spring (0 days left)")


func test_banner_subtitle_with_and_without_highlights() -> void:
	var hud_script: GDScript = load("res://src/ui/hud.gd")
	var none: Array[Dictionary] = []
	assert_eq(hud_script.season_banner_subtitle("Qingshi Village", none), "in Qingshi Village.")
	var hl: Array[Dictionary] = [
		{"item_name": "Spirit Herb", "place": "Village Herb Slope"},
		{"item_name": "Frost Lotus", "place": "Ice Pond"},
		{"item_name": "Third", "place": "Nowhere"},
	]
	assert_eq(hud_script.season_banner_subtitle("Qingshi Village", hl),
		"in Qingshi Village. In season: Spirit Herb at Village Herb Slope; Frost Lotus at Ice Pond.")
