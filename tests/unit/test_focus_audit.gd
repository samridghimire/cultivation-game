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

	var shop: Control = hud.get("_shop")
	shop.open("Test Stall", 0, ["herb"])
	await _check(shop, "shop")

	var balance: Control = hud.get("_sect_balance")
	balance.open()
	await _check(balance, "sect balance")

	var report: Control = hud.get("_combat_report")
	report.show_fight("Wild Boar", true, PackedStringArray(["You face the boar.", "You win."]))
	await _check(report, "combat report")

	var source := MenuSource.new()
	root.add_child(source)
	var menu: Control = hud.get("_choice_menu")
	menu.open_for(source)
	await _check(menu, "choice menu")
	source.free()

	var gs_threat := CharacterFactory.create("Hunted", gs.data, seeded_rng(5))
	gs_threat.spiritual_roots = {"fire": 80}
	gs.start_session(gs_threat)
	var foe: Dictionary = gs.data.enemies["mist_wolf"].duplicate(true)
	foe["id"] = "audit_foe"
	foe["lethal"] = true
	gs.data.enemies["audit_foe"] = foe
	gs.pending_threat = "audit_foe"
	EventBus.threat_sensed.emit("audit_foe")
	await _check(menu, "threat prompt")
	assert_eq(gs.pending_threat, "", "closing the threat prompt slips away")

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


class ReasonSource extends Node:
	var display_name := "Reason Stone"
	var used := false

	func menu_options() -> Array[Dictionary]:
		return [
			{"label": "Open", "action": func() -> void: pass},
			{"label": "Locked", "action": _use, "disabled": true, "reason": "Needs a key."},
		]

	func _use() -> void:
		used = true


## WU-022: a gamepad can land on a disabled option and read why; accepting does nothing.
func test_choice_menu_shows_reason_of_focused_disabled_option() -> void:
	var menu := ChoiceMenu.new()
	_tree().root.add_child(menu)
	var src := ReasonSource.new()
	menu.open_for(src)
	await _frames()
	var locked: Button = menu._buttons.get_child(1)
	assert_true(locked.disabled and locked.focus_mode == Control.FOCUS_ALL, "disabled option is focusable")
	assert_true((menu._buttons.get_child(0) as Button).has_focus(), "first enabled option gets focus first")
	locked.grab_focus()
	await _frames()
	assert_eq(menu._description.text, "Needs a key.", "reason shown")
	locked.emit_signal("pressed")
	assert_false(src.used, "disabled option does nothing")
	menu.queue_free()
	src.free()
