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
