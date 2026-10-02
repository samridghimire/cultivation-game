class_name InventoryScreen
extends PanelContainer
## Modal inventory: item list on the left, details and actions for the
## selected item on the right. Selection follows focus so it works on gamepad.

signal closed

var _list: VBoxContainer
var _name: Label
var _description: Label
var _effects: Label
var _use_button: Button
var _close_button: Button
var _selected := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel().get_theme_stylebox("panel"))
	custom_minimum_size = Vector2(760, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("Inventory", 24, UIStyle.ACCENT))

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
	details.add_child(_use_button)

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


## Item ids the player holds, sorted by display name.
static func sorted_item_ids(c: CharacterData, data: GameData) -> Array:
	var ids := c.inventory.keys()
	ids.sort_custom(func(a, b): return _item_name(data, a).naturalnocasecmp_to(_item_name(data, b)) < 0)
	return ids


## Human-readable summary of an effects dictionary (see Effects for the keys).
static func describe_effects(effects: Dictionary, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	if effects.has("qi"):
		lines.append("+%d qi" % int(effects["qi"]))
	if effects.has("breakthrough_bonus"):
		lines.append("+%d%% to your next breakthrough" % int(float(effects["breakthrough_bonus"]) * 100))
	if effects.has("burn_lifespan"):
		lines.append("WARNING: burns %d years of your lifespan!" % int(effects["burn_lifespan"]))
	if effects.has("extend_lifespan"):
		lines.append("+%d years of lifespan" % int(effects["extend_lifespan"]))
	if effects.has("alignment"):
		lines.append("Alignment %+d" % int(effects["alignment"]))
	for item_id in effects.get("items", {}):
		lines.append("%+d %s" % [int(effects["items"][item_id]), _item_name(data, item_id)])
	if effects.has("learn_technique"):
		var tech: TechniqueDef = data.techniques.get(String(effects["learn_technique"]))
		lines.append("Teaches the technique: %s" % (tech.name if tech != null else effects["learn_technique"]))
	if effects.has("heal_injury"):
		var injury_id := String(effects["heal_injury"])
		lines.append("Heals every injury" if injury_id == "all" else "Heals: %s" % Injuries.injury_name(data, injury_id))
	return lines


static func _item_name(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("name", item_id))


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := sorted_item_ids(p, data)
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
	if ids.is_empty():
		_list.add_child(UIStyle.label("Your pouch is empty.", 16, Color(0.7, 0.7, 0.7)))
	for item_id in ids:
		var b := UIStyle.button("%s  x%d" % [_item_name(data, item_id), p.item_count(item_id)], _select.bind(item_id))
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
	_effects.text = "\n".join(lines)
	_use_button.visible = bool(item.get("usable", false))
	# Show why an item can't be used now (e.g. nothing to heal) instead of a failed use.
	var reason := Effects.check(GameState.player, data, item.get("effects", {})) if _use_button.visible else ""
	_use_button.disabled = reason != ""
	_use_button.tooltip_text = reason
	if reason != "":
		_effects.text += "\n" + reason


func _use_selected() -> void:
	if _selected == "":
		return
	GameState.use_item(_selected)
	# player_changed has rebuilt the list; keep focus somewhere sensible.
	_focus_selected.call_deferred()


func _focus_selected() -> void:
	var b := _list.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
