extends TestCase
## QA-008: gamepad/focus audit. Opens every HUD modal on a live HUD and checks
## that a visible control inside it has keyboard/gamepad focus and that
## ui_cancel closes it (CLAUDE.md rule 8).


class MenuSource extends Node:
	var display_name := "Test Stone"

	func menu_options() -> Array[Dictionary]:
		return [{"label": "Touch it", "action": func() -> void: pass}]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_tree().root.push_input(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	_tree().root.push_input(release)


## Asserts `screen` is open with focus inside it, then closes it with ui_cancel.
func _check(screen: Control, label: String) -> void:
	await _frames()
	assert_true(screen.is_visible_in_tree(), "%s opens" % label)
	var owner := _tree().root.gui_get_focus_owner()
	assert_true(owner != null, "%s: something has focus" % label)
	if owner != null:
		assert_true(screen.is_ancestor_of(owner), "%s: focus is inside the screen (got %s)" % [label, owner.name])
		assert_true(owner.is_visible_in_tree(), "%s: the focused control is visible" % label)
	_press("ui_cancel")
	await _frames()
	assert_false(screen.visible, "%s: ui_cancel closes it" % label)


func test_every_hud_screen_has_focus_and_closes_on_cancel() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	var c := new_character()
	c.add_item("qi_gathering_pill", 1)
	gs.start_session(c)
	gs.pending_event = ""  # skip the intro story event (ART-006b); its window would hold the input
	var hud: CanvasLayer = load("res://src/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await _frames()

	var screens: Dictionary = hud.get("_screens")
	assert_gt(screens.size(), 0)
	for action: String in screens:
		_press(action)
		await _check(screens[action], action)

	var crafting: Control = hud.get("_crafting")
	crafting.open("alchemist")
	await _check(crafting, "crafting")

	var report: Control = hud.get("_combat_report")
	report.show_fight("Wild Boar", true, PackedStringArray(["You face the boar.", "You win."]))
	await _check(report, "combat report")

	var source := MenuSource.new()
	root.add_child(source)
	var menu: Control = hud.get("_choice_menu")
	menu.open_for(source)
	await _check(menu, "choice menu")
	source.free()

	_press("pause_menu")
	var pause: Control = hud.get("_pause_menu")
	await _check(pause, "pause menu")

	var settings: Control = hud.get("_settings")
	settings.open()
	await _check(settings, "settings")
	pause.close()

	var load_screen: Control = hud.get("_load_screen")
	load_screen.open()
	await _check(load_screen, "load")
	pause.close()

	root.remove_child(hud)
	hud.free()
	gs.end_session()
	await _frames()
