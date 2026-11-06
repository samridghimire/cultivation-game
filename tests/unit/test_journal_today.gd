extends TestCase
## WU-458: the journal's Today page: icon keywords, rows from a fixed list, the quiet-day line, focus on open.


func test_today_icon_maps_each_kind() -> void:
	assert_eq(HudIcons.today_icon("The Lantern Festival is on in Qingshi"), "lantern")
	assert_eq(HudIcons.today_icon("Fresh tracks in the forest"), "paw")
	assert_eq(HudIcons.today_icon("Market day today at the stall."), "coin")
	assert_eq(HudIcons.today_icon("Qingshi: rain-fish biting."), "fish")
	assert_eq(HudIcons.today_icon("Qingshi: herb bloom."), "leaf")
	assert_eq(HudIcons.today_icon("Today: Mei's marked day"), "calendar")
	assert_eq(HudIcons.today_icon("Winter ends soon"), "snow")
	assert_eq(HudIcons.today_icon("Something else"), "dot")
	for k in ["lantern", "paw", "coin", "fish", "leaf", "calendar", "snow", "dot"]:
		assert_true(HudIcons.today_glyph(k) != null, k)


func _screen() -> JournalScreen:
	var root: Node = Engine.get_main_loop().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	var s := JournalScreen.new()
	root.add_child(s)
	return s


func _rows(s: JournalScreen) -> int:
	return s._today.find_children("*", "HBoxContainer", true, false).filter(func(n: Node) -> bool: return n.has_meta("today_row")).size()


func test_rows_and_empty_line() -> void:
	var s := _screen()
	s._build_today(PackedStringArray(["Market day today at X.", "Fresh tracks in Y."]))
	assert_eq(_rows(s), 2)
	assert_true(s._today.find_child("TodayQuiet", true, false) == null)
	s._build_today(PackedStringArray())
	assert_eq(_rows(s), 0)
	assert_true(s._today.find_child("TodayQuiet", true, false) != null)
	s.queue_free()


func test_opens_on_today_with_focus_and_switches() -> void:
	var s := _screen()
	s.open()
	await Engine.get_main_loop().process_frame
	assert_true(s._today.visible)
	assert_false(s._cards.visible)
	assert_true(s.get_viewport().gui_get_focus_owner() == s._tabs.get_node("Tab_today"))
	s.set_page("journal")
	assert_true(s._cards.visible)
	s.queue_free()
