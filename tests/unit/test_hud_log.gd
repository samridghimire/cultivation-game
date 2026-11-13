extends TestCase
## WU-249: identical consecutive log lines collapse into one "(xN)" line on the HUD.

const HUD := preload("res://src/ui/hud.gd")


func _hud() -> CanvasLayer:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	gs.start_session(new_character())
	gs.pending_event = ""
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	return hud


func _lines(hud: CanvasLayer) -> Array:
	var log: RichTextLabel = hud.get("_log")
	var out: Array = []
	for l: String in log.get_parsed_text().split("\n"):
		if l.strip_edges() != "":
			out.append(l)
	return out


func _finish(hud: CanvasLayer) -> void:
	hud.queue_free()
	(Engine.get_main_loop() as SceneTree).root.get_node("GameState").end_session()


func test_collapsed_line() -> void:
	assert_eq(HUD.collapsed_line("a", 1), "a")
	assert_eq(HUD.collapsed_line("a", 3), "a (x3)")


func test_three_identical_posts_give_one_line() -> void:
	var hud := _hud()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var start: int = _lines(hud).size()
	for i in 3:
		hud.call("_on_message", "You practice the Iron Fist for 3 days.", "info")
	var lines := _lines(hud)
	assert_eq(lines.size(), start + 1)
	assert_true(String(lines[-1]).ends_with("(x3)"), String(lines[-1]))
	_finish(hud)


func test_other_category_or_text_does_not_collapse() -> void:
	var hud := _hud()
	await (Engine.get_main_loop() as SceneTree).process_frame
	var start: int = _lines(hud).size()
	hud.call("_on_message", "same", "info")
	hud.call("_on_message", "same", "warning")
	assert_eq(_lines(hud).size(), start + 2)
	hud.call("_on_message", "A", "info")
	hud.call("_on_message", "B", "info")
	hud.call("_on_message", "A", "info")
	assert_eq(_lines(hud).size(), start + 5)
	_finish(hud)


func test_log_still_capped() -> void:
	var hud := _hud()
	await (Engine.get_main_loop() as SceneTree).process_frame
	for i in HUD.MAX_LOG_LINES + 20:
		hud.call("_on_message", "line %d" % i, "info")
	assert_true(_lines(hud).size() <= HUD.MAX_LOG_LINES + 1)
	_finish(hud)


func test_fit_messages() -> void:
	var none: Array[float] = []
	assert_eq(HUD.fit_messages(none, 80.0), 0)
	var all: Array[float] = [20.0, 20.0, 20.0]
	assert_eq(HUD.fit_messages(all, 80.0), 3)
	var mixed: Array[float] = [60.0, 40.0, 20.0]
	assert_eq(HUD.fit_messages(mixed, 80.0), 2)
	var exact: Array[float] = [40.0, 40.0]
	assert_eq(HUD.fit_messages(exact, 80.0), 2)
	var tall: Array[float] = [20.0, 100.0]
	assert_eq(HUD.fit_messages(tall, 80.0), 0)


func test_card_starts_on_a_whole_message() -> void:
	var hud := _hud()
	await (Engine.get_main_loop() as SceneTree).process_frame
	hud.call("_on_message", "Zebra one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty twenty-one twenty-two twenty-three twenty-four twenty-five twenty-six", "info")
	hud.call("_on_message", "Alpha short.", "info")
	hud.call("_on_message", "Beta short.", "info")
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var log: RichTextLabel = hud.get("_log")
	var top_px: int = int(log.get_v_scroll_bar().value)
	var starts: Array = []
	for i in log.get_paragraph_count():
		starts.append(int(log.get_paragraph_offset(i)))
	assert_true(starts.has(top_px), "scroll %d should be a message start in %s" % [top_px, starts])
	# REVIEW (WU-531): the card's text itself starts on a whole message (the shot showed "in all)." on top).
	for i in 6:
		hud.call("_on_message", "Filler %d with enough words to wrap onto a second line of the narrow log card here." % i, "info")
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	var text := log.get_parsed_text().strip_edges()
	assert_true(text.begins_with("Filler "), "card starts on a message: %s" % text)
	assert_true(log.get_content_height() <= HUD.LOG_CARD_MAX_LINES * HUD.LOG_CARD_MIN_LINE_PX + 1, "whole messages fit the card")
	_finish(hud)
