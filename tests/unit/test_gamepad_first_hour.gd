extends TestCase
## WU-574: the first hour is reachable with a gamepad alone. Opens every HUD screen with synthesized
## joypad events and every first-hour Qingshi menu; each must take focus, move it with ui_down when it has
## 2+ buttons, and close on the pad's cancel button, returning focus to the world.


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int = 2) -> void:
	for i in n:
		await _tree().process_frame


func _button(button: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		_tree().root.push_input(ev)


func _axis(axis: int, value: float) -> void:
	for v in [value, 0.0]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axis
		ev.axis_value = v
		_tree().root.push_input(ev)


## Presses the pad binding of `action` (button or trigger axis).
func _pad(action: String) -> void:
	if InputConfig.JOY_BUTTONS.has(action):
		_button(int(InputConfig.JOY_BUTTONS[action][0]))
	elif InputConfig.JOY_AXES.has(action):
		_axis(int(InputConfig.JOY_AXES[action][0]), float(InputConfig.JOY_AXES[action][1]))
	else:
		assert_true(false, "%s has no gamepad binding" % action)


func _buttons_in(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is BaseButton and (c as Control).is_visible_in_tree() and not (c as BaseButton).disabled:
			out.append(c)
		_buttons_in(c, out)


## Focus is inside `screen`; ui_down moves it when there are 2+ buttons; pad cancel closes it.
func _check(screen: Control, label: String) -> void:
	await _frames()
	assert_true(screen.is_visible_in_tree(), "%s opens" % label)
	var root := _tree().root
	var owner := root.gui_get_focus_owner()
	assert_true(owner != null, "%s: something has focus" % label)
	if owner != null:
		assert_true(screen.is_ancestor_of(owner), "%s: focus is inside (got %s)" % [label, owner.name])
		var buttons: Array = []
		_buttons_in(screen, buttons)
		if buttons.size() >= 2:
			var start: Control = owner
			var moved := false
			# A column moves on down, a button row on right (no neighbour below a single row).
			for dir: int in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT]:
				_button(dir)
				await _frames(1)
				if root.gui_get_focus_owner() != start:
					moved = true
					break
			assert_true(moved, "%s: the d-pad moves focus (%d buttons)" % [label, buttons.size()])
	_button(JOY_BUTTON_B)
	await _frames()
	assert_false(screen.visible, "%s: B closes it" % label)
	var after := root.gui_get_focus_owner()
	assert_true(after == null or not screen.is_ancestor_of(after), "%s: focus left the closed screen" % label)


func test_first_hour_on_a_gamepad() -> void:
	var root := _tree().root
	var gs: Node = root.get_node("GameState")
	gs.start_session(CharacterFactory.create("Wanderer", gs.data, seeded_rng(3)))
	gs.pending_event = ""
	var world: Node = load("res://src/world/world.tscn").instantiate()
	root.add_child(world)
	await _frames(3)
	var hud: CanvasLayer = world.get_node("HUD")

	var screens: Dictionary = hud.get("_screens")
	for action: String in screens:
		if action == "open_calendar":  # no pad button of its own: the journal's Calendar button opens it
			hud.call("_open_calendar_from_journal")
		else:
			_pad(action)
		await _check(screens[action], "pad " + action)

	var player: Player = world.get_node("Player")
	var wanted := ["Elder Mo", "merchant", "bounty", "meditat", "herb", "jetty", "fish"]
	var tested := 0
	var seen := {}
	var menu: Control = hud.get("_choice_menu")
	for node in world.get_children():
		if not (node is Interactable):
			continue
		var inter := node as Interactable
		var name_l := inter.display_name.to_lower()
		var hit := false
		for w: String in wanted:
			if name_l.contains(w.to_lower()):
				hit = true
		if not hit or inter is ForagePickup:
			continue
		player.position = inter.position
		await _frames(3)
		var target := player.current_target()  # the nearest one wins when two stand close
		if target == null or target is ForagePickup or seen.has(target.display_name):
			continue
		seen[target.display_name] = true
		_pad("interact")
		await _frames()
		if not menu.visible:
			continue
		tested += 1
		await _check(menu, "menu " + target.display_name)
	assert_gt(tested, 2, "several Qingshi menus were driven by the pad")

	world.free()
	gs.end_session()
