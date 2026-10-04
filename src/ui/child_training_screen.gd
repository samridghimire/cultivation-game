class_name ChildTrainingScreen
extends PanelContainer
## Modal screen for training descendants (FAM-004b), opened from the character
## sheet: the player's living children on the left; age, realm, current
## assignment and one button per assignment (one per profession for
## apprenticeships) on the right, with Training.check_assign reasons on the
## disabled ones and a "Stop training" button. Rules live in Training /
## GameState.assign_training / clear_training.

signal closed

var _list: VBoxContainer
var _name: Label
var _info: Label
var _current: Label
var _actions: VBoxContainer
var _close_button: Button
var _selected := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(820, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Train Your Children", 24, UIStyle.ACCENT))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(280, 420)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(500, 0)
	details.add_theme_constant_override("separation", 8)
	columns.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = _wrapped(UIStyle.label("", 15, Color(0.75, 0.75, 0.75)))
	details.add_child(_info)
	_current = _wrapped(UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["progress"]))
	details.add_child(_current)
	var action_scroll := ScrollContainer.new()
	action_scroll.custom_minimum_size = Vector2(500, 300)
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(action_scroll)
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_scroll.add_child(_actions)

	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.player_changed.connect(func(): if visible: _rebuild())


func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_selected = ""
	_rebuild()
	visible = true
	_focus_selected.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## The player's living children, in birth order.
static func living_children(c: CharacterData, people: Dictionary) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for child_id in c.children:
		var child: CharacterData = people.get(child_id)
		if child != null and child.alive:
			out.append(child)
	return out


## "Cultivation (Qi Refining 2), 5 stones a month" style line for the child's
## current assignment, or "No training assigned."
static func current_text(child: CharacterData, data: GameData) -> String:
	var id := Training.current(child)
	if id == "":
		return "No training assigned."
	var what := Training.assignment_name(data, id)
	var prof_id := String(child.training.get("profession", ""))
	if data.professions.has(prof_id):
		what += " (%s)" % data.professions[prof_id].name
	return "Training: %s, %d spirit stones a month." % [what, Training.monthly_cost(data, id)]


## One entry per choosable assignment for `child`: {label, assignment,
## profession, reason}. Apprenticeships get one entry per profession.
static func assignment_options(c: CharacterData, child: CharacterData, data: GameData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in Training.assignments(data):
		var base := "%s (%d stones/month)" % [Training.assignment_name(data, id), Training.monthly_cost(data, id)]
		var professions: Array = [""]
		if String(Training.assignment(data, id).get("kind", "")) == "profession":
			professions = data.professions.keys()
			professions.sort()
		for prof_id: String in professions:
			var label := base
			if prof_id != "":
				label = "%s: %s (%d stones/month)" % [Training.assignment_name(data, id), data.professions[prof_id].name, Training.monthly_cost(data, id)]
			var reason := Training.check_assign(c, child, id, prof_id, data)
			if reason == "" and Training.current(child) == id and String(child.training.get("profession", "")) == prof_id:
				reason = "Already training this."
			out.append({"label": label, "assignment": id, "profession": prof_id, "reason": reason})
	return out


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var kids := living_children(p, GameState.npcs)
	var ids: Array[String] = []
	for kid in kids:
		ids.append(kid.id)
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
	if kids.is_empty():
		var hint := _wrapped(UIStyle.label("You have no living children to train.", 16, Color(0.7, 0.7, 0.7)))
		hint.custom_minimum_size = Vector2(260, 0)
		_list.add_child(hint)
	for kid in kids:
		var b := UIStyle.button("%s (age %d)" % [kid.name, kid.age_years()], _select.bind(kid.id))
		b.name = kid.id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = kid.id == _selected
		b.focus_entered.connect(_select.bind(kid.id))
		_list.add_child(b)
	_show_details()


func _select(child_id: String) -> void:
	if child_id == _selected:
		return
	_selected = child_id
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == child_id)
	_show_details()


func _show_details() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var kid: CharacterData = GameState.npcs.get(_selected)
	for c in [_name, _info, _current]:
		c.visible = kid != null
	if kid == null:
		return
	_name.text = kid.name
	_info.text = "Age %d  |  %s  |  %s" % [kid.age_years(), Cultivation.realm_label(kid, data), SpiritualRoots.describe(kid.spiritual_roots, data)]
	_current.text = current_text(kid, data)
	for option in assignment_options(p, kid, data):
		var reason := String(option["reason"])
		var label := String(option["label"])
		if reason != "":
			label += "  - " + reason
		var b := UIStyle.button(label, _assign.bind(String(option["assignment"]), String(option["profession"])))
		b.name = "assign_%s_%s" % [option["assignment"], option["profession"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = reason != ""
		_actions.add_child(b)
	if Training.current(kid) != "":
		var stop := UIStyle.button("Stop training", _stop)
		stop.name = "stop"
		_actions.add_child(stop)


func _assign(assignment_id: String, profession: String) -> void:
	if _selected == "":
		return
	GameState.assign_training(_selected, assignment_id, profession)
	_focus_selected.call_deferred()


func _stop() -> void:
	if _selected == "":
		return
	GameState.clear_training(_selected)
	_focus_selected.call_deferred()


func _focus_selected() -> void:
	if not visible:
		return
	var b := _list.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
