class_name FamilyScreen
extends PanelContainer
## Modal family tree (FAM-010), opened from the character sheet: the player's
## parents, spouses, children and grandchildren grouped by generation on the
## left (the departed marked), and for the selected relative their realm, age,
## spiritual roots, bloodline, home, favor, clan rank and training on the right,
## with "Training..." (the ChildTrainingScreen) and "Send to <sect>" / "Recall"
## (FAM-009c) for living children and "Name as heir" for clan members. Rules
## live in Family / Clans / Training / Sects.

signal closed

var _list: VBoxContainer
var _name: Label
var _info: Label
var _actions: HBoxContainer
var _sect_actions: VBoxContainer
var _close_button: Button
var _selected := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(820, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Family", 24, UIStyle.ACCENT))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(480, 0)
	details.add_theme_constant_override("separation", 8)
	columns.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = UIStyle.label("", 15, Color(0.85, 0.85, 0.85))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_info)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	details.add_child(_actions)
	_sect_actions = VBoxContainer.new()
	_sect_actions.add_theme_constant_override("separation", 6)
	details.add_child(_sect_actions)
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


## The player's relatives by generation: [[heading, [ids]]] with empty
## generations left out. Grandchildren are the children's children.
static func generations(c: CharacterData, people: Dictionary) -> Array:
	var grandchildren: Array[String] = []
	for child_id in c.children:
		var child: CharacterData = people.get(child_id)
		if child != null:
			for grandchild_id in child.children:
				if not grandchildren.has(grandchild_id):
					grandchildren.append(grandchild_id)
	var out: Array = []
	for group in [["Parents", c.parents], ["Spouses", c.spouses], ["Children", c.children], ["Grandchildren", grandchildren]]:
		var ids: Array = (group[1] as Array).filter(func(id: String) -> bool: return people.has(id))
		if not ids.is_empty():
			out.append([group[0], ids])
	return out


## Detail lines for relative `person`.
static func person_lines(c: CharacterData, person: CharacterData, data: GameData, people: Dictionary, favor: Dictionary, clan: ClanData) -> PackedStringArray:
	var lines: PackedStringArray = []
	if not person.alive:
		lines.append("Departed: %s, at %d." % [person.cause_of_death if person.cause_of_death != "" else "passed away", person.age_years()])
		return lines
	lines.append("%s, age %d" % [Cultivation.realm_label(person, data), person.age_years()])
	lines.append("Spiritual root: %s" % SpiritualRoots.describe(person.spiritual_roots, data))
	var bloodline := Bloodlines.describe(person, data)
	if bloodline != "":
		lines.append("Bloodline: %s" % bloodline)
	lines.append("Lives in %s" % Exploration.region_name(data, Npcs.region_of(person, data)))
	var sect := Sects.member_text(person, data)
	if sect != "":
		lines.append("%s%s" % [sect.left(1).to_upper(), sect.substr(1)])
	if favor.has(person.id):
		lines.append("Favor: %d" % int(favor[person.id]))
	if clan != null and clan.members.has(person.id):
		var rank := Clans.rank_name(data, String(clan.members[person.id]), person.gender)
		if Clans.heir(clan, c, people, data) == person.id:
			rank += ", %s" % Clans.heir_title(data, person.gender)
		lines.append("%s of the %s" % [rank, clan.name])
	if c.children.has(person.id):
		var assignment := Training.current(person)
		lines.append("Training: %s" % (Training.assignment_name(data, assignment) if assignment != "" else "none"))
	if Children.is_pregnant(person):
		lines.append("With child.")
	return lines


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var people := GameState.npcs
	var groups := generations(p, people)
	var ids: Array = []
	if groups.is_empty():
		_list.add_child(UIStyle.label("You have no family yet.", 16, Color(0.7, 0.7, 0.7)))
	for group in groups:
		_list.add_child(UIStyle.label(String(group[0]), 16, Color(0.75, 0.75, 0.75)))
		for id in group[1]:
			var person: CharacterData = people[id]
			var label := person.name if person.alive else "%s (departed)" % person.name
			var b := UIStyle.button(label, _select.bind(String(id)))
			b.name = String(id)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			b.focus_entered.connect(_select.bind(String(id)))
			if not person.alive:
				b.modulate = Color(1, 1, 1, 0.55)
			_list.add_child(b)
			ids.append(String(id))
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
	_show_details()


func _select(id: String) -> void:
	_selected = id
	_show_details()


func _show_details() -> void:
	var p := GameState.player
	var data := GameState.data
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == _selected)
	for row in [_actions, _sect_actions]:
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
	var person: CharacterData = GameState.npcs.get(_selected)
	_name.visible = person != null
	_info.visible = person != null
	if person == null:
		return
	_name.text = person.name
	_info.text = "\n".join(person_lines(p, person, data, GameState.npcs, GameState.npc_favor, GameState.clan))
	if not person.alive:
		return
	if p.children.has(person.id):
		var training := UIStyle.button("Training...", func(): EventBus.child_training_requested.emit())
		training.name = "Training"
		_actions.add_child(training)
		_add_sect_actions(p, person, data)
	var clan: ClanData = GameState.clan
	if clan != null and clan.members.has(person.id):
		var people := GameState.npcs.duplicate()
		people[p.id] = p
		var reason := Clans.check_designate(p, clan, person, people)
		var heir := UIStyle.button("Name as %s" % Clans.heir_title(data, person.gender), func(): GameState.designate_heir(person.id))
		heir.name = "NameHeir"
		heir.disabled = reason != ""
		heir.tooltip_text = reason
		_actions.add_child(heir)


## "Send to <sect>" per sect for a child outside any sect (disabled with the
## Sects.check_send_child reason), or "Recall from <sect>" (FAM-009c).
func _add_sect_actions(p: CharacterData, child: CharacterData, data: GameData) -> void:
	if not child.is_rogue():
		var sect_name := (data.sects[child.sect["id"]] as SectDef).name if data.sects.has(String(child.sect["id"])) else "sect"
		var recall := UIStyle.button("Recall from the %s" % sect_name, func(): GameState.recall_child_from_sect(child.id))
		recall.name = "Recall"
		_sect_actions.add_child(recall)
		return
	var min_age := int(data.family.get("sect_entry", {}).get("min_age_years", 12))
	if child.age_years() < min_age:
		_sect_actions.add_child(UIStyle.label("Sects take disciples from age %d." % min_age, 14, Color(0.6, 0.6, 0.6)))
		return
	var ids: Array = data.sects.keys()
	ids.sort()
	for sect_id: String in ids:
		var reason := Sects.check_send_child(p, child, data, sect_id)
		var send := UIStyle.button("Send to the %s" % (data.sects[sect_id] as SectDef).name, func(): GameState.send_child_to_sect(child.id, sect_id))
		send.name = "Send_" + sect_id
		send.disabled = reason != ""
		send.tooltip_text = reason
		_sect_actions.add_child(send)


func _focus_selected() -> void:
	if not visible:
		return
	var b := _list.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
