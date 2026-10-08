class_name InventoryScreen
extends PanelContainer
## Modal inventory: item list on the left, details and actions for the
## selected item on the right. Selection follows focus so it works on gamepad.
## Equipment shows its slot and stats and is equipped instead of used.
## Combat talismans can be readied for battle (CombatTalismans) or put away.

signal closed

var _list: VBoxContainer
var _name: Label
var _description: Label
var _effects: Label
var _use_button: Button
## Item whose risky Use/Equip waits for a second press (WU-032), "" = none.
var _use_armed := ""
var _ready_button: Button
var _readied: Label
var _close_button: Button
var _selected := ""
var _tabs: HBoxContainer
## Selected category tab; remembered while the game runs.
static var _category := "All"


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(760, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Inventory", 24, UIStyle.ACCENT))
	_readied = UIStyle.label("", 15, Color(0.75, 0.75, 0.85))
	_readied.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_readied)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	box.add_child(_tabs)
	for cat in Items.CATEGORIES:
		var tb := UIStyle.button(cat, _set_category.bind(cat))
		tb.name = cat
		tb.toggle_mode = true
		_tabs.add_child(tb)

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
	_description = UIStyle.label("", 16)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_description)
	_effects = UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["progress"])
	_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_effects)
	_use_button = UIStyle.button("Use", _use_selected)
	_use_button.focus_exited.connect(_disarm_use.call_deferred)
	details.add_child(_use_button)
	_ready_button = UIStyle.button("Ready for battle", _toggle_ready)
	details.add_child(_ready_button)

	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.player_changed.connect(func(): if visible: _rebuild())


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_selected = ""
	_sync_tabs()
	_rebuild()
	visible = true
	_focus_selected.call_deferred()


func _sync_tabs() -> void:
	for tb in _tabs.get_children():
		(tb as Button).set_pressed_no_signal(tb.name == _category)


func _set_category(cat: String) -> void:
	_category = cat
	_selected = ""
	_sync_tabs()
	_rebuild()
	_focus_selected.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Item ids the player holds, sorted by display name.
static func sorted_item_ids(c: CharacterData, data: GameData) -> Array:
	var ids := c.inventory.keys()
	ids.sort_custom(func(a, b): return _item_name(data, a).naturalnocasecmp_to(_item_name(data, b)) < 0)
	return ids


## Sorted item ids in one category tab ("All" = everything).
static func filtered_ids(c: CharacterData, data: GameData, category: String) -> Array:
	var ids := sorted_item_ids(c, data)
	if category == "All":
		return ids
	return ids.filter(func(id): return Items.category(data.items.get(id, {})) == category)


## Human-readable summary of an effects dictionary; see Items.describe_effects.
static func describe_effects(effects: Dictionary, data: GameData) -> PackedStringArray:
	return Items.describe_effects(effects, data)


## Detail lines for an equipment item: slot + stats, and what it would replace.
static func describe_equipment(c: CharacterData, data: GameData, item_id: String) -> PackedStringArray:
	var slot := Equipment.slot_of(data, item_id)
	var lines: PackedStringArray = ["%s: %s" % [slot.capitalize(), Equipment.describe_stats(data, item_id)]]
	var worn := String(c.equipment.get(slot, ""))
	if worn != "":
		lines.append("Replaces your %s (%s)" % [_item_name(data, worn), Equipment.describe_stats(data, worn)])
	return lines


## Detail line for a combat talisman: its kind and power, and whether it is readied.
static func describe_talisman(c: CharacterData, data: GameData, item_id: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	match CombatTalismans.kind_of(data, item_id):
		"strike":
			lines.append("Strike talisman: deals %d damage at the start of a fight" % CombatTalismans.amount(data, item_id))
		"shield":
			lines.append("Shield talisman: absorbs %d damage in a fight" % CombatTalismans.amount(data, item_id))
		"escape":
			lines.append("Escape talisman: turns a defeat into a flight")
	if c.readied_talismans.has(item_id):
		lines.append("Readied: one burns in each fight while you carry it.")
	return lines


## "Readied for battle: A, B (2/3)" or a hint when no talisman is readied.
static func readied_summary(c: CharacterData, data: GameData) -> String:
	var names: PackedStringArray = []
	for item_id in c.readied_talismans:
		if c.item_count(item_id) > 0:
			names.append("%s x%d" % [_item_name(data, item_id), c.item_count(item_id)])
	if names.is_empty():
		return "No talismans readied for battle."
	return "Readied for battle: %s (%d/%d)" % [", ".join(names), names.size(), CombatTalismans.MAX_READIED]


static func _item_name(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("name", item_id))


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_readied.text = readied_summary(p, data)
	var ids := filtered_ids(p, data, _category)
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
	if ids.is_empty():
		_list.add_child(UIStyle.label("Nothing here." if _category != "All" else "Your pouch is empty.", 16, Color(0.7, 0.7, 0.7)))
	for item_id in ids:
		var label := "%s  x%d" % [_item_name(data, item_id), p.item_count(item_id)]
		if p.readied_talismans.has(item_id):
			label += "  (readied)"
		var b := UIStyle.button(label, _select.bind(item_id))
		b.name = item_id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = item_id == _selected
		b.focus_entered.connect(_select.bind(item_id))
		_list.add_child(b)
	_show_details()


func _select(item_id: String) -> void:
	if item_id == _selected:
		return
	_selected = item_id
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == item_id)
	_show_details()


func _show_details() -> void:
	var data := GameState.data
	var item: Dictionary = data.items.get(_selected, {})
	_name.text = _item_name(data, _selected) if _selected != "" else ""
	_description.text = String(item.get("description", ""))
	var lines := describe_effects(item.get("effects", {}), data)
	if int(item.get("price", 0)) > 0:
		lines.append("Market price: %d spirit stones" % int(item["price"]))
	var equippable := _selected != "" and Equipment.is_equipment(data, _selected)
	if equippable:
		lines.append_array(describe_equipment(GameState.player, data, _selected))
	var array := Abodes.array_def(data, _selected) if _selected != "" else {}
	if not array.is_empty():
		lines.append("Gathering array: +%d%% qi density in seclusion once set up at your abode" % roundi(float(array.get("qi_density_bonus", 0.0)) * 100.0))
	if _selected != "":
		for line in Appraisal.describe_item(GameState.player, data, _selected):
			lines.append("Appraisal: " + line)
	var talisman := _selected != "" and CombatTalismans.is_combat_talisman(data, _selected)
	if talisman:
		lines.append_array(describe_talisman(GameState.player, data, _selected))
	_effects.text = "\n".join(lines)
	_show_ready_button(talisman)
	_use_button.visible = bool(item.get("usable", false)) or equippable
	if _use_armed != _selected:
		_use_armed = ""
	_use_button.text = "Equip" if equippable else "Use"
	if _use_armed != "":
		_use_button.text = "%s? Press again" % _use_warning(_selected)
	# Show why an item can't be used now (e.g. nothing to heal) instead of a failed use.
	var reason := ""
	if equippable:
		reason = Equipment.check_equip(GameState.player, data, _selected)
	elif _use_button.visible:
		reason = Effects.check(GameState.player, data, item.get("effects", {}))
	_use_button.disabled = reason != ""
	_use_button.tooltip_text = reason
	if reason != "":
		_effects.text += "\n" + reason


func _show_ready_button(talisman: bool) -> void:
	_ready_button.visible = talisman
	if not talisman:
		return
	var readied := GameState.player.readied_talismans.has(_selected)
	_ready_button.text = "Put away" if readied else "Ready for battle"
	var reason := "" if readied else CombatTalismans.check_ready(GameState.player, GameState.data, _selected)
	_ready_button.disabled = reason != ""
	_ready_button.tooltip_text = reason
	if reason != "":
		_effects.text += "\n" + reason


func _toggle_ready() -> void:
	if _selected == "":
		return
	if GameState.player.readied_talismans.has(_selected):
		GameState.unready_talisman(_selected)
	else:
		GameState.ready_talisman(_selected)
	_ready_button.grab_focus.call_deferred()


func _use_selected() -> void:
	if _selected == "":
		return
	var warning := _use_warning(_selected)
	if warning != "" and _use_armed != _selected:
		_use_armed = _selected
		_use_button.text = "%s? Press again" % warning
		return
	_use_armed = ""
	if Equipment.is_equipment(GameState.data, _selected):
		GameState.equip_item(_selected)
	else:
		GameState.use_item(_selected)
	# player_changed has rebuilt the list; keep focus somewhere sensible.
	_focus_selected.call_deferred()


## What the selected item's Use/Equip would cost irreversibly ("" = nothing).
func _use_warning(item_id: String) -> String:
	var data := GameState.data
	if Equipment.is_equipment(data, item_id):
		var risk := Equipment.equip_warning(GameState.player, data, item_id)
		return "" if risk == "" else "Equip (%s)" % risk
	return Items.use_warning(data, item_id)


func _disarm_use() -> void:
	if _use_armed == "" or _use_button.has_focus():
		return
	_use_armed = ""
	_show_details()


func _focus_selected() -> void:
	var b := _list.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
