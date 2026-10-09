class_name EncounterWindow
extends PanelContainer
## Modal for encounters that offer choices (help, rob, fight...). The HUD opens
## it on EventBus.encounter_choice_requested and closes it on
## encounter_choice_resolved. Locked choices show why. If every choice is
## locked, the player can walk away (GameState.dismiss_encounter).

signal closed

var _title: Label
var _text: Label
var _choices: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(680, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	_title = UIStyle.label("Encounter", 22, UIStyle.ACCENT)
	box.add_child(_title)
	_text = UIStyle.label("", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(656, 0)
	box.add_child(_text)
	box.add_child(HSeparator.new())
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	box.add_child(_choices)


## Button text for an encounter_choices() entry; locked ones carry their reason.
static func choice_label(choice: Dictionary) -> String:
	var text: String = choice["label"]
	if choice["disabled"] and choice["reason"] != "":
		text += "  (%s)" % choice["reason"]
	return text


## Window title: "Encounter", or "Discovery: <name>" for a region discovery.
static func title_for(encounter: Dictionary, discovery: bool) -> String:
	if not discovery:
		return "Encounter"
	var name := String(encounter.get("name", String(encounter.get("id", "")).capitalize()))
	return "Discovery: " + name


## Shows the pending encounter (or closes if there is none).
func open() -> void:
	var choices := GameState.encounter_choices()
	if choices.is_empty():
		close()
		return
	var enc: Dictionary = GameState.data.encounters.get(GameState.pending_encounter, {})
	_title.text = title_for(enc, GameState.last_explore_discovery)
	_text.text = GameState.rival_text(String(GameState.data.encounters.get(GameState.pending_encounter, {}).get("text", "")))
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	var any_enabled := false
	for choice in choices:
		var b := UIStyle.button(GameState.rival_text(choice_label(choice)), GameState.choose_encounter.bind(choice["index"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = choice["disabled"]
		any_enabled = any_enabled or not b.disabled
		_choices.add_child(b)
	if not any_enabled:
		var leave := UIStyle.button("Walk away", GameState.dismiss_encounter)
		leave.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_choices.add_child(leave)
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


func encounter_text() -> String:
	return _text.text


func _focus_first() -> void:
	if not is_inside_tree():
		return
	for b in choice_buttons():
		if not b.disabled:
			b.grab_focus()
			return
