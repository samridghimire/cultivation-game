class_name ShopScreen
extends PanelContainer
## Modal merchant screen with Buy and Sell tabs: goods on the left; details,
## equipment comparison, a quantity stepper and the trade button on the right.
## Left/right on an item steps the quantity (works on a gamepad d-pad).
## Stock rules live in Items.shop_stock / Items.buyback_ids; trades go through
## GameState.buy_item / sell_item.

signal closed

const MAX_QUANTITY := 99

var _title: Label
var _stones: Label
var _buy_tab: Button
var _sell_tab: Button
var _list: VBoxContainer
var _name: Label
var _description: Label
var _effects: Label
var _compare: Label
var _quantity_label: Label
var _trade_button: Button
var _close_button: Button
var _max_price := 0
var _stock_tags: Array = []
var _selling := false
var _selected := ""
var _quantity := 1


func _init() -> void:
	var temp := UIStyle.panel()
	add_theme_stylebox_override("panel", temp.get_theme_stylebox("panel"))
	temp.free()
	custom_minimum_size = Vector2(800, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_stones = UIStyle.label("", 18)
	header.add_child(_stones)

	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	_buy_tab = UIStyle.button("Buy", _set_tab.bind(false))
	_buy_tab.name = "BuyTab"
	_buy_tab.toggle_mode = true
	tabs.add_child(_buy_tab)
	_sell_tab = UIStyle.button("Sell", _set_tab.bind(true))
	_sell_tab.name = "SellTab"
	_sell_tab.toggle_mode = true
	tabs.add_child(_sell_tab)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 380)
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
	_description = _wrapped(UIStyle.label("", 16))
	details.add_child(_description)
	_effects = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["progress"]))
	details.add_child(_effects)
	_compare = _wrapped(UIStyle.label("", 15, Color(0.75, 0.75, 0.75)))
	details.add_child(_compare)
	var stepper := HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 8)
	details.add_child(stepper)
	var less := UIStyle.button("<", _step.bind(-1))
	less.focus_mode = Control.FOCUS_NONE
	stepper.add_child(less)
	_quantity_label = UIStyle.label("", 18)
	stepper.add_child(_quantity_label)
	var more := UIStyle.button(">", _step.bind(1))
	more.focus_mode = Control.FOCUS_NONE
	stepper.add_child(more)
	_trade_button = UIStyle.button("", _trade)
	_trade_button.name = "Trade"
	_trade_button.gui_input.connect(_on_item_input)
	details.add_child(_trade_button)
	details.add_child(UIStyle.label("Left/Right: change quantity", 14, Color(0.6, 0.6, 0.6)))

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


## Opens the merchant's wares (see merchant.gd for max_price / stock_tags).
func open(merchant_name: String = "Merchant", max_price: int = 0, stock_tags: Array = []) -> void:
	_title.text = merchant_name
	_max_price = max_price
	_stock_tags = stock_tags
	_selling = false
	_selected = ""
	_quantity = 1
	_rebuild()
	visible = true
	_focus_selected.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Item ids shown on the current tab.
func item_ids() -> Array:
	if _selling:
		return Items.buyback_ids(GameState.player, GameState.data, _stock_tags)
	return Items.shop_stock(GameState.data, _max_price, _stock_tags)


## Most of `item_id` that can be bought with `stones` or sold from `c`'s pouch.
static func max_quantity(c: CharacterData, data: GameData, item_id: String, selling: bool) -> int:
	if selling:
		return mini(c.item_count(item_id), MAX_QUANTITY)
	var price := int(data.items.get(item_id, {}).get("price", 0))
	return 0 if price <= 0 else mini(c.item_count("spirit_stone") / price, MAX_QUANTITY)


## "Equipped: Iron Sword (+5 attack)" for whatever `c` wears in the item's slot.
static func compare_text(c: CharacterData, data: GameData, item_id: String) -> String:
	if not Equipment.is_equipment(data, item_id):
		return ""
	var worn := String(c.equipment.get(Equipment.slot_of(data, item_id), ""))
	if worn == "":
		return "Your %s slot is empty." % Equipment.slot_of(data, item_id)
	return "Equipped: %s (%s)" % [data.items[worn]["name"], Equipment.describe_stats(data, worn)]


func _set_tab(selling: bool) -> void:
	_selling = selling
	_selected = ""
	_quantity = 1
	_rebuild()
	(_sell_tab if selling else _buy_tab).grab_focus()


func _rebuild() -> void:
	var p := GameState.player
	var data := GameState.data
	_stones.text = "Spirit Stones: %d" % p.item_count("spirit_stone")
	_buy_tab.set_pressed_no_signal(not _selling)
	_sell_tab.set_pressed_no_signal(_selling)
	_sell_tab.disabled = _stock_tags.is_empty()
	_sell_tab.tooltip_text = "This merchant buys nothing." if _stock_tags.is_empty() else ""
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := item_ids()
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
		_quantity = 1
	if ids.is_empty():
		var empty := "You have nothing this merchant wants." if _selling else "Nothing for sale."
		_list.add_child(UIStyle.label(empty, 16, Color(0.7, 0.7, 0.7)))
	for item_id in ids:
		var price := Items.sell_price(data, item_id) if _selling else int(data.items[item_id]["price"])
		var label := "%s  %d" % [data.items[item_id]["name"], price]
		if _selling:
			label += "  (have %d)" % p.item_count(item_id)
		var b := UIStyle.button(label, _select.bind(item_id))
		b.name = item_id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = item_id == _selected
		b.focus_entered.connect(_select.bind(item_id))
		b.gui_input.connect(_on_item_input)
		_list.add_child(b)
	_show_details()


func _select(item_id: String) -> void:
	if item_id == _selected:
		return
	_selected = item_id
	_quantity = 1
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == item_id)
	_show_details()


func _on_item_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		accept_event()


func _step(delta: int) -> void:
	if _selected == "":
		return
	var most := max_quantity(GameState.player, GameState.data, _selected, _selling)
	_quantity = clampi(_quantity + delta, 1, maxi(most, 1))
	_show_details()


func _show_details() -> void:
	var p := GameState.player
	var data := GameState.data
	var item: Dictionary = data.items.get(_selected, {})
	for c in [_name, _description, _effects, _compare, _quantity_label, _trade_button]:
		c.visible = not item.is_empty()
	if item.is_empty():
		return
	_name.text = item["name"]
	_description.text = String(item.get("description", ""))
	var lines := InventoryScreen.describe_effects(item.get("effects", {}), data)
	if Equipment.is_equipment(data, _selected):
		lines.insert(0, Equipment.describe_stats(data, _selected))
	_effects.text = "\n".join(lines)
	_compare.text = compare_text(p, data, _selected)
	_compare.visible = _compare.text != ""
	var most := max_quantity(p, data, _selected, _selling)
	_quantity = clampi(_quantity, 1, maxi(most, 1))
	var unit := Items.sell_price(data, _selected) if _selling else int(item["price"])
	_quantity_label.text = "x%d  (you have %d)" % [_quantity, p.item_count(_selected)]
	_trade_button.text = "%s %d for %d spirit stones" % ["Sell" if _selling else "Buy", _quantity, unit * _quantity]
	_trade_button.disabled = most < 1
	_trade_button.tooltip_text = "You cannot afford it." if most < 1 and not _selling else ""


func _trade() -> void:
	if _selected == "" or _trade_button.disabled:
		return
	if _selling:
		GameState.sell_item(_selected, _quantity)
	else:
		GameState.buy_item(_selected, _quantity)
	_quantity = 1
	_focus_selected.call_deferred()


func _focus_selected() -> void:
	var b := _list.get_node_or_null(NodePath(_selected)) as Button
	if b != null:
		b.grab_focus()
	elif _selling:
		_sell_tab.grab_focus()
	else:
		_close_button.grab_focus()
