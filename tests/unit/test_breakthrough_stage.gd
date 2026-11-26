extends TestCase
## GFX-258: the breakthrough stage picture and the animated Attempt.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _bottleneck() -> void:
	var c := new_character()
	c.realm_index = 1
	var realm: RealmDef = data().realms[1]
	c.stage = realm.stage_count() - 1
	c.qi = realm.qi_required(c.stage)
	c.heart_seen_realm = 1  # no heart vision pending
	_gs().start_session(c)
	_gs().current_region = "qingshi_village"
	_gs().pending_event = ""


func test_ghost_shows_with_vision_and_fades_once_faced() -> void:
	var stage := BreakthroughStage.new()
	stage.setup({}, 2, true)
	assert_true(stage.ghost_visible())
	stage.fade_vision()
	stage._process(1.0)
	assert_false(stage.ghost_visible())
	stage.free()


func test_attempt_finishes_after_its_duration_and_skip_ends_it() -> void:
	var stage := BreakthroughStage.new()
	stage.setup({}, 2, false)
	var fired := [0]
	stage.attempt_finished.connect(func() -> void: fired[0] += 1)
	stage.play_attempt(true)
	stage._process(0.5)
	assert_eq(fired[0], 0)
	stage._process(1.0)
	assert_eq(fired[0], 1)
	stage.play_attempt(false)
	stage.skip()
	assert_eq(fired[0], 2)
	assert_false(stage.is_playing())
	stage.free()


func test_motes_are_deterministic_and_inside_the_picture() -> void:
	for i in BreakthroughStage.MOTES:
		for ph: float in [0.0, 1.7, 9.3]:
			for pb: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]:
				var a := BreakthroughStage.mote_pos(i, ph, pb.x, pb.y)
				assert_eq(a, BreakthroughStage.mote_pos(i, ph, pb.x, pb.y))
				assert_true(Rect2(0, 0, BreakthroughStage.W, BreakthroughStage.H).has_point(a), "mote %d inside" % i)


func test_window_stays_until_the_beat_ends() -> void:
	_bottleneck()
	var host := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var screen := BreakthroughScreen.new()
	host.add_child(screen)
	screen.open()
	var fired := [0]
	screen.closed.connect(func() -> void: fired[0] += 1)
	screen._attempt_button.pressed.emit()
	if not screen._attempting:  # a pending heart vision asks "Push on?" first
		screen._attempt_button.pressed.emit()
	assert_true(screen._stage.is_playing(), "the beat plays")
	assert_true(screen.visible)
	assert_true(screen._attempt_button.disabled)
	screen._stage._process(2.0)
	assert_false(screen.visible)
	assert_eq(fired[0], 1)
	host.queue_free()


func test_closes_at_once_when_no_attempt_happens() -> void:
	var c := new_character()  # a fresh mortal cannot attempt
	_gs().start_session(c)
	var host := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var screen := BreakthroughScreen.new()
	host.add_child(screen)
	screen.open()
	screen._attempt_button.pressed.emit()
	assert_false(screen.visible)
	assert_false(screen._stage.is_playing())
	host.queue_free()
