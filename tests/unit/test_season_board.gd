extends TestCase
## WU-466: the village board's season task card: option label, near-village gating, rows and focus.


func _tasks(done: Array) -> Array:
	var out: Array = []
	for i in done.size():
		out.append({"text": "Task %d" % (i + 1), "n": 1 if done[i] else 0, "count": 1, "done": done[i]})
	return out


func test_option_label_for_0_2_and_3_done() -> void:
	assert_eq(SeasonBoard.option_label(_tasks([false, false, false]), "spring"), "Village tasks this spring (0 of 3 done)")
	assert_eq(SeasonBoard.option_label(_tasks([true, true, false]), "spring"), "Village tasks this spring (2 of 3 done)")
	assert_eq(SeasonBoard.option_label(_tasks([true, true, true]), "spring"), "Village tasks this spring: all done")


func test_one_left_line_only_near_qingshi() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	assert_true(SeasonBoard.near_village(gs.data, "qingshi_village"))
	var far := ""
	for id: String in gs.data.regions:
		if id != "qingshi_village" and not Exploration.is_nearby(gs.data, id, "qingshi_village"):
			far = id
			break
	assert_true(far != "", "some region lies more than one road from Qingshi")
	assert_false(SeasonBoard.near_village(gs.data, far))


func test_journal_header_names_qingshi_when_elsewhere() -> void:
	assert_eq(JournalScreen.season_header("qingshi_village"), "The season's tasks")
	assert_true(JournalScreen.season_header("misty_forest").contains("(in Qingshi Village)"))


func test_board_builds_rows_and_takes_focus() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	var board := SeasonBoard.new()
	root.add_child(board)
	board.build(_tasks([true, false, false]), "spring", "", "Old shrine: 1 of 4 stages restored", "5 stones")
	board.visible = true
	assert_eq(board.row_count(), 3)
	board.first_row().grab_focus()
	await (Engine.get_main_loop() as SceneTree).process_frame
	assert_true(board.first_row().has_focus())
	board.close()
	assert_false(board.visible)
	board.queue_free()


func test_board_option_on_bounty_board_in_qingshi() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	var board := preload("res://src/world/interactables/bounty_board.gd").new()
	var opts: Array[Dictionary] = board.get_options()
	assert_true(String(opts[0]["label"]).begins_with("Village tasks this"))
	board.free()


func test_where_line_only_when_text_lacks_the_place() -> void:
	assert_eq(SeasonBoard.where_line("Sell herbs at the Herb Stall", "herb stall"), "")
	assert_eq(SeasonBoard.where_line("Win a contest", "Qingshi Village"), "at Qingshi Village")
	assert_eq(SeasonBoard.where_line("Win a contest", ""), "")


func test_done_row_has_checked_box_and_where_line() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	root.get_node("GameState").start_session(new_character())
	var board := SeasonBoard.new()
	root.add_child(board)
	var tasks := _tasks([true, false])
	tasks[0]["where"] = "Old Well"
	board.build(tasks, "spring", "", "", "5 stones")
	assert_true(board.row_check(0).checked)
	assert_false(board.row_check(1).checked)
	assert_eq(board.row_button(0).get_parent().get_child_count(), 2, "where on its own line")
	assert_eq(board.row_button(1).get_parent().get_child_count(), 1)
	board.queue_free()


func test_shop_title_is_one_line_with_notes_in_another_label() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var gs: Node = root.get_node("GameState")
	gs.start_session(new_character())
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.open("Wandering Merchant")
	assert_eq(shop._title.text, "Wandering Merchant")
	assert_true(shop._title_notes != null)
	assert_false(shop._title_notes.text.begins_with(" "))
	shop.queue_free()
