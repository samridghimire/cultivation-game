class_name QuarrelWindow
extends PanelContainer
## Modal for settling a village quarrel (WU-410): both villagers' portraits, what it is about and the four ways
## to settle it, with their check tags. Choosing calls GameState.settle_quarrel, then the window shows the outcome.

signal closed

const NPC_SCRIPT := preload("res://src/world/interactables/npc.gd")
const TEXT_WIDTH := 656 - PortraitBox.COLUMN_WIDTH

var _npc_id := ""
var _title: Label
var _text: Label
var _choices: VBoxContainer
var _footer: Label
var _portraits: Array[PortraitBox] = []


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(680, 0)
	visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var faces := VBoxContainer.new()
	faces.add_theme_constant_override("separation", 8)
	row.add_child(faces)
	for i in 2:
		var p := PortraitBox.new()
		faces.add_child(p)
		_portraits.append(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	_title = UIStyle.label("A quarrel", 22, UIStyle.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	box.add_child(_title)
	_text = UIStyle.label("", 17)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	box.add_child(_text)
	box.add_child(HSeparator.new())
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	box.add_child(_choices)
	_footer = UIStyle.label("", 14, UIStyle.HINT)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	_footer.visible = false
	box.add_child(_footer)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Window title: "A quarrel: Huang Cai and Xiao Ling".
static func title_for(a_name: String, b_name: String) -> String:
	return "A quarrel: %s and %s" % [a_name, b_name]


## Choice-button text per Folk.QUARREL_CHOICES entry; the mediate check shows as a [Charisma 10] tag.
static func choice_labels(a_name: String, b_name: String, check: Dictionary) -> Dictionary:
	return {
		"mediate": "[%s %d] Mediate" % [String(check["attribute"]).capitalize(), int(check["target"])],
		"side_a": "Side with %s" % a_name,
		"side_b": "Side with %s" % b_name,
		"extort": "Demand payment to keep quiet"}


## Shows the quarrel `npc_id` is part of (or closes if there is none).
func open_for(npc_id: String) -> void:
	_npc_id = npc_id
	var q := GameState.quarrel_of(npc_id)
	if q.is_empty():
		close()
		return
	var a: CharacterData = GameState.npcs[q["a"]]
	var b: CharacterData = GameState.npcs[q["b"]]
	_title.text = title_for(a.name, b.name)
	_text.text = Folk.quarrel_text(q, GameState.npcs, GameState.data)
	for i in 2:
		var id := String(q["a" if i == 0 else "b"])
		_portraits[i].set_portrait(PixelFigure.frame(NPC_SCRIPT.look_of(id, Color("9a8f7a")), "down", 0))
	_clear_choices()
	var check: Dictionary = Folk.quarrel_rules(GameState.data)["outcomes"]["mediate"]["check"]
	var labels := choice_labels(a.name, b.name, check)
	var reason := GameState.check_quarrel(npc_id)
	for choice: String in Folk.QUARREL_CHOICES:
		var text := String(labels[choice])
		if reason != "":
			text += "  (%s)" % reason
		var btn := UIStyle.button(text, _settle.bind(choice))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = reason != ""
		_choices.add_child(btn)
	_footer.text = EncounterWindow.tags_footer(InputConfig.current_label("toggle_help"))
	_footer.visible = true
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


func body_text() -> String:
	return _text.text


func footer_text() -> String:
	return _footer.text if _footer.visible else ""


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


## Settles the quarrel through GameState, then shows what happened until the player closes the window.
func _settle(choice: String) -> void:
	var seen: Array[String] = []
	var grab := func(text: String, _category: String) -> void: seen.append(text)
	EventBus.message_posted.connect(grab)
	GameState.settle_quarrel(_npc_id, choice)
	EventBus.message_posted.disconnect(grab)
	_text.text = seen[seen.size() - 1] if not seen.is_empty() else "It is settled."
	_clear_choices()
	_footer.visible = false
	var done := UIStyle.button("Close", close)
	done.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_choices.add_child(done)
	_focus_first.call_deferred()


func _focus_first() -> void:
	if not is_inside_tree():
		return
	for b in choice_buttons():
		if not b.disabled:
			b.grab_focus()
			return
