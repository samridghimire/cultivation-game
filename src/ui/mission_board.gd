class_name MissionBoard
extends PanelContainer
## Modal sect mission board, opened from the sect hall: the missions the
## player's sect offers on the left; kind, duration, hand-in items (have/need),
## enemy danger, rewards and cooldown on the right, with a Take button. All
## rules live in Sects / GameState.take_mission.

signal closed

const KIND_NAMES := {"gather": "Gathering", "hunt": "Hunt", "deliver": "Delivery", "guard": "Escort"}

var _title: Label
var _list: VBoxContainer
var _name: Label
var _info: Label
var _description: Label
var _requirements: Label
var _rewards: Label
var _status: Label
var _take_button: Button
var _close_button: Button
var _selected := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(800, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	box.add_child(_title)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(440, 0)
	details.add_theme_constant_override("separation", 8)
	columns.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = _wrapped(UIStyle.label("", 15, Color(0.75, 0.75, 0.75)))
	details.add_child(_info)
	_description = _wrapped(UIStyle.label("", 16))
	details.add_child(_description)
	_requirements = _wrapped(UIStyle.label("", 16))
	details.add_child(_requirements)
	_rewards = _wrapped(UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["progress"]))
	details.add_child(_rewards)
	_status = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["warning"]))
	details.add_child(_status)
	_take_button = UIStyle.button("Take mission", _take)
	_take_button.name = "Take"
	details.add_child(_take_button)

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


## "Hunt  |  takes 5 days  |  +80 contribution" summary line for a mission
## (plus the minimum rank in `c`'s sect, if any).
static func info_text(c: CharacterData, data: GameData, mission: Dictionary) -> String:
	var parts: PackedStringArray = [
		KIND_NAMES.get(String(mission.get("kind", "")), String(mission.get("kind", "")).capitalize()),
		"takes %s" % Calendar.format_duration(int(mission.get("days", 1))),
		"+%d contribution" % int(mission.get("contribution", 0)),
	]
	var min_rank := int(mission.get("min_rank", 0))
	if min_rank > 0 and not c.is_rogue():
		parts.append("%s or above" % (data.sects[c.sect["id"]] as SectDef).rank_name(min_rank))
	return "  |  ".join(parts)


## Hand-in items as "2 / 5 Spirit Herb" lines and the enemy with its danger
## for `c`; empty when the mission needs neither.
static func requirement_lines(c: CharacterData, data: GameData, mission: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var needed: Dictionary = mission.get("requires", {}).get("items", {})
	for item_id in needed:
		lines.append("%d / %d %s" % [c.item_count(item_id), int(needed[item_id]), data.items.get(item_id, {}).get("name", item_id)])
	var enemy_id := String(mission.get("enemy", ""))
	if data.enemies.has(enemy_id):
		var enemy: Dictionary = data.enemies[enemy_id]
		lines.append("Defeat: %s (%s)" % [enemy["name"], Combat.danger_label(c, data, enemy)])
	return lines


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := Sects.available_missions(p, data)
	_title.text = "Mission Board"
	if not p.is_rogue():
		_title.text = "%s Mission Board   (contribution %d)" % [(data.sects[p.sect["id"]] as SectDef).name, int(p.sect["contribution"])]
	if not ids.has(_selected):
		_selected = ""
		for mission_id in ids:
			if Sects.check_mission(p, data, mission_id) == "":
				_selected = mission_id
				break
		if _selected == "" and not ids.is_empty():
			_selected = ids[0]
	if ids.is_empty():
		var hint := _wrapped(UIStyle.label("No missions are posted for you. Only sect disciples receive sect missions.", 16, Color(0.7, 0.7, 0.7)))
		hint.custom_minimum_size = Vector2(300, 0)
		_list.add_child(hint)
	for mission_id in ids:
		var mission: Dictionary = data.sect_missions[mission_id]
		var label := String(mission["name"])
		var wait := Sects.mission_cooldown_left(p, mission_id)
		if wait > 0:
			label += " (in %s)" % Calendar.format_duration(wait)
		var b := UIStyle.button(label, _select.bind(mission_id))
		b.name = mission_id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = mission_id == _selected
		b.focus_entered.connect(_select.bind(mission_id))
		if Sects.check_mission(p, data, mission_id) != "":
			b.modulate = Color(1, 1, 1, 0.6)
		_list.add_child(b)
	_show_details()


func _select(mission_id: String) -> void:
	if mission_id == _selected:
		return
	_selected = mission_id
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == mission_id)
	_show_details()


func _show_details() -> void:
	var p := GameState.player
	var data := GameState.data
	var mission: Dictionary = data.sect_missions.get(_selected, {})
	for c in [_name, _info, _description, _requirements, _rewards, _status, _take_button]:
		c.visible = not mission.is_empty()
	if mission.is_empty():
		return
	_name.text = mission["name"]
	_info.text = info_text(p, data, mission)
	_description.text = String(mission.get("description", ""))
	var reqs := requirement_lines(p, data, mission)
	_requirements.visible = not reqs.is_empty()
	_requirements.text = "Requires:\n  " + "\n  ".join(reqs)
	var rewards := InventoryScreen.describe_effects(mission.get("rewards", {}), data)
	_rewards.visible = not rewards.is_empty()
	_rewards.text = "Rewards:\n  " + "\n  ".join(rewards)
	var reason := Sects.check_mission(p, data, _selected)
	var cooldown := int(mission.get("cooldown_days", 0))
	_status.text = reason
	if reason == "" and cooldown > 0:
		_status.text = "Offered again %s after you take it." % Calendar.format_duration(cooldown)
	_take_button.disabled = reason != ""


func _take() -> void:
	var mission_id := _selected
	if mission_id == "":
		return
	# A fight closes every screen for the combat report; otherwise stay open.
	GameState.take_mission(mission_id)
	if visible:
		_focus_selected.call_deferred()


func _focus_selected() -> void:
	if not visible:
		return
	var b := _list.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
