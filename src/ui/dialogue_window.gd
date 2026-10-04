class_name DialogueWindow
extends PanelContainer
## Modal conversation window. The HUD opens it on EventBus.dialogue_requested
## and closes it on dialogue_ended. It renders GameState.dialogue_view() and
## sends picks to GameState.choose_dialogue; locked choices show their reason.

signal closed

var _speaker: Label
var _text: Label
var _choices: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(680, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_speaker = UIStyle.label("", 22, UIStyle.ACCENT)
	box.add_child(_speaker)
	_text = UIStyle.label("", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(656, 0)
	box.add_child(_text)
	box.add_child(HSeparator.new())
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	box.add_child(_choices)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameState.end_dialogue()
		close()


## Button text for a dialogue_view() choice; locked ones carry their reason.
static func choice_label(choice: Dictionary) -> String:
	var text: String = choice["label"]
	if choice["disabled"] and choice["reason"] != "":
		text += "  (%s)" % choice["reason"]
	return text


## Shows the current node of the conversation in progress (or closes if none).
func open() -> void:
	var view := GameState.dialogue_view()
	if view.is_empty():
		close()
		return
	_speaker.text = view["speaker"]
	_text.text = view["text"]
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	for choice: Dictionary in view["choices"]:
		var b := UIStyle.button(choice_label(choice), _choose.bind(choice["index"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = choice["disabled"]
		_choices.add_child(b)
	visible = true
	_focus_first.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Buttons currently offered, in order (for tests and focus).
func choice_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _choices.get_children():
		if child is Button:
			out.append(child)
	return out


func speaker_text() -> String:
	return _speaker.text


func line_text() -> String:
	return _text.text


func _choose(index: int) -> void:
	GameState.choose_dialogue(index)
	# dialogue_ended (via the HUD) closes us when the conversation is over.
	if GameState.dialogue_npc != "":
		open()
	else:
		close()


func _focus_first() -> void:
	if not is_inside_tree():
		return
	for b in choice_buttons():
		if not b.disabled:
			b.grab_focus()
			return
