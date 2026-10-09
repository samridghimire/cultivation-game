extends TestCase
## WU-068: an open ChoiceMenu refits its scroll height when the viewport shrinks or grows.


class FakeSource extends Node:
	var display_name := "Long list"

	func menu_options() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for i in 40:
			out.append({"label": "Option %d" % i, "action": func() -> void: pass})
		return out


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_scroll_refits_when_viewport_resizes() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 800)
	_tree().root.add_child(vp)
	var menu := ChoiceMenu.new()
	vp.add_child(menu)
	var source := FakeSource.new()
	vp.add_child(source)
	menu.open_for(source)
	await _tree().process_frame
	await _tree().process_frame
	var before: float = menu._scroll.custom_minimum_size.y
	assert_eq(before, 800.0 - ChoiceMenu.MENU_MARGIN)
	vp.size = Vector2i(1280, 500)
	await _tree().process_frame
	await _tree().process_frame
	assert_eq(menu._scroll.custom_minimum_size.y, 500.0 - ChoiceMenu.MENU_MARGIN, "scroll shrank")
	vp.size = Vector2i(1280, 800)
	await _tree().process_frame
	await _tree().process_frame
	assert_eq(menu._scroll.custom_minimum_size.y, before, "growing back restores it")
	vp.free()
