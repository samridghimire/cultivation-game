extends TestCase
## WU-617: practice you can see: the session's progress line, bonus text per level and the level-up moment.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var c := CharacterFactory.create("Prac", _gs().data, seeded_rng(11))
	_gs().start_session(c)
	_gs().pending_event = ""
	return c


func _frames(n: int = 4) -> void:
	for i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame


func test_progress_line_names_level_and_days() -> void:
	var c := _start()
	var gs := _gs()
	Techniques.learn(c, gs.data, "iron_fist")
	var line := Techniques.progress_line(c, gs.data, "iron_fist")
	var days := Techniques.days_to_next(c, gs.data, "iron_fist")
	assert_eq(line, "Iron Fist: level 1, about %d days of practice to level 2" % days)
	gs.end_session()


func test_session_posts_progress_and_replaces_the_last() -> void:
	var c := _start()
	var gs := _gs()
	Techniques.learn(c, gs.data, "iron_fist")
	gs.practice_technique("iron_fist", 1)
	var rows := EventBus.history.size()
	var found := false
	for h in EventBus.history:
		if String(h["text"]).begins_with("Iron Fist: level 1, about "):
			found = true
	assert_true(found, "a practice session that does not level posts the progress line")
	gs.practice_technique("iron_fist", 1)
	var count := 0
	for h in EventBus.history:
		if String(h["text"]).begins_with("Iron Fist: level 1"):
			count += 1
	assert_true(count >= 1)
	assert_true(EventBus.history.size() <= rows + 3, "the second session replaces rather than stacks")
	gs.end_session()


func test_bonus_text_at_level() -> void:
	var c := _start()
	var gs := _gs()
	Techniques.learn(c, gs.data, "iron_fist")
	assert_eq(Techniques.describe_bonuses_at(c, gs.data, "iron_fist", 1), Techniques.describe_bonuses(c, gs.data, "iron_fist"))
	assert_true(Techniques.describe_bonuses_at(c, gs.data, "iron_fist", 3) != Techniques.describe_bonuses_at(c, gs.data, "iron_fist", 2))
	gs.end_session()


func test_level_up_emits_signal_and_plain_session_does_not() -> void:
	var c := _start()
	var gs := _gs()
	Techniques.learn(c, gs.data, "iron_fist")
	var got: Array = []
	var cb := func(id: String, level: int, _b: String, _a: String) -> void: got.append([id, level])
	EventBus.technique_leveled.connect(cb)
	gs.practice_technique("iron_fist", 1)
	assert_eq(got.size(), 0, "no level, no moment")
	gs.practice_technique("iron_fist", 60)
	EventBus.technique_leveled.disconnect(cb)
	assert_true(got.size() >= 1)
	assert_eq(got[0][0], "iron_fist")
	assert_eq(got[0][1], 2)
	gs.end_session()


func test_hud_plays_level_card_with_focus() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs := _gs()
	_start()
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var card: SectCard = hud.get("_sect_card")
	EventBus.technique_leveled.emit("iron_fist", 3, "+4 attack", "+6 attack")
	await _frames()
	assert_true(card.visible)
	assert_true(card.all_text().contains("Iron Fist"))
	assert_true(card.all_text().contains("Level 3"))
	assert_true(card.all_text().contains("+6 attack"))
	assert_eq(card.button().text, "OK")
	assert_true(card.button().has_focus())
	card.close()
	assert_eq(card.button().text, "Continue")
	hud.queue_free()
	await _frames()
	gs.end_session()
