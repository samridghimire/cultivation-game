extends TestCase
## WU-419: the calendar modal: today focused and framed, market icons, next-month switch, closed signal, journal button.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _screen() -> Array:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var screen := CalendarScreen.new()
	root.add_child(screen)
	return [gs, screen]


func test_opens_with_today_focused() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var grid := screen.get("_grid") as GridContainer
	assert_eq(grid.get_child_count(), 30, "30 day cells")
	var today := Calendar.day_of(GameClock.total_days)
	assert_true(grid.get_child(today - 1).has_focus(), "today's cell is focused")
	assert_true((screen.get("_detail") as Label).text.contains("(today)"), "detail names today")
	screen.queue_free()
	await _frames()


func test_market_day_has_market_icon() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var grid := screen.get("_grid") as GridContainer
	var cell := grid.get_child(9) as Button  # day 10
	assert_true(cell.find_child("Icon_market", true, false) != null, "day 10 shows the market icon")
	assert_true(cell.get_meta("icons") <= 2, "at most two icons")
	cell.grab_focus()
	await _frames()
	assert_true((screen.get("_detail") as Label).text.contains("Market"), "focused day lists the market")
	screen.queue_free()
	await _frames()


func test_next_month_switch() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var title := (screen.get("_title") as Label).text
	screen.set_month_offset(1)
	await _frames()
	assert_true((screen.get("_title") as Label).text != title, "title changes")
	var grid := screen.get("_grid") as GridContainer
	assert_true((grid.get_child(9) as Button).find_child("Icon_market", true, false) != null, "next month's day 10 has a market too")
	assert_true(grid.get_child(0).has_focus(), "focus on day 1")
	screen.set_month_offset(5)
	assert_eq(screen.get("_offset"), 1, "only the next month")
	screen.queue_free()
	await _frames()


func test_close_emits_closed() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	var closed := [false]
	screen.closed.connect(func() -> void: closed[0] = true)
	screen.close()
	assert_true(closed[0], "closed emitted")
	screen.queue_free()
	await _frames()


func test_journal_button_and_key() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()
	var journal: Control = hud.get("_screens")["toggle_journal"]
	journal.open()
	await _frames()
	var button := journal.find_child("CalendarButton", true, false) as Button
	assert_true(button != null, "journal has the Calendar button")
	if button != null:
		button.pressed.emit()
	await _frames()
	var cal: Control = hud.get("_screens")["open_calendar"]
	assert_true(cal.visible, "calendar opens")
	assert_false(journal.visible, "journal closes")
	assert_true(InputMap.has_action("open_calendar"), "action exists")
	hud.queue_free()
	await _frames()
