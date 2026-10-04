class_name ClanScreen
extends PanelContainer
## Modal clan screen (FAM-005b). Without a clan it shows the founding
## requirements and a "Found the <Surname> Clan" button (Clans.check_found
## reason when unavailable). With a clan: treasury and deposits, members by
## rank on the left with rank changes, and people in the current region who
## could be recruited as retainers. The heir (Clans.heir, FAM-008b) is named in
## the summary and marked in the list; descendant members can be named heir.
## The Estate section (FAM-006b) lists buildings with their level, effects and
## a build/upgrade action (ClanEstate), and the NPC clans of the realm are
## summarized (FAM-009d). Rules live in Clans / ClanEstate / GameState.

signal closed

const DEPOSITS: Array[int] = [10, 100]

var _title: Label
var _summary: Label
var _found_box: VBoxContainer
var _found_info: Label
var _found_status: Label
var _found_button: Button
var _clan_box: HBoxContainer
var _deposit_box: HBoxContainer
var _list: VBoxContainer
var _name: Label
var _info: Label
var _status: Label
var _actions: VBoxContainer
var _close_button: Button
## "m:<id>" for a member, "r:<id>" for a recruit candidate, "b:<id>" for an
## estate building, or "".
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
	_summary = _wrapped(UIStyle.label("", 16))
	box.add_child(_summary)

	_found_box = VBoxContainer.new()
	_found_box.add_theme_constant_override("separation", 8)
	box.add_child(_found_box)
	_found_info = _wrapped(UIStyle.label("", 16))
	_found_box.add_child(_found_info)
	_found_status = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["warning"]))
	_found_box.add_child(_found_status)
	_found_button = UIStyle.button("", _found)
	_found_button.name = "Found"
	_found_box.add_child(_found_button)

	_deposit_box = HBoxContainer.new()
	_deposit_box.add_theme_constant_override("separation", 8)
	box.add_child(_deposit_box)
	for amount in DEPOSITS:
		var b := UIStyle.button("Deposit %d" % amount, _deposit.bind(amount))
		b.name = "Deposit%d" % amount
		_deposit_box.add_child(b)

	_clan_box = HBoxContainer.new()
	_clan_box.add_theme_constant_override("separation", 16)
	box.add_child(_clan_box)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_clan_box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(440, 0)
	details.add_theme_constant_override("separation", 8)
	_clan_box.add_child(details)
	_name = UIStyle.label("", 20, UIStyle.ACCENT)
	details.add_child(_name)
	_info = _wrapped(UIStyle.label("", 15, Color(0.75, 0.75, 0.75)))
	details.add_child(_info)
	_status = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["warning"]))
	details.add_child(_status)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	details.add_child(_actions)

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
	_focus_default.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## "Requires Foundation Establishment and 500 spirit stones; takes 1 month."
static func founding_text(data: GameData) -> String:
	var r := Clans.rules(data)
	var realm: RealmDef = data.realms[maxi(data.realm_index_of(String(r.get("min_realm", "mortal"))), 0)]
	return "Raise a clan under your surname and become its head. Your living spouses and descendants join it.\nRequires the %s realm and %d spirit stones; takes %s." % [
		realm.name, int(r.get("found_cost", 0)), Calendar.format_duration(int(r.get("found_days", 0)))]


## Member ids of `clan`, the head first, then by rank (highest first) and name.
static func sorted_members(clan: ClanData, people: Dictionary, data: GameData) -> Array[String]:
	var order := Clans.ranks(data)
	var out: Array[String] = []
	for member_id in clan.members:
		out.append(String(member_id))
	out.sort_custom(func(a: String, b: String) -> bool:
		var ra := order.find(String(clan.members[a]))
		var rb := order.find(String(clan.members[b]))
		if ra != rb:
			return ra < rb
		return _person_name(a, people).naturalnocasecmp_to(_person_name(b, people)) < 0)
	return out


## Living people in `region_id` who are not yet members of `clan`.
static func recruit_candidates(clan: ClanData, people: Dictionary, data: GameData, region_id: String) -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for c in Npcs.in_region(people, data, region_id):
		if not clan.members.has(c.id):
			out.append(c)
	out.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return a.name.naturalnocasecmp_to(b.name) < 0)
	return out


## "Spirit Field  2/3" (or "not built").
static func building_label(clan: ClanData, data: GameData, building_id: String) -> String:
	var lvl := ClanEstate.level(clan, building_id)
	var text := ClanEstate.building_name(data, building_id)
	text += "  %d/%d" % [lvl, ClanEstate.max_level(data, building_id)] if lvl > 0 else "  (not built)"
	if String(clan.construction.get("building", "")) == building_id:
		text += "  [building]"
	return text


## "Builders: Spirit Field level 2, 40 days left" or "No construction under way."
static func construction_text(clan: ClanData, data: GameData) -> String:
	if clan.construction.is_empty():
		return "No construction under way."
	return "Builders: %s level %d, %s left" % [ClanEstate.building_name(data, String(clan.construction.get("building", ""))), int(clan.construction.get("level", 1)), Calendar.format_duration(maxi(0, int(clan.construction.get("days_left", 0))))]


## Detail lines for a building: description, current effects and the next level.
static func building_lines(clan: ClanData, data: GameData, building_id: String) -> PackedStringArray:
	var lines: PackedStringArray = [String(data.clan_buildings.get(building_id, {}).get("description", ""))]
	var lvl := ClanEstate.level(clan, building_id)
	if lvl > 0:
		lines.append("Level %d: %s" % [lvl, ", ".join(ClanEstate.describe_effects(data, building_id, lvl))])
	var next := ClanEstate.level_def(data, building_id, lvl + 1)
	if next.is_empty():
		lines.append("Fully built.")
	else:
		lines.append("Level %d: %s" % [lvl + 1, ", ".join(ClanEstate.describe_effects(data, building_id, lvl + 1))])
		var cost := "%d spirit stones, %s" % [int(next.get("cost", 0)), Calendar.format_duration(int(next.get("build_days", 0)))]
		if next.has("min_realm"):
			cost += ", head of %s" % data.realms[data.realm_index_of(String(next["min_realm"]))].name
		lines.append("Costs %s." % cost)
	return lines


static func _person_name(id: String, people: Dictionary) -> String:
	var c: CharacterData = people.get(id)
	return c.name if c != null else id


func _person(id: String) -> CharacterData:
	return GameState.player if id == GameState.player.id else GameState.npcs.get(id)


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	var clan: ClanData = GameState.clan
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_found_box.visible = clan == null
	_clan_box.visible = clan != null
	_deposit_box.visible = clan != null
	if clan == null:
		_title.text = "Found a Clan"
		_summary.text = ""
		_summary.visible = false
		_found_info.text = founding_text(data) + "\n\nClans of the realm:\n  " + "\n  ".join(NpcClans.summary_lines(GameState.npc_clans, GameState.npcs, data))
		var reason := Clans.check_found(p, clan, data)
		_found_status.text = reason
		_found_status.visible = reason != ""
		_found_button.text = "Found the %s" % Clans.clan_name(p, data)
		_found_button.disabled = reason != ""
		return
	_title.text = clan.name
	_summary.visible = true
	_summary.text = "Founded %s   |   %d members   |   Treasury: %d spirit stones   (you carry %d)" % [
		Calendar.format_date(clan.founded_day), clan.members.size(), clan.treasury, p.item_count("spirit_stone")]
	var seat := Clans.seat_name(clan, data)
	_summary.text += "\nSeat: %s" % (seat if seat != "" else "none (claim an abode to give the clan a seat)")
	var people_all := GameState.npcs.duplicate()
	people_all[p.id] = p
	var heir_id := Clans.heir(clan, p, people_all, data)
	_summary.text += "   |   %s: %s" % [Clans.heir_title(data), _person_name(heir_id, people_all) if heir_id != "" else "none yet"]
	_summary.text += "\n" + construction_text(clan, data)
	for b: Button in _deposit_box.get_children():
		b.disabled = p.item_count("spirit_stone") < int(String(b.name).trim_prefix("Deposit"))

	var keys: Array[String] = []
	_list.add_child(UIStyle.label("Members", 16, Color(0.75, 0.75, 0.75)))
	var people := GameState.npcs.duplicate()
	people[p.id] = p
	for member_id in sorted_members(clan, people, data):
		var member := _person(member_id)
		var label := "%s  -  %s" % [_person_name(member_id, people), Clans.rank_name(data, String(clan.members[member_id]), member.gender if member != null else "")]
		if member_id == heir_id:
			label += "  (%s)" % Clans.heir_title(data, member.gender if member != null else "")
		keys.append("m:" + member_id)
		_list.add_child(_entry(label, "m:" + member_id, false))
	var candidates := recruit_candidates(clan, GameState.npcs, data, GameState.current_region)
	_list.add_child(UIStyle.label("Recruit in %s" % Exploration.region_name(data, GameState.current_region), 16, Color(0.75, 0.75, 0.75)))
	if candidates.is_empty():
		_list.add_child(UIStyle.label("No one here to recruit.", 15, Color(0.6, 0.6, 0.6)))
	for c in candidates:
		var reason := Clans.check_recruit(p, clan, c, int(GameState.npc_favor.get(c.id, 0)), data)
		keys.append("r:" + c.id)
		_list.add_child(_entry(c.name, "r:" + c.id, reason != ""))
	_list.add_child(UIStyle.label("Clans of the realm", 16, Color(0.75, 0.75, 0.75)))
	for line in NpcClans.summary_lines(GameState.npc_clans, GameState.npcs, data):
		var l := _wrapped(UIStyle.label(line, 14, Color(0.7, 0.7, 0.7)))
		l.custom_minimum_size = Vector2(300, 0)
		_list.add_child(l)
	_list.add_child(UIStyle.label("Estate", 16, Color(0.75, 0.75, 0.75)))
	for building_id in ClanEstate.building_ids(data):
		keys.append("b:" + building_id)
		_list.add_child(_entry(building_label(clan, data, building_id), "b:" + building_id, ClanEstate.check_build(p, clan, building_id, data) != ""))
	if not keys.has(_selected):
		_selected = keys[0] if not keys.is_empty() else ""
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == _key_name(_selected))
	_show_details()


## Node names cannot contain ':', so list buttons use "m_<id>" / "r_<id>".
static func _key_name(key: String) -> String:
	return key.replace(":", "_")


func _entry(label: String, key: String, dim: bool) -> Button:
	var b := UIStyle.button(label, _select.bind(key))
	b.name = _key_name(key)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.focus_entered.connect(_select.bind(key))
	if dim:
		b.modulate = Color(1, 1, 1, 0.6)
	return b


func _select(key: String) -> void:
	if key == _selected:
		return
	_selected = key
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == _key_name(key))
	_show_details()


func _show_details() -> void:
	var p := GameState.player
	var data := GameState.data
	var clan: ClanData = GameState.clan
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var id := _selected.substr(2)
	if _selected.begins_with("b:") and clan != null:
		_show_building(id)
		return
	var person := _person(id) if _selected != "" else null
	for c in [_name, _info, _status]:
		c.visible = person != null
	if person == null or clan == null:
		return
	_name.text = person.name
	var lines: PackedStringArray = []
	if person == p:
		lines.append("You, %s" % Cultivation.realm_label(p, data))
	else:
		lines.append(Npcs.describe(person, data))
		lines.append("Favor: %d" % int(GameState.npc_favor.get(id, 0)))
	_status.text = ""
	if _selected.begins_with("m:"):
		lines.insert(0, "Rank: %s" % Clans.rank_name(data, String(clan.members[id]), person.gender))
		_info.text = "\n".join(lines)
		if id == clan.head:
			_status.text = "The head of the clan."
			return
		var reasons: PackedStringArray = []
		var people := GameState.npcs.duplicate()
		people[p.id] = p
		if Clans.descendants(p, people).has(id):
			var heir_reason := Clans.check_designate(p, clan, person, people)
			var heir_button := UIStyle.button("Name as %s" % Clans.heir_title(data, person.gender), _designate.bind(id))
			heir_button.name = "NameHeir"
			heir_button.disabled = heir_reason != ""
			_actions.add_child(heir_button)
			if heir_reason != "":
				reasons.append(heir_reason)
		for rank_id in Clans.ranks(data):
			if rank_id == Clans.head_rank(data) or rank_id == String(clan.members[id]):
				continue
			var reason := Clans.check_promote(clan, person, rank_id, data)
			var b := UIStyle.button("Make %s" % Clans.rank_name(data, rank_id, person.gender), _set_rank.bind(id, rank_id))
			b.disabled = reason != ""
			_actions.add_child(b)
			if reason != "":
				reasons.append(reason)
		_status.text = "\n".join(reasons)
	else:
		_info.text = "\n".join(lines)
		var reason := Clans.check_recruit(p, clan, person, int(GameState.npc_favor.get(id, 0)), data)
		_status.text = reason
		var b := UIStyle.button("Recruit as retainer (%d stones)" % int(Clans.rules(data).get("recruit_cost", 0)), _recruit.bind(id))
		b.name = "Recruit"
		b.disabled = reason != ""
		_actions.add_child(b)
	_status.visible = _status.text != ""


func _show_building(building_id: String) -> void:
	var p := GameState.player
	var data := GameState.data
	var clan: ClanData = GameState.clan
	for c in [_name, _info, _status]:
		c.visible = true
	_name.text = ClanEstate.building_name(data, building_id)
	_info.text = "\n".join(building_lines(clan, data, building_id))
	var reason := ClanEstate.check_build(p, clan, building_id, data)
	_status.text = reason
	_status.visible = reason != ""
	if ClanEstate.level(clan, building_id) < ClanEstate.max_level(data, building_id):
		var b := UIStyle.button("Build" if ClanEstate.level(clan, building_id) == 0 else "Upgrade", _build.bind(building_id))
		b.name = "Build"
		b.disabled = reason != ""
		_actions.add_child(b)


func _build(building_id: String) -> void:
	GameState.build_clan_building(building_id)
	_focus_default.call_deferred()


func _designate(person_id: String) -> void:
	GameState.designate_heir(person_id)
	_focus_default.call_deferred()


func _found() -> void:
	GameState.found_clan()
	_focus_default.call_deferred()


func _deposit(amount: int) -> void:
	GameState.deposit_to_clan(amount)
	_focus_default.call_deferred()


func _set_rank(member_id: String, rank_id: String) -> void:
	GameState.set_clan_rank(member_id, rank_id)
	_focus_default.call_deferred()


func _recruit(npc_id: String) -> void:
	GameState.recruit_to_clan(npc_id)
	_focus_default.call_deferred()


func _focus_default() -> void:
	if not visible:
		return
	if GameState.clan == null:
		if not _found_button.disabled:
			_found_button.grab_focus()
		else:
			_close_button.grab_focus()
		return
	var b := _list.get_node_or_null(NodePath(_key_name(_selected))) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
