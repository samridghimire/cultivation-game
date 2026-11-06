extends TestCase
## WU-406: the hint bullet badge sits beside the hint text, never over its first letter.

const HudScript := preload("res://src/ui/hud.gd")


func _hud() -> CanvasLayer:
	var tree := Engine.get_main_loop() as SceneTree
	var gs: Node = tree.root.get_node("GameState")
	gs.start_session(new_character())
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	tree.root.add_child(hud)
	return hud


## Containers only lay out while visible in the tree: show `node` and every ancestor up to the HUD.
func _show_chain(hud: Node, node: Control) -> void:
	var n: Node = node
	while n != null and n != hud:
		if n is CanvasItem:
			(n as CanvasItem).visible = true
		n = n.get_parent()


func test_badge_clears_hint_text() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := _hud()
	var hint: Label = hud.get("_hint")
	var badge: Label = hud.get("_hint_badge")
	hud.call("_set_hint_text", PackedStringArray(["Go to the Village Clinic to heal."]))
	badge.visible = true
	await tree.process_frame
	_show_chain(hud, badge)  # after the HUD's own refresh, which hides the empty card
	await tree.process_frame
	await tree.process_frame
	assert_true(not hint.text.begins_with(" "), "no leading spaces: '%s'" % hint.text)
	assert_true(badge.get_global_rect().end.x + 2.0 <= hint.get_global_rect().position.x,
		"badge %s clear of hint %s" % [badge.get_global_rect(), hint.get_global_rect()])
	hud.queue_free()
	await tree.process_frame


func test_hidden_badge_leaves_no_gap() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := _hud()
	var hint: Label = hud.get("_hint")
	var goal: Label = hud.get("_goal")
	hud.call("_set_hint_text", PackedStringArray(["Rest a while."]))
	hud.get("_hint_badge").visible = false
	await tree.process_frame
	goal.visible = true
	_show_chain(hud, hint)
	await tree.process_frame
	await tree.process_frame
	assert_eq(hint.get_global_rect().position.x, goal.get_global_rect().position.x + float(HudScript.HINT_ICON_W))  # WU-471: the icon column
	hud.queue_free()
	await tree.process_frame


## WU-471: the kind comes from the line's prefix.
func test_hint_kind_by_prefix() -> void:
	assert_eq(HudScript.hint_kind("Goal: Reach Qi Refining Middle"), "goal")
	assert_eq(HudScript.hint_kind("Easy fight: Wolf"), "fight")
	assert_eq(HudScript.hint_kind("Fair fight: Boar"), "fight")
	assert_eq(HudScript.hint_kind("Today: the market opens (J)"), "today")
	assert_eq(HudScript.hint_kind("One more for Spring: sell herbs"), "season")
	assert_eq(HudScript.hint_kind("Rest a while."), "other")


## WU-471: one icon per hint line (the badge is not an icon).
func test_hint_panel_builds_one_icon_per_line() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := _hud()
	hud.call("_set_hint_text", PackedStringArray(["Goal: Reach Qi Refining Middle", "Today: the market opens (J)", "Rest a while."]))
	var strip: Control = hud.get("_hint_icons")
	var icons := strip.get_children().filter(func(c: Node) -> bool: return c is TextureRect)
	assert_eq(icons.size(), 3)
	for i: TextureRect in icons:
		assert_true(i.texture != null)
	assert_true(not (icons[0] as TextureRect).position.y > (icons[1] as TextureRect).position.y, "icons run down the lines")
	hud.call("_set_hint_text", PackedStringArray(["Rest a while."]))
	assert_eq(strip.get_children().filter(func(c: Node) -> bool: return c is TextureRect).size(), 1)
	hud.queue_free()
	await tree.process_frame
