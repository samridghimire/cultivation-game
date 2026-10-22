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
var _footer: Label


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
	_footer = UIStyle.label("", 14, UIStyle.HINT)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.custom_minimum_size = Vector2(656, 0)
	_footer.visible = false
	box.add_child(_footer)


## Button text for an encounter_choices() entry; locked ones carry their reason.
static func choice_label(choice: Dictionary) -> String:
	var text: String = choice["label"]
	if choice["disabled"]:
		if choice["reason"] != "":
			text += "  (%s)" % choice["reason"]
	elif String(choice.get("check", "")) != "":
		text = "[%s] %s" % [choice["check"], text]
	return text


## " (Even, 80 in 100, to the death)" for a fight choice carrying odds (chance >= 0), else "".
static func fight_suffix(choice: Dictionary) -> String:
	var chance: float = float(choice.get("chance", -1.0))
	if chance < 0.0:
		return ""
	return " (%s)" % UIStyle.odds_wording(chance, bool(choice.get("lethal", false)))


## True when at least one choice label carries a [bracketed] tag (see choice_label).
static func has_tags(choices: Array) -> bool:
	for choice: Dictionary in choices:
		if choice_label(choice).begins_with("["):
			return true
	return false


## Footer explaining the bracketed tags; `help_key` is the Help key's name.
static func tags_footer(help_key: String) -> String:
	var tail := "Help (%s): Choices and Checks." % help_key if help_key != "" else "Help: Choices and Checks."
	return "Tags in [brackets] show what a choice checks or costs. " + tail


## Window title: "Encounter", "Discovery: <name>" for a region discovery, "Hidden path: <name>"
## for a deeper path, or "A request for the renowned: <name>" for an encounter gated by renown.
static func title_for(encounter: Dictionary, discovery: bool, deep_path: bool = false) -> String:
	var renowned := encounter.has("min_renown")
	if not discovery and not deep_path and not renowned:
		return "Encounter"
	var name := String(encounter.get("name", String(encounter.get("id", "")).capitalize()))
	if discovery:
		return "Discovery: " + name
	if deep_path:
		return "Hidden path: " + name
	return "A request for the renowned: " + name


## Shows the pending encounter (or closes if there is none).
func open() -> void:
	var choices := GameState.encounter_choices()
	if choices.is_empty():
		close()
		return
	var enc: Dictionary = GameState.data.encounters.get(GameState.pending_encounter, {})
	_title.text = title_for(enc, GameState.last_explore_discovery, GameState.last_explore_deep_path)
	_text.text = GameState.rival_text(String(GameState.data.encounters.get(GameState.pending_encounter, {}).get("text", "")))
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	_footer.visible = has_tags(choices)
	_footer.text = tags_footer(InputConfig.current_label("toggle_help"))
	var any_enabled := false
	for choice in choices:
		var label := choice_label(choice) + fight_suffix(choice)
		if choice.get("fight", false):
			label = Warnings.append_to(GameState.player, label)
		var b := UIStyle.button(GameState.rival_text(label), GameState.choose_encounter.bind(choice["index"]))
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


func footer_text() -> String:
	return _footer.text if _footer.visible else ""
