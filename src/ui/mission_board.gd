class_name MissionBoard
extends PanelContainer
## Modal sect mission board, opened from the sect hall: the missions the
## player's sect offers on the left; kind, duration, hand-in items (have/need),
## enemy danger, rewards and cooldown on the right, with a Take button. Missions
## with a fight show its danger (Sects.mission_danger), colored, in the list and
## details, since a mission's foe is always fought. A second
## "Treasury" tab is the sect's contribution shop (G-008e): items with cost and
## minimum rank, bought with GameState.buy_with_contribution. A third "Rank" tab
## (G-011b) lists the sect's ranks with their requirements (contribution, realm,
## trial foe and its danger), stipend and monthly duty, your duty progress this
## month, and "Attempt promotion trial" (GameState.attempt_promotion_trial).
## All rules live in Sects / GameState.

signal closed

const KIND_NAMES := {"gather": "Gathering", "hunt": "Hunt", "deliver": "Delivery", "guard": "Escort"}

var _title: Label
var _missions_tab: Button
var _shop_tab: Button
var _rank_tab: Button
var _list: VBoxContainer
var _name: Label
var _info: Label
var _description: Label
var _requirements: Label
var _danger: Label
var _rewards: Label
var _status: Label
var _take_button: Button
var _close_button: Button
var _selected := ""
## "missions", "shop" (the contribution treasury) or "rank".
var _tab := "missions"


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(800, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	box.add_child(_title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	_missions_tab = UIStyle.button("Missions", _set_tab.bind("missions"))
	_shop_tab = UIStyle.button("Treasury", _set_tab.bind("shop"))
	_rank_tab = UIStyle.button("Rank", _set_tab.bind("rank"))
	for b: Button in [_missions_tab, _shop_tab, _rank_tab]:
		b.toggle_mode = true
		tabs.add_child(b)

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
	_danger = _wrapped(UIStyle.label("", 16))
	details.add_child(_danger)
	_rewards = _wrapped(UIStyle.label("", 16, UIStyle.CATEGORY_COLORS["progress"]))
	details.add_child(_rewards)
	_status = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["warning"]))
	details.add_child(_status)
	_take_button = UIStyle.button("Take mission", _act)
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
	_tab = "missions"
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


## "Costs 40 contribution  |  Inner Disciple or above" for a shop entry.
## "Danger: Deadly. A mission's foe is always fought; there is no slipping away."
## for missions with a fight, "" otherwise.
static func danger_text(danger: String) -> String:
	if danger == "":
		return ""
	var text := "Danger: %s." % danger
	if danger == "Deadly" or danger == "Dangerous":
		text += " A mission's foe is always fought; there is no slipping away."
	return text


## What reaching `rank` of `c`'s sect takes: contribution (have/need), realm
## and the trial foe with its danger for `c`.
static func rank_requirement_lines(c: CharacterData, data: GameData, rank: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var def: Dictionary = (data.sects[c.sect["id"]] as SectDef).ranks[rank]
	var need := int(def.get("contribution", 0))
	if need > 0:
		lines.append("%d / %d lifetime contribution" % [mini(int(c.sect["contribution"]), need), need])
	if def.has("min_realm"):
		lines.append("Realm: %s or above" % data.realms[data.realm_index_of(String(def["min_realm"]))].name)
	var trial := String(def.get("trial", ""))
	if trial != "" and data.enemies.has(trial):
		lines.append("Trial: defeat %s in a sparring match (%s)" % [data.enemies[trial]["name"], Combat.danger_label(c, data, data.enemies[trial])])
	return lines


## A rank's monthly stipend and duty, e.g. ["Stipend: 50 spirit stones, 1 Qi
## Gathering Pill a month", "Monthly duty: 80 contribution"].
static func rank_benefit_lines(data: GameData, sect_id: String, rank: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var def: Dictionary = (data.sects[sect_id] as SectDef).ranks[rank]
	var stipend: Dictionary = def.get("stipend", {})
	var parts: PackedStringArray = []
	if int(stipend.get("spirit_stones", 0)) > 0:
		parts.append("%d spirit stones" % int(stipend["spirit_stones"]))
	var items: Dictionary = stipend.get("items", {})
	for item_id in items:
		parts.append("%d %s" % [int(items[item_id]), data.items.get(item_id, {}).get("name", item_id)])
	lines.append("Stipend: %s" % (", ".join(parts) + " a month" if not parts.is_empty() else "none"))
	var duty := int(def.get("monthly_duty", 0))
	lines.append("Monthly duty: %s" % ("%d contribution (or the stipend is withheld)" % duty if duty > 0 else "none"))
	return lines


## "Duty this month: 20 / 30 contribution" for `c`'s current rank.
static func duty_text(c: CharacterData, data: GameData) -> String:
	var duty := Sects.monthly_duty(c, data)
	if duty <= 0:
		return "Your rank owes no monthly duty."
	var text := "Duty this month: %d / %d contribution" % [mini(Sects.duty_progress(c), duty), duty]
	if bool(c.sect.get("duty_grace", false)):
		text += " (waived: promoted this month)"
	return text


static func shop_info_text(c: CharacterData, data: GameData, entry: Dictionary) -> String:
	var parts: PackedStringArray = ["Costs %d contribution" % int(entry.get("contribution", 0))]
	var min_rank := int(entry.get("min_rank", 0))
	if min_rank > 0 and not c.is_rogue():
		parts.append("%s or above" % (data.sects[c.sect["id"]] as SectDef).rank_name(min_rank))
	var owned := c.item_count(String(entry.get("item_id", "")))
	if owned > 0:
		parts.append("you carry %d" % owned)
	return "  |  ".join(parts)


## What a shop item does: its effects, or its equipment slot and stats.
static func shop_item_lines(c: CharacterData, data: GameData, item_id: String) -> PackedStringArray:
	if Equipment.is_equipment(data, item_id):
		return InventoryScreen.describe_equipment(c, data, item_id)
	return InventoryScreen.describe_effects(data.items.get(item_id, {}).get("effects", {}), data)


func _set_tab(tab: String) -> void:
	_missions_tab.set_pressed_no_signal(tab == "missions")
	_shop_tab.set_pressed_no_signal(tab == "shop")
	_rank_tab.set_pressed_no_signal(tab == "rank")
	if tab == _tab:
		return
	_tab = tab
	_selected = ""
	_rebuild()
	_focus_selected.call_deferred()


func _clear_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()


func _add_entry(id: String, label: String, available: bool) -> void:
	var b := UIStyle.button(label, _select.bind(id))
	b.name = id
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.toggle_mode = true
	b.button_pressed = id == _selected
	b.focus_entered.connect(_select.bind(id))
	if not available:
		b.modulate = Color(1, 1, 1, 0.6)
	_list.add_child(b)


func _add_hint(text: String) -> void:
	var hint := _wrapped(UIStyle.label(text, 16, Color(0.7, 0.7, 0.7)))
	hint.custom_minimum_size = Vector2(300, 0)
	_list.add_child(hint)


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	_clear_list()
	_missions_tab.set_pressed_no_signal(_tab == "missions")
	_shop_tab.set_pressed_no_signal(_tab == "shop")
	_rank_tab.set_pressed_no_signal(_tab == "rank")
	_title.text = "Mission Board"
	if not p.is_rogue():
		_title.text = "%s Mission Board   (contribution %d, %d to spend)" % [(data.sects[p.sect["id"]] as SectDef).name, int(p.sect["contribution"]), Sects.contribution_balance(p)]
	if _tab == "shop":
		_rebuild_shop()
	elif _tab == "rank":
		_rebuild_ranks()
	else:
		_rebuild_missions()


func _rebuild_shop() -> void:
	var p := GameState.player
	var data := GameState.data
	var ids: Array[String] = []
	for entry in Sects.shop_items(p, data):
		ids.append(String(entry["item_id"]))
	if not ids.has(_selected):
		_selected = ""
		for item_id in ids:
			if Sects.check_purchase(p, data, item_id) == "":
				_selected = item_id
				break
		if _selected == "" and not ids.is_empty():
			_selected = ids[0]
	if ids.is_empty():
		_add_hint("The sect treasury has nothing to offer you.")
	for item_id in ids:
		var entry := Sects.shop_entry(p, data, item_id)
		var label := "%s (%d)" % [data.items.get(item_id, {}).get("name", item_id), int(entry["contribution"])]
		_add_entry(item_id, label, Sects.check_purchase(p, data, item_id) == "")
	_show_details()


func _rebuild_missions() -> void:
	var p := GameState.player
	var data := GameState.data
	var ids := Sects.available_missions(p, data, GameState.world_flags)
	if not ids.has(_selected):
		_selected = ""
		for mission_id in ids:
			if Sects.check_mission(p, data, mission_id, GameState.world_flags) == "":
				_selected = mission_id
				break
		if _selected == "" and not ids.is_empty():
			_selected = ids[0]
	if ids.is_empty():
		_add_hint("No missions are posted for you. Only sect disciples receive sect missions.")
	for mission_id in ids:
		var mission: Dictionary = data.sect_missions[mission_id]
		var label := String(mission["name"])
		var wait := Sects.mission_cooldown_left(p, mission_id)
		if wait > 0:
			label += " (in %s)" % Calendar.format_duration(wait)
		var danger := Sects.mission_danger(p, data, mission_id)
		if danger != "":
			label += "  [%s]" % danger
		_add_entry(mission_id, label, Sects.check_mission(p, data, mission_id, GameState.world_flags) == "")
		if danger != "":
			UIStyle.tint_button_text(_list.get_child(-1) as Button, UIStyle.danger_color(danger))
	_show_details()


func _rebuild_ranks() -> void:
	var p := GameState.player
	if p.is_rogue():
		_selected = ""
		_add_hint("Rogue cultivators hold no rank.")
		_show_details()
		return
	var sect: SectDef = GameState.data.sects[p.sect["id"]]
	var current := int(p.sect["rank"])
	if not _selected.begins_with("rank_"):
		_selected = "rank_%d" % (current + 1 if current + 1 < sect.ranks.size() else current)
	for i in sect.ranks.size():
		var label := sect.rank_name(i)
		if i == current:
			label += "  (your rank)"
		elif i == current + 1:
			label += "  (next)"
		_add_entry("rank_%d" % i, label, i <= current + 1)
	_show_details()


func _show_rank_details() -> void:
	var p := GameState.player
	var data := GameState.data
	var rank := int(_selected.trim_prefix("rank_")) if _selected.begins_with("rank_") else -1
	for c in [_name, _info, _description, _requirements, _rewards, _status, _take_button]:
		c.visible = rank >= 0
	_danger.visible = false
	if rank < 0:
		return
	var sect: SectDef = data.sects[p.sect["id"]]
	var current := int(p.sect["rank"])
	_name.text = sect.rank_name(rank)
	_info.text = "Your rank: %s  |  %d lifetime contribution, %d to spend" % [sect.rank_name(current), int(p.sect["contribution"]), Sects.contribution_balance(p)]
	_description.text = duty_text(p, data)
	var reqs := rank_requirement_lines(p, data, rank)
	_requirements.visible = not reqs.is_empty() and rank > current
	_requirements.text = "Requires:\n  " + "\n  ".join(reqs)
	_rewards.text = "\n".join(rank_benefit_lines(data, sect.id, rank))
	_take_button.text = "Attempt promotion trial"
	var is_next := rank == current + 1
	_take_button.visible = is_next and String(sect.ranks[rank].get("trial", "")) != ""
	var reason := ""
	if rank <= current:
		reason = "You hold this rank." if rank == current else "You have risen past this rank."
	elif not is_next:
		reason = "Reach %s first." % sect.rank_name(current + 1)
	else:
		reason = Sects.check_promotion(p, data)
	_status.text = reason
	_status.visible = reason != ""
	_take_button.disabled = reason != ""


func _select(mission_id: String) -> void:
	if mission_id == _selected:
		return
	_selected = mission_id
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == mission_id)
	_show_details()


func _show_details() -> void:
	if _tab == "shop":
		_show_shop_details()
		return
	if _tab == "rank":
		_show_rank_details()
		return
	_take_button.text = "Take mission"
	var p := GameState.player
	var data := GameState.data
	var mission: Dictionary = data.sect_missions.get(_selected, {})
	for c in [_name, _info, _description, _requirements, _rewards, _status, _take_button]:
		c.visible = not mission.is_empty()
	var danger := Sects.mission_danger(p, data, _selected) if not mission.is_empty() else ""
	_danger.visible = danger != ""
	_danger.text = danger_text(danger)
	_danger.add_theme_color_override("font_color", UIStyle.danger_color(danger))
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
	var reason := Sects.check_mission(p, data, _selected, GameState.world_flags)
	var cooldown := int(mission.get("cooldown_days", 0))
	_status.text = reason
	if reason == "" and cooldown > 0:
		_status.text = "Offered again %s after you take it." % Calendar.format_duration(cooldown)
	_take_button.disabled = reason != ""


func _show_shop_details() -> void:
	var p := GameState.player
	var data := GameState.data
	var entry := Sects.shop_entry(p, data, _selected)
	for c in [_name, _info, _description, _requirements, _rewards, _status, _take_button]:
		c.visible = not entry.is_empty()
	_danger.visible = false
	if entry.is_empty():
		return
	var item: Dictionary = data.items.get(_selected, {})
	_name.text = String(item.get("name", _selected))
	_info.text = shop_info_text(p, data, entry)
	_description.text = String(item.get("description", ""))
	_requirements.visible = false
	var lines := shop_item_lines(p, data, _selected)
	_rewards.visible = not lines.is_empty()
	_rewards.text = "\n".join(lines)
	var reason := Sects.check_purchase(p, data, _selected)
	_status.text = reason
	_status.visible = reason != ""
	_take_button.text = "Buy"
	_take_button.disabled = reason != ""


func _act() -> void:
	if _tab == "shop":
		_buy()
	elif _tab == "rank":
		GameState.attempt_promotion_trial()
		if visible:
			_focus_selected.call_deferred()
	else:
		_take()


func _buy() -> void:
	if _selected == "":
		return
	GameState.buy_with_contribution(_selected)
	if visible:
		_focus_selected.call_deferred()


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
