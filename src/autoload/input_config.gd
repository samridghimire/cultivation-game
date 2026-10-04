extends Node
## Registers input actions in code so bindings are readable and diffable.
## Keyboard plus gamepad (Steam Deck) bindings for every action.

const KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E],
	"toggle_character_sheet": [KEY_C],
	"toggle_inventory": [KEY_I],
	"toggle_techniques": [KEY_K],
	"toggle_message_log": [KEY_L],
	"scroll_up": [KEY_PAGEUP],
	"scroll_down": [KEY_PAGEDOWN],
	"toggle_clan": [KEY_G],
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
	"toggle_message_log": [JOY_BUTTON_BACK],
	"toggle_clan": [JOY_BUTTON_RIGHT_SHOULDER],
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
}


func _ready() -> void:
	for action in KEYS:
		_ensure_action(action)
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in JOY_BUTTONS:
		_ensure_action(action)
		for button in JOY_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			InputMap.action_add_event(action, ev)
	for action in JOY_AXES:
		_ensure_action(action)
		var ev := InputEventJoypadMotion.new()
		ev.axis = JOY_AXES[action][0]
		ev.axis_value = JOY_AXES[action][1]
		InputMap.action_add_event(action, ev)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
