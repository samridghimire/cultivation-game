extends Node
## Registers input actions in code so bindings are readable and diffable.
## Keyboard plus gamepad (Steam Deck) bindings for every action. KEYS and
## JOY_BUTTONS are the defaults; the player can rebind the first key and the
## first gamepad button of an action (UI-003c, SettingsScreen > Controls). The
## current bindings live in `keys` / `joy_buttons`, saved to user://controls.cfg.

const KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E],
	"toggle_character_sheet": [KEY_C],
	"toggle_inventory": [KEY_I],
	"toggle_techniques": [KEY_K],
	"toggle_artifact": [KEY_O],
	"toggle_map": [KEY_M],
	"toggle_message_log": [KEY_L],
	"scroll_up": [KEY_PAGEUP],
	"scroll_down": [KEY_PAGEDOWN],
	"toggle_clan": [KEY_G],
	"toggle_journal": [KEY_J],
	"toggle_family": [KEY_F],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"pause_menu": [KEY_ESCAPE],
}

const JOY_BUTTONS := {
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"interact": [JOY_BUTTON_A],
	"toggle_character_sheet": [JOY_BUTTON_Y],
	"toggle_inventory": [JOY_BUTTON_X],
	"toggle_techniques": [JOY_BUTTON_LEFT_SHOULDER],
	"toggle_artifact": [JOY_BUTTON_RIGHT_SHOULDER],
	"toggle_map": [JOY_BUTTON_BACK],
	"toggle_message_log": [JOY_BUTTON_LEFT_STICK],
	"toggle_clan": [JOY_BUTTON_RIGHT_STICK],
	"pause_menu": [JOY_BUTTON_START],
}

## action -> [axis, direction]
const JOY_AXES := {
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"scroll_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"scroll_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"toggle_family": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


## Emitted after bindings or the last-used input device change (HUD key hints).
signal controls_changed

const CONTROLS_PATH := "user://controls.cfg"

## Where rebinds are saved (tests point this elsewhere).
var path := CONTROLS_PATH
## Current bindings: action -> [keycode...] / [joy button...].
var keys: Dictionary = {}
var joy_buttons: Dictionary = {}
## True once the last real input came from a gamepad (drives the HUD key hints).
var last_input_joypad := false


func _ready() -> void:
	load_controls()
	apply()
	for action in JOY_AXES:
		_ensure_action(action)
		var ev := InputEventJoypadMotion.new()
		ev.axis = JOY_AXES[action][0]
		ev.axis_value = JOY_AXES[action][1]
		InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	var pad: bool
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventKey:
		pad = false
	else:
		return
	if pad != last_input_joypad:
		last_input_joypad = pad
		controls_changed.emit()


## Short name of the first binding of `action` ("E", "A"), "" when unbound.
func binding_label(action: String, joypad: bool) -> String:
	if joypad:
		var buttons: Array = joy_buttons.get(action, [])
		if buttons.is_empty():
			return ""
		return HelpScreen.JOY_BUTTON_NAMES.get(buttons[0], "Button %d" % buttons[0])
	var codes: Array = keys.get(action, [])
	return "" if codes.is_empty() else OS.get_keycode_string(codes[0])


## binding_label for whichever device was used last.
func current_label(action: String) -> String:
	return binding_label(action, last_input_joypad)


## "[E] interact   [C] character ..." in the current device's names; actions
## with no binding on that device are left out.
func key_bar_text(entries: Array) -> String:
	var parts: Array[String] = []
	for e: Array in entries:
		var label := current_label(e[0])
		if label != "":
			parts.append("[%s] %s" % [label, e[1]])
	return "   ".join(parts)


## Rebuilds the key and gamepad-button events of every action from `keys` and
## `joy_buttons` (stick axes never change).
func apply() -> void:
	for action in KEYS.keys() + JOY_BUTTONS.keys():
		_ensure_action(action)
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey or ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)
	for action in keys:
		for key in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in joy_buttons:
		for button in joy_buttons[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)


## Defaults, then any saved rebinds (unknown actions and bad values are ignored).
func load_controls() -> void:
	keys = _copy(KEYS)
	joy_buttons = _copy(JOY_BUTTONS)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for action in keys:
		var saved: Variant = cfg.get_value("keys", action, null)
		if saved is Array and not (saved as Array).is_empty() and (saved as Array).all(func(v: Variant) -> bool: return v is int):
			keys[action] = (saved as Array).duplicate()
	for action in joy_buttons:
		var saved: Variant = cfg.get_value("joy_buttons", action, null)
		if saved is Array and not (saved as Array).is_empty() and (saved as Array).all(func(v: Variant) -> bool: return v is int):
			joy_buttons[action] = (saved as Array).duplicate()


func save_controls() -> void:
	var cfg := ConfigFile.new()
	for action in keys:
		cfg.set_value("keys", action, keys[action])
	for action in joy_buttons:
		cfg.set_value("joy_buttons", action, joy_buttons[action])
	var err := cfg.save(path)
	if err != OK:
		push_error("Could not save controls to %s: %s" % [path, error_string(err)])


## Makes `code` the first binding of `action` in `bindings` (action -> [codes]).
## An action that already used `code` gets `action`'s old first binding in its
## place (a swap), so no two actions end up sharing a key or button. Returns
## the new bindings; `bindings` is not changed.
static func rebound(bindings: Dictionary, action: String, code: int) -> Dictionary:
	var out := _copy(bindings)
	var own: Array = out.get(action, [])
	var old: int = own[0] if not own.is_empty() else -1
	if old == code:
		return out
	for other in out:
		if other == action:
			continue
		var list: Array = out[other]
		var at := list.find(code)
		if at >= 0:
			if old >= 0 and not list.has(old):
				list[at] = old
			else:
				list.remove_at(at)
	own = own.duplicate()
	own.erase(code)
	if own.is_empty():
		own.append(code)
	else:
		own[0] = code
	out[action] = own
	return out


func rebind_key(action: String, keycode: int) -> void:
	keys = rebound(keys, action, keycode)
	apply()
	save_controls()
	controls_changed.emit()


func rebind_joy(action: String, button: int) -> void:
	joy_buttons = rebound(joy_buttons, action, button)
	apply()
	save_controls()
	controls_changed.emit()


func reset_controls() -> void:
	keys = _copy(KEYS)
	joy_buttons = _copy(JOY_BUTTONS)
	apply()
	save_controls()
	controls_changed.emit()


static func _copy(bindings: Dictionary) -> Dictionary:
	var out := {}
	for action in bindings:
		out[action] = (bindings[action] as Array).duplicate()
	return out


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
