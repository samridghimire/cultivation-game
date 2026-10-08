class_name AuctionScreen
extends PanelContainer
## Modal auction house screen (AUC-001b): when no auction is held, the date of
## the next one; while one is open, its lots on the left (rarity colored, sold
## lots marked) and the selected lot's item details, opening bid and a sealed
## bid amount on the right. Left/right steps the bid (gamepad d-pad friendly);
## "Place sealed bid" calls GameState.bid with GameState.check_bid reasons.

signal closed

const RARITY_COLORS := {
	"common": Color("dddddd"),
	"uncommon": Color("8fd18a"),
	"rare": Color("6fa8e8"),
	"epic": Color("b58ae8"),
	"legendary": Color("e8a04a"),
}

var _title: Label
var _status: Label
var _list: VBoxContainer
var _name: Label
var _description: Label
var _effects: Label
var _bid_label: Label
var _reason: Label
var _bid_button: Button
var _close_button: Button
var _house_id := ""
## Selected lot index (-1 = none).
var _selected := -1
## The bid amount for the selected lot.
var _amount := 0


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(780, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	box.add_child(_title)
	_status = _wrapped(UIStyle.label("", 16, Color(0.8, 0.8, 0.8)))
	box.add_child(_status)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 340)
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
	var stepper := HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 8)
	details.add_child(stepper)
	var less := UIStyle.button("<", _step.bind(-1))
	less.focus_mode = Control.FOCUS_NONE
	stepper.add_child(less)
	_bid_label = UIStyle.label("", 18)
	stepper.add_child(_bid_label)
	var more := UIStyle.button(">", _step.bind(1))
	more.focus_mode = Control.FOCUS_NONE
	stepper.add_child(more)
	_bid_button = UIStyle.button("Place sealed bid", _bid)
	_bid_button.name = "Bid"
	_bid_button.gui_input.connect(_on_lot_input)
	details.add_child(_bid_button)
	_reason = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["warning"]))
	details.add_child(_reason)
	details.add_child(UIStyle.label("Left/Right: change your bid. One sealed bid per lot.", 14, Color(0.6, 0.6, 0.6)))
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


func open(house_id: String) -> void:
	_house_id = house_id
	_selected = -1
	_rebuild()
	visible = true
	_focus_selected.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## "Auction open: closes in 5 days" or "Next auction opens in 3 weeks".
static func status_text(def: Dictionary, total_days: int) -> String:
	if Auctions.is_open(def, total_days):
		return "auction open, closes in %s" % Calendar.format_duration(Auctions.days_until_close(def, total_days))
	return "next auction opens in %s" % Calendar.format_duration(Auctions.days_until_open(def, total_days))


## "Star Silver x2  [uncommon]  from 300", with how a sold lot went.
static func lot_label(data: GameData, lot: Dictionary) -> String:
	var name := String(data.items.get(String(lot["item"]), {}).get("name", lot["item"]))
	if int(lot.get("count", 1)) > 1:
		name += " x%d" % int(lot["count"])
	var text := "%s  [%s]  from %d" % [name, lot.get("rarity", "common"), int(lot["base_price"])]
	match String(lot.get("sold", "")):
		"player":
			text += "  (yours, %d)" % int(lot.get("price", 0))
		"npc":
			text += "  (sold to a rival, %d)" % int(lot.get("price", 0))
	return text


## Bid step for a lot: 5% of the opening bid, at least 1 spirit stone.
static func bid_step(lot: Dictionary) -> int:
	return maxi(1, roundi(int(lot["base_price"]) * 0.05))


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)


func _lots() -> Array:
	return GameState.auction_lots(_house_id)


func _rebuild() -> void:
	var data := GameState.data
	var def := Auctions.house(data, _house_id)
	_title.text = String(def.get("name", "Auction House"))
	var lots := _lots()
	_status.text = "%s. %s\nYou carry %d spirit stones." % [String(def.get("description", "")), status_text(def, GameClock.total_days).capitalize(), GameState.player.item_count("spirit_stone")]
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if lots.is_empty():
		_list.add_child(_wrapped(UIStyle.label("The hall is empty. Come back when the next auction opens.", 16, Color(0.7, 0.7, 0.7))))
		_selected = -1
	elif _selected < 0 or _selected >= lots.size():
		_selected = 0
		for i in lots.size():
			if String(lots[i].get("sold", "")) == "":
				_selected = i
				break
		_amount = int(lots[_selected]["base_price"])
	for i in lots.size():
		var lot: Dictionary = lots[i]
		var b := UIStyle.button(lot_label(data, lot), _select.bind(i))
		b.name = "lot_%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = i == _selected
		b.focus_entered.connect(_select.bind(i))
		b.gui_input.connect(_on_lot_input)
		UIStyle.tint_button_text(b, rarity_color(String(lot.get("rarity", "common"))))
		if String(lot.get("sold", "")) != "":
			b.modulate = Color(1, 1, 1, 0.6)
		_list.add_child(b)
	_show_details()


func _select(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	var lots := _lots()
	if index >= 0 and index < lots.size():
		_amount = int(lots[index]["base_price"])
	for b in _list.get_children():
		if b is Button:
			b.set_pressed_no_signal(b.name == "lot_%d" % index)
	_show_details()


func _on_lot_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		accept_event()


func _step(delta: int) -> void:
	var lots := _lots()
	if _selected < 0 or _selected >= lots.size():
		return
	var lot: Dictionary = lots[_selected]
	_amount = maxi(int(lot["base_price"]), _amount + delta * bid_step(lot))
	_show_details()


func _show_details() -> void:
	var data := GameState.data
	var lots := _lots()
	var has_lot := _selected >= 0 and _selected < lots.size()
	for c in [_name, _description, _effects, _bid_label, _bid_button, _reason]:
		c.visible = has_lot
	if not has_lot:
		return
	var lot: Dictionary = lots[_selected]
	var item_id := String(lot["item"])
	var item: Dictionary = data.items.get(item_id, {})
	_name.text = String(item.get("name", item_id))
	_name.add_theme_color_override("font_color", rarity_color(String(lot.get("rarity", "common"))))
	_description.text = String(item.get("description", ""))
	var lines := Items.describe_effects(item.get("effects", {}), data)
	if Equipment.is_equipment(data, item_id):
		lines.append_array(InventoryScreen.describe_equipment(GameState.player, data, item_id))
	if CombatTalismans.is_combat_talisman(data, item_id):
		lines.append_array(InventoryScreen.describe_talisman(GameState.player, data, item_id))
	lines.append("%s lot of %d. Opening bid: %d spirit stones." % [String(lot.get("rarity", "common")).capitalize(), int(lot.get("count", 1)), int(lot["base_price"])])
	if int(item.get("price", 0)) > 0:
		lines.append("Market price: %d spirit stones each" % int(item["price"]))
	_effects.text = "\n".join(lines)
	_bid_label.text = "Your bid: %d" % _amount
	var reason := GameState.check_bid(_house_id, _selected, _amount)
	_reason.text = reason
	_reason.visible = reason != ""
	_bid_button.disabled = reason != ""


func _bid() -> void:
	if _selected < 0:
		return
	GameState.bid(_house_id, _selected, _amount)
	if visible:
		_focus_selected.call_deferred()


func _focus_selected() -> void:
	if not visible:
		return
	var b := _list.get_node_or_null("lot_%d" % _selected) as Button
	if b != null:
		b.grab_focus()
	else:
		_close_button.grab_focus()
