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


func test_title_is_followed_by_a_separator() -> void:
	var menu := ChoiceMenu.new()
	var box := menu._title.get_parent()
	assert_true(box.get_child(menu._title.get_index() + 1) is HSeparator, "rule under the title")
	menu.free()


class ShortSource extends Node:
	var display_name := "Village Herb Seller"

	func menu_options() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for i in 3:
			out.append({"label": "Option %d" % i, "action": func() -> void: pass})
		return out


## WU-409: a short menu shrinks to its content (no blank band above the footer rule).
func test_short_menu_fits_content() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 800)
	_tree().root.add_child(vp)
	var menu := ChoiceMenu.new()
	vp.add_child(menu)
	var source := ShortSource.new()
	vp.add_child(source)
	menu.open_for(source)
	for i in 4:
		await _tree().process_frame
	var buttons_h: float = menu._buttons.get_combined_minimum_size().y
	var title_h: float = menu._title.get_combined_minimum_size().y
	print("panel=%s buttons=%s title=%s" % [menu.size.y, buttons_h, title_h])
	assert_true(menu.size.y < buttons_h + title_h + 120.0, "panel %s too tall for %s buttons + title" % [menu.size.y, buttons_h])
	vp.free()
