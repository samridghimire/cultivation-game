extends TestCase
## WU-027: ChoiceMenu shows an option's `reason` (disabled) or `description`
## (enabled) under the buttons, and interactables keep reasons out of labels.

## Longest unavoidable labels: "Temper your body: Copper Skin (...)" (98) and secret realm delves
## with a guardian (up to ~100); everything else fits well within it.
const MAX_LABEL := 105


class FakeSource extends Node:
	var display_name := "Fake"
	var options: Array[Dictionary] = []

	func menu_options() -> Array[Dictionary]:
		return options


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _gs() -> Node:
	return _tree().root.get_node("GameState")


func _button(menu: ChoiceMenu, text: String) -> Button:
	for b: Node in menu._buttons.get_children():
		if b is Button and (b as Button).text == text:
			return b
	return null


func test_description_line_follows_focus() -> void:
	var src := FakeSource.new()
	src.options = [
		{"label": "Locked", "action": func() -> void: pass, "disabled": true, "reason": "needs more favor"},
		{"label": "Open", "action": func() -> void: pass, "description": "A calm month, about 100 qi."},
		{"label": "Plain", "action": func() -> void: pass},
	]
	var menu := ChoiceMenu.new()
	_tree().root.add_child(menu)
	menu.open_for(src)
	_button(menu, "Locked").focus_entered.emit()
	assert_eq(menu._description.text, "needs more favor")
	assert_eq(menu._description.get_theme_color("font_color"), UIStyle.CATEGORY_COLORS["warning"])
	_button(menu, "Open").focus_entered.emit()
	assert_eq(menu._description.text, "A calm month, about 100 qi.")
	assert_true(menu._description.get_theme_color("font_color") != UIStyle.CATEGORY_COLORS["warning"])
	_button(menu, "Plain").focus_entered.emit()
	assert_eq(menu._description.text, "")
	menu.queue_free()
	src.free()


func _check_options(node: Interactable, who: String) -> void:
	for o: Dictionary in node.menu_options():
		var label := String(o.get("label", ""))
		var reason := String(o.get("reason", ""))
		assert_true(label.length() <= MAX_LABEL, "%s: label too long (%d): %s" % [who, label.length(), label])
		if reason != "":
			assert_false(label.contains(reason), "%s: label repeats its reason: %s" % [who, label])


func test_no_label_repeats_its_reason() -> void:
	var gs := _gs()
	for kind in ["mortal", "disciple"]:
		var c := CharacterFactory.create("Desc %s" % kind, gs.data, seeded_rng(5), "female")
		c.spiritual_roots = {"fire": 70, "wood": 50}
		gs.start_session(c)
		if kind == "disciple":
			c.realm_index = gs.data.realm_index_of("qi_refining")
			c.stage = 6
			c.alignment = 300
			c.add_item("spirit_stone", 500)
			gs.join_sect("azure_cloud_sect")
		for region_id: String in gs.data.regions:
			gs.current_region = region_id
			gs.spawn_anchor = ""
			var world: Node = load("res://src/world/world.tscn").instantiate()
			_tree().root.add_child(world)
			await _tree().process_frame
			for node in world.get_children():
				if node is Interactable and node.is_available():
					_check_options(node, "%s/%s/%s" % [kind, region_id, node.display_name])
			world.queue_free()
			await _tree().process_frame
		gs.end_session()
