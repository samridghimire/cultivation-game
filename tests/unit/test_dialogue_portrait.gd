extends TestCase
## WU-408: the speaker's framed portrait in DialogueWindow and ChoiceMenu.


class PlaceSource extends Node:
	var display_name := "Stall"

	func menu_options() -> Array[Dictionary]:
		return [{"label": "Browse", "action": func() -> void: pass}]


class FaceSource extends PlaceSource:
	func portrait_texture() -> Texture2D:
		return PixelFigure.frame({"robe": Color.RED, "sash": Color.WHITE}, "down", 0)


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_interactable_default_has_no_portrait() -> void:
	var i := Interactable.new()
	assert_true(i.portrait_texture() == null)
	i.free()


func test_figure_frame_size() -> void:
	var tex: Texture2D = FaceSource.new().portrait_texture()
	assert_eq(Vector2i(tex.get_size()), PixelFigure.SIZE)


func test_choice_menu_portrait_column() -> void:
	var menu := ChoiceMenu.new()
	_tree().root.add_child(menu)
	var face := FaceSource.new()
	menu.open_for(face)
	assert_true(menu.portrait_visible(), "NPC shows the portrait")
	menu.close()
	var place := PlaceSource.new()
	menu.open_for(place)
	assert_false(menu.portrait_visible(), "place hides it")
	await _tree().process_frame
	await _tree().process_frame
	var focus := menu.get_viewport().gui_get_focus_owner()
	assert_true(focus is Button, "focus lands on a button")
	menu.free()
	face.free()
	place.free()


func test_dialogue_text_fits_beside_portrait() -> void:
	var w := DialogueWindow.new()
	w.set_portrait(FaceSource.new().portrait_texture())
	assert_true(w.portrait_visible())
	assert_true(w._text.custom_minimum_size.x + PortraitBox.COLUMN_WIDTH <= DialogueWindow.TEXT_WIDTH + 0.5)
	w.set_portrait(null)
	assert_false(w.portrait_visible())
	assert_eq(w._text.custom_minimum_size.x, float(DialogueWindow.TEXT_WIDTH))
	w.free()
