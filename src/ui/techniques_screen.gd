class_name TechniquesScreen
extends PanelContainer
## Modal technique overview: known techniques (and manuals in the pouch that
## could be learned) on the left; details, mastery and actions on the right.

signal closed

const PRACTICE_DAYS: Array[int] = [7, 30]
const KIND_NAMES := {"cultivation": "Cultivation Method", "combat": "Combat Art", "body": "Body Tempering"}

var _list: VBoxContainer
var _name: Label
var _info: Label
var _description: Label
var _bonuses: Label
var _mastery: Label
var _xp_bar: ProgressBar
var _actions: HBoxContainer
var _close_button: Button
var _selected := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel().get_theme_stylebox("panel"))
	custom_minimum_size = Vector2(760, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Techniques", 24, UIStyle.ACCENT))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(420, 0)
	details.add_theme_constant_override("separation", 8)
	columns.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = UIStyle.label("", 14, Color(0.7, 0.7, 0.7))
	details.add_child(_info)
	_description = UIStyle.label("", 16)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_description)
	_bonuses = UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["progress"])
	_bonuses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_bonuses)
	_mastery = UIStyle.label("", 15)
	_mastery.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_mastery)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(400, 14)
	_xp_bar.show_percentage = false
	details.add_child(_xp_bar)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	details.add_child(_actions)

	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.player_changed.connect(func(): if visible: _rebuild())


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


## Technique ids to list: known ones first (by name), then techniques whose
## manual the character carries but has not learned yet (by name).
static func listed_ids(c: CharacterData, data: GameData) -> Array:
	var by_name := func(a, b): return data.techniques[a].name.naturalnocasecmp_to(data.techniques[b].name) < 0
	var known: Array = c.techniques.keys().filter(func(id): return data.techniques.has(id))
	known.sort_custom(by_name)
	var manuals: Array = []
	for def: TechniqueDef in data.techniques.values():
		if def.manual_item != "" and c.item_count(def.manual_item) > 0 and not Techniques.knows(c, def.id):
			manuals.append(def.id)
	manuals.sort_custom(by_name)
	return known + manuals


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := listed_ids(p, data)
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
	if ids.is_empty():
		var hint := UIStyle.label("You know no techniques. Manuals can be bought or found while exploring.", 16, Color(0.7, 0.7, 0.7))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(280, 0)
		_list.add_child(hint)
	for tech_id in ids:
		var def: TechniqueDef = data.techniques[tech_id]
		var suffix := "Lv %d" % Techniques.level(p, tech_id) if Techniques.knows(p, tech_id) else "(manual)"
		var b := UIStyle.button("%s  %s" % [def.name, suffix], _select.bind(tech_id))
		b.name = tech_id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = tech_id == _selected
		b.focus_entered.connect(_select.bind(tech_id))
		_list.add_child(b)
	_show_details()


func _select(tech_id: String) -> void:
	if tech_id == _selected:
		return
	_selected = tech_id
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == tech_id)
	_show_details()


func _show_details() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var def: TechniqueDef = data.techniques.get(_selected)
	for c in [_name, _info, _description, _bonuses, _mastery, _xp_bar]:
		c.visible = def != null
	if def == null:
		return
	_name.text = def.name
	var element := "any root" if def.element == "" else "%s element" % def.element.capitalize()
	var min_realm: RealmDef = data.realms[data.realm_index_of(def.min_realm)]
	_info.text = "%s  |  %s  |  requires %s" % [KIND_NAMES.get(def.kind, def.kind.capitalize()), element, min_realm.name]
	_description.text = def.description
	var bonuses := Techniques.describe_bonuses(p, data, def.id)
	if Techniques.knows(p, def.id):
		_bonuses.text = bonuses
		var lvl := Techniques.level(p, def.id)
		if Techniques.is_mastered(p, data, def.id):
			_mastery.text = "Level %d / %d (mastered)" % [lvl, def.max_level]
			_xp_bar.max_value = 1.0
			_xp_bar.value = 1.0
		else:
			var needed := def.xp_to_next(lvl)
			var have := float(p.techniques[def.id]["xp"])
			_mastery.text = "Level %d / %d   (%d / %d practice)   ~%.1f per day" % [lvl, def.max_level, int(have), int(needed), Techniques.xp_per_day(p)]
			_xp_bar.max_value = needed
			_xp_bar.value = have
			for days in PRACTICE_DAYS:
				_actions.add_child(UIStyle.button("Practice %s" % Calendar.format_duration(days), _practice.bind(days)))
		if not def.activation.is_empty():
			_bonuses.text = Techniques.describe_activation(p, data, def.id)
			var activate := UIStyle.button("Activate (-%d years)" % int(def.activation.get("lifespan_cost", 0)), _activate)
			activate.disabled = Techniques.can_activate(p, data, def.id) != ""
			_actions.add_child(activate)
	else:
		_bonuses.text = "At level 1: %s" % bonuses if def.activation.is_empty() else Techniques.describe_activation(p, data, def.id)
		_xp_bar.visible = false
		var reason := Techniques.can_learn(p, data, def.id)
		_mastery.text = reason if reason != "" else "You carry the manual for this technique."
		var learn := UIStyle.button("Learn", _learn)
		learn.disabled = reason != ""
		_actions.add_child(learn)


func _practice(days: int) -> void:
	GameState.practice_technique(_selected, days)
	_focus_first_action.call_deferred()


func _activate() -> void:
	GameState.activate_technique(_selected)
	_focus_first_action.call_deferred()


func _learn() -> void:
	GameState.learn_technique(_selected)
	_focus_selected.call_deferred()


func _focus_selected() -> void:
	var b := _list.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()


func _focus_first_action() -> void:
	for child in _actions.get_children():
		if child is Button and not child.disabled and not child.is_queued_for_deletion():
			child.grab_focus()
			return
	_focus_selected()
