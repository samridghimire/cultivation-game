extends TestCase
## WU-404: the hint bullet badge never covers the first letter of the hint.


func test_badge_clears_hint_text() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	gs.start_session(new_character())
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	var hint: Label = hud.get("_hint")
	var badge: Label = hud.get("_hint_badge")
	var indent: String = hud.call("hint_indent")
	var font := hint.get_theme_font("font")
	var text_left := font.get_string_size(indent, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var badge_right := badge.position.x + badge.get_minimum_size().x
	assert_true(badge_right <= text_left, "badge right %s <= text left %s" % [badge_right, text_left])
	hud.queue_free()
	await tree.process_frame
