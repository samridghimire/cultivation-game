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
	assert_eq(grid.get_children().filter(func(c: Node) -> bool: return c is Button).size(), 30, "30 day cells")
	var today := Calendar.day_of(GameClock.total_days)
	assert_true(grid.find_child("Day_%d" % today, false, false).has_focus(), "today's cell is focused")
	assert_true((screen.get("_detail") as Label).text.contains("(today)"), "detail names today")
	screen.queue_free()
	await _frames()


func test_market_day_has_market_icon() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var grid := screen.get("_grid") as GridContainer
	var cell := grid.find_child("Day_10", false, false) as Button
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
	assert_true((grid.find_child("Day_10", false, false) as Button).find_child("Icon_market", true, false) != null, "next month's day 10 has a market too")
	assert_true(grid.find_child("Day_1", false, false).has_focus(), "focus on day 1")
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


## WU-422: the legend lists every kind present; at most two 20 px icons per cell.
func test_legend_lists_present_kinds() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var legend := screen.get("_legend") as HBoxContainer
	var kinds: Array = []
	for item in legend.get_children():
		kinds.append(item.get_meta("kind"))
	assert_true(kinds.has("market"), "market in the legend")
	for cell in (screen.get("_grid") as GridContainer).get_children():
		if not cell is Button:
			continue
		assert_true(cell.get_meta("icons") <= CalendarScreen.MAX_ICONS, "<= 2 icons")
	screen.queue_free()
	await _frames()


func test_empty_day_shows_next_entries() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var entries: Dictionary = screen.get("_grid_entries")
	var today := Calendar.day_of(GameClock.total_days)
	var empty := -1
	for d in range(today, 30):
		if (entries.get(d, []) as Array).is_empty():
			empty = d
			break
	assert_true(empty > 0, "an empty day exists")
	screen.call("_show_day", empty)
	var text := (screen.get("_detail") as Label).text
	assert_true(text.contains("Next:") or text.contains("Nothing planned."), "empty day: " + text)
	assert_false(text.contains("Nothing planned.\n"), "no bare line")
	screen.queue_free()
	await _frames()


func test_all_kinds_have_icons() -> void:
	for kind: String in VillageCalendar.KIND_ORDER:
		assert_true(HudIcons.calendar_kind(kind, "Spring") != null, kind)


func test_key_strip_fits_1280() -> void:
	var ic: Node = _tree().root.get_node("InputConfig")
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.text = ic.key_bar_text(load("res://src/ui/hud.gd").KEY_HINTS)
	_tree().root.add_child(label)
	await _frames()
	assert_true(label.get_minimum_size().x <= 600.0, "key strip %d px fits its 600 px slot" % int(label.get_minimum_size().x))
	assert_true(label.text.contains("] cal"), "calendar listed")
	label.queue_free()


func test_cells_carry_great_beast_mark() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var grid := screen.get("_grid") as GridContainer
	var start := VillageCalendar.month_start(GameClock.total_days)
	for d in range(1, 31):
		var cell := grid.find_child("Day_%d" % d, false, false) as Button
		assert_false(cell.text.contains(Calendar.weekday_short(start + d - 1)), "day %d no longer prints a cut weekday" % d)
		var entries: Array = (screen.get("_grid_entries") as Dictionary).get(d, [])
		for e: Dictionary in entries:
			if String(e["kind"]) == "great_beast":
				assert_true(cell.find_child("Icon_great_beast", true, false) != null or int(cell.get_meta("icons")) >= 3, "paw mark on day %d" % d)
	screen.queue_free()
	await _frames()


func test_date_string_names_the_weekday() -> void:
	assert_eq(Calendar.format_date_weekday(1), "Year 1, Month 1, Day 2, Moonday")
	assert_true(GameClock.date_string().ends_with(Calendar.weekday_name(GameClock.total_days)), "HUD date ends with the weekday")


func test_mark_options_lists_that_days_labels() -> void:
	var entries: Array = [{"day": 12, "text": "Market"}, {"day": 12, "text": "Birthday"}, {"day": 12, "text": "Market"}, {"day": 13, "text": "Rent"}]
	assert_eq(CalendarScreen.mark_options(entries, 12), PackedStringArray(["Market", "Birthday"]), "that day's labels, no repeats")
	assert_eq(CalendarScreen.mark_options(entries, 14).size(), 0, "none for an empty day")


func test_mark_and_unmark_from_the_grid() -> void:
	var s := _screen()
	var gs: Node = s[0]
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var today := GameClock.total_days
	var grid := screen.get("_grid") as GridContainer
	# Find a future day with an entry.
	var d := 0
	for i in range(Calendar.day_of(today) + 1, 31):
		if not (screen.get("_grid_entries") as Dictionary).get(i, []).is_empty():
			d = i
			break
	assert_true(d > 0, "a future day has an entry")
	var total := VillageCalendar.month_start(today) + d - 1
	var cell := grid.find_child("Day_%d" % d, false, false) as Button
	cell.grab_focus()
	cell.pressed.emit()
	await _frames()
	var menu := screen.get("_menu") as ChoiceMenu
	assert_true(menu.visible, "accept opens the mark menu")
	var first: Button = null
	for b in menu.find_children("*", "Button", true, false):
		first = b
		break
	first.pressed.emit()
	await _frames()
	assert_true(gs.player.marked_days.has(total), "the day is marked")
	assert_true(not menu.visible, "menu closed")
	cell = grid.find_child("Day_%d" % d, false, false) as Button
	assert_true(cell.has_meta("marked"), "marked cell flagged")
	assert_true(cell.find_child("Seal", true, false) != null, "seal drawn")
	assert_true(cell.has_focus(), "focus returns to the cell")
	assert_true((screen.get("_detail") as Label).text.contains("Marked:"), "detail names the mark")
	# Unmark.
	cell.pressed.emit()
	await _frames()
	assert_true(menu.visible, "accept on a marked day offers Unmark")
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "Unmark":
			(b as Button).pressed.emit()
			break
	await _frames()
	assert_true(not gs.player.marked_days.has(total), "unmarked")
	screen.queue_free()
	await _frames()


func test_today_cannot_be_marked() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var grid := screen.get("_grid") as GridContainer
	(grid.find_child("Day_%d" % Calendar.day_of(GameClock.total_days), false, false) as Button).pressed.emit()
	await _frames()
	assert_true(not (screen.get("_menu") as ChoiceMenu).visible, "no menu for today")
	assert_true((screen.get("_detail") as Label).text.contains("future day"), "reason shown")
	screen.queue_free()
	await _frames()


## GFX-078: 7 columns, a weekday header, spacers before day 1 that cannot take focus.
func test_week_grid_has_spacers_and_header() -> void:
	var s := _screen()
	var screen: CalendarScreen = s[1]
	screen.open()
	await _frames()
	var grid := screen.get("_grid") as GridContainer
	assert_eq(grid.columns, 7)
	var header := screen.get("_header") as GridContainer
	assert_eq(header.get_child_count(), 7, "7 weekday labels")
	assert_eq((header.get_child(0) as Label).text, Calendar.weekday_label(0))
	var lead := CalendarScreen.lead_spacers(VillageCalendar.month_start(GameClock.total_days))
	for i in lead:
		assert_eq(grid.get_child(i).focus_mode, Control.FOCUS_NONE, "spacer %d not focusable" % i)
		assert_false(grid.get_child(i) is Button)
	assert_eq(grid.get_child(lead).name, &"Day_1", "day 1 follows the spacers")
	assert_eq(CalendarScreen.lead_spacers(3), 3)
	screen.queue_free()
	await _frames()


func test_next_summary_groups_same_labels() -> void:
	var entries: Array = [{"day": 10, "text": "Travelling Market Stall"}, {"day": 12, "text": "Mei's birthday"}, {"day": 25, "text": "Travelling Market Stall"}]
	assert_eq(CalendarScreen.next_summary(entries), "Next: Travelling Market Stall on days 10 and 25; Mei's birthday on day 12.")
	assert_eq(CalendarScreen.next_summary([]), "")


func test_hunt_has_its_own_glyph() -> void:
	assert_true(HudIcons.calendar_kind("hunt", "Spring") != HudIcons.calendar_kind("great_beast", "Spring"))
	assert_eq(CalendarScreen.short_label("market"), "Market")
