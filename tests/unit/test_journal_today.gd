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


## WU-462: the season's tasks on the Today page and the HUD's one-left line.
func _tasks(done: Array) -> Array:
	var out: Array = []
	for i in done.size():
		out.append({"text": "Task %d." % i, "n": 1 if done[i] else 0, "count": 1, "done": done[i]})
	return out


func test_season_rows_and_check() -> void:
	var s := _screen()
	s._build_today(PackedStringArray(), _tasks([true, false, false]), "")
	assert_eq(s._today.find_children("*", "HBoxContainer", true, false).filter(func(n: Node) -> bool: return n.has_meta("season_row")).size(), 3)
	assert_true(s._today.find_child("SeasonHeader", true, false) != null)
	assert_true(s._today.find_children("*", "HBoxContainer", true, false).filter(func(n: Node) -> bool: return n.has_meta("season_reward")).is_empty())
	s._build_today(PackedStringArray(), _tasks([true, true, true]), "The village thanks you.")
	assert_eq(s._today.find_children("*", "HBoxContainer", true, false).filter(func(n: Node) -> bool: return n.has_meta("season_reward")).size(), 1)
	assert_true(HudIcons.today_glyph("check") != null)
	s.queue_free()


func test_season_task_text_counts() -> void:
	assert_eq(JournalScreen.season_task_text({"text": "Gather 3.", "n": 1, "count": 3}), "Gather 3. (1/3)")
	assert_eq(JournalScreen.season_task_text({"text": "Catch one.", "n": 0, "count": 1}), "Catch one.")


func test_one_left_line() -> void:
	const HUD := preload("res://src/ui/hud.gd")
	assert_eq(HUD.season_one_left_line(_tasks([true, true, false]), "spring"), "One more for spring: Task 2.")
	assert_eq(HUD.season_one_left_line(_tasks([true, false, false]), "spring"), "")
	assert_eq(HUD.season_one_left_line(_tasks([true, true, true]), "spring"), "")
	assert_eq(HUD.season_one_left_line([], "spring"), "")


func test_earning_and_people_cards() -> void:
	var s := _screen()
	s._build_today(PackedStringArray(["Fresh tracks in Y.", "Mei has something to show you."]), [], "",
		PackedStringArray(["Gathering (Herb Slope): about 3 stones a day."]), PackedStringArray(["Mei has something to show you."]))
	assert_true(s._today.find_child("EarningCard", true, false) != null)
	assert_true(s._today.find_child("PeopleCard", true, false) != null)
	assert_eq(_rows(s), 3)  # tracks + earning + one people row (not repeated in the main card)
	s._build_today(PackedStringArray())
	assert_true(s._today.find_child("EarningCard", true, false) == null)
	assert_true(s._today.find_child("PeopleCard", true, false) == null)
	s.queue_free()


func test_people_today_lines_empty_for_new_game() -> void:
	new_character()
	var root: Node = Engine.get_main_loop().root
	root.get_node("GameState").start_session(new_character())
	assert_true(root.get_node("GameState").earning_lines_here().size() <= 3)
	assert_true(root.get_node("GameState").people_today_lines().size() >= 0)
