class_name ShopScreen
extends PanelContainer
## Modal merchant screen with Buy and Sell tabs: goods on the left; details,
## equipment comparison, a quantity stepper and the trade button on the right.
## Left/right on an item steps the quantity (works on a gamepad d-pad).
## Stock rules live in Items.shop_stock / Items.buyback_ids; a faction merchant's
## prices follow your sect reputation (Reputation.buy_price). Trades go through
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
var _wanted: Label
var _recharge_warn: Label
var _quantity_label: Label
var _trade_button: Button
var _hint_label: Label
var _gear_note: Label
var _close_button: Button
var _max_price := 0
var _stock_tags: Array = []
var _buy_tags: Array = []
var _faction := ""
var _selling := false
var _selected := ""
var _cat_row: HBoxContainer
var _sell_all_button: Button
var _sell_all_note: Label
var _hinted := ""  # WU-318: the item the HUD's first hint names (gold "!" row)

## True after the first press of "Sell all loot", until focus leaves or the list changes.
var _sell_all_armed := false
## Selected category tab ("All" = everything); reset when switching Buy/Sell.
var _category := "All"
const LIST_WIDTH := 540  ## about 60% of the panel (WU-133)
const ROW_PADDING := 40  ## button margins + scrollbar
const MAX_STEP := 1000000  ## a step too big to be anything but "Max"

var _quantity := 1


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style())
	custom_minimum_size = Vector2(920, 0)
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title = UIStyle.label("", 24, UIStyle.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 200
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

	_cat_row = HBoxContainer.new()
	_cat_row.add_theme_constant_override("separation", 4)
	box.add_child(_cat_row)

	_sell_all_button = UIStyle.button("", _sell_all)
	_sell_all_button.name = "SellAll"
	_sell_all_button.focus_exited.connect(_disarm_sell_all.call_deferred)
	box.add_child(_sell_all_button)
	_sell_all_note = UIStyle.label("", 14, Color(0.7, 0.7, 0.7))
	_sell_all_note.name = "SellAllNote"
	_sell_all_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sell_all_note.visible = false
	box.add_child(_sell_all_note)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	box.add_child(columns)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(LIST_WIDTH, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(scroll)
	_gear_note = _wrapped(UIStyle.label("", 14, Color(0.7, 0.7, 0.7)))
	_gear_note.name = "GearNote"
	_gear_note.custom_minimum_size.x = LIST_WIDTH
	_gear_note.visible = false
	left.add_child(_gear_note)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var details := VBoxContainer.new()
	details.custom_minimum_size = Vector2(340, 0)
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
	_wanted = _wrapped(UIStyle.label("", 15, UIStyle.ACCENT))
	details.add_child(_wanted)
	_recharge_warn = _wrapped(UIStyle.label("", 15, UIStyle.CATEGORY_COLORS["warning"]))
	details.add_child(_recharge_warn)
	var stepper := HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 8)
	details.add_child(stepper)
	var less10 := UIStyle.button("-10", _step.bind(-10))
	less10.focus_mode = Control.FOCUS_NONE
	stepper.add_child(less10)
	var less := UIStyle.button("<", _step.bind(-1))
	less.focus_mode = Control.FOCUS_NONE
	stepper.add_child(less)
	_quantity_label = UIStyle.label("", 18)
	stepper.add_child(_quantity_label)
	var more := UIStyle.button(">", _step.bind(1))
	more.focus_mode = Control.FOCUS_NONE
	stepper.add_child(more)
	var more10 := UIStyle.button("+10", _step.bind(10))
	more10.focus_mode = Control.FOCUS_NONE
	stepper.add_child(more10)
	var most_button := UIStyle.button("Max", _step.bind(MAX_STEP))
	most_button.focus_mode = Control.FOCUS_NONE
	stepper.add_child(most_button)
	_trade_button = UIStyle.button("", _trade)
	_trade_button.name = "Trade"
	_trade_button.gui_input.connect(_on_item_input)
	details.add_child(_trade_button)
	_hint_label = UIStyle.label("", 14, Color(0.6, 0.6, 0.6))
	details.add_child(_hint_label)
	_refresh_hint()
	InputConfig.controls_changed.connect(_refresh_hint)

	_close_button = UIStyle.button("Close", close)
	box.add_child(_close_button)
	EventBus.player_changed.connect(func(): if visible: _rebuild())


func _refresh_hint() -> void:
	_hint_label.text = "Left/Right: change quantity. %s/%s or PgUp/PgDn: by 10" % [InputConfig.binding_label("toggle_techniques", true), InputConfig.binding_label("toggle_artifact", true)]


func _wrapped(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## WU-318: the item whose name appears in `hint` (the longest name wins) among `item_ids`; "" if none.
static func hinted_item(data: GameData, hint: String, item_ids: Array) -> String:
	var best := ""
	var best_len := 0
	for id in item_ids:
		var item_name := String(data.items[id]["name"])
		if item_name.length() > best_len and hint.contains(item_name):
			best = String(id)
			best_len = item_name.length()
	return best


## The HUD's first hint ("" when the shop has no HUD above it).
func _hud_hint() -> String:
	var node := get_parent()
	while node != null and not node.has_method("first_hint"):
		node = node.get_parent()
	return "" if node == null else String(node.call("first_hint"))


## Opens the merchant's wares (see merchant.gd for max_price / stock_tags / faction).
func open(merchant_name: String = "Merchant", max_price: int = 0, stock_tags: Array = [], faction: String = "", buy_tags: Array = []) -> void:
	_title.text = merchant_name + price_note(GameState.player, GameState.data, faction) + renown_note(GameState.player, GameState.data, GameState.current_region) + deal_note(GameState.player, GameState.current_region, GameClock.total_days)
	_max_price = max_price
	_stock_tags = stock_tags
	_buy_tags = buy_tags
	_faction = faction
	_refresh_hint()
	_selling = false
	_category = "All"
	_hinted = hinted_item(GameState.data, _hud_hint(), item_ids())
	_selected = _hinted
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
		return Items.buyback_ids(GameState.player, GameState.data, _stock_tags, _buy_tags)
	var ids := Items.shop_stock(GameState.data, _max_price, _stock_tags)
	for item_id: Variant in GameState.festival_stock(_stock_tags):
		if not ids.has(item_id):
			ids.append(item_id)
	return ids


## Item ids on the current Buy/Sell tab that fall in the selected category.
func visible_ids() -> Array:
	return filter_by_category(GameState.data, item_ids(), _category)


## Categories (Items.CATEGORIES order, "All" first) that have a row in `ids`.
static func categories_in(data: GameData, ids: Array) -> Array[String]:
	var found: Array[String] = ["All"]
	for cat in Items.CATEGORIES:
		if cat != "All" and not filter_by_category(data, ids, cat).is_empty():
			found.append(cat)
	return found


static func filter_by_category(data: GameData, ids: Array, category: String) -> Array:
	if category == "All":
		return ids
	return ids.filter(func(id): return Items.category(data.items.get(id, {})) == category)


func _set_category(cat: String) -> void:
	_category = cat
	_selected = ""
	_quantity = 1
	_rebuild()
	_focus_selected.call_deferred()


## " (Honored price)" when `faction`'s reputation changes `c`'s prices, else "".
static func price_note(c: CharacterData, data: GameData, faction: String) -> String:
	if is_equal_approx(Reputation.price_multiplier(c, data, faction), 1.0):
		return ""
	return " (%s price)" % Reputation.tier_name(c, data, faction)


## "  Renown: Respected (-5%)" when local renown discounts buying in `region_id`, else "".
static func renown_note(c: CharacterData, data: GameData, region_id: String) -> String:
	var mult := Renown.buy_multiplier(c, data, region_id)
	if mult >= 1.0:
		return ""
	return "  Renown: %s (-%d%%)" % [Renown.title(c, data, region_id), roundi((1.0 - mult) * 100.0)]


## "  A friend's price: -20% (12 days left)" while a friend's price holds in `region_id`, else "".
static func deal_note(c: CharacterData, region_id: String, today: int) -> String:
	var mult := Letters.deal_multiplier(c, region_id, today)
	if mult >= 1.0:
		return ""
	var left: int = int(c.shop_deals[region_id]["until"]) - today
	return "  A friend's price: -%d%% (%d days left)" % [roundi((1.0 - mult) * 100.0), left]


## Price of one `item_id` on the current tab.
## `market_mult`: the region's world-event price multiplier (GameState.buy_multiplier: world events and local renown; buying only).
static func unit_price(c: CharacterData, data: GameData, item_id: String, selling: bool, faction: String = "", market_mult: float = 1.0) -> int:
	return Items.sell_price(data, item_id) if selling else Reputation.buy_price(c, data, item_id, faction, market_mult)


## Most of `item_id` that `c` can buy with their stones or sell from their pouch.
@warning_ignore("integer_division")
static func max_quantity(c: CharacterData, data: GameData, item_id: String, selling: bool, faction: String = "", market_mult: float = 1.0) -> int:
	if selling:
		return mini(c.item_count(item_id), MAX_QUANTITY)
	var price := unit_price(c, data, item_id, false, faction, market_mult)
	return 0 if price <= 0 else mini(c.item_count("spirit_stone") / price, MAX_QUANTITY)


## The technique id an item's `learn_technique` effect names, or "" (WU-118).
static func manual_technique(data: GameData, item_id: String) -> String:
	return Items.manual_technique(data, item_id)


static func kind_word(kind: String) -> String:
	match kind:
		"combat":
			return "fighting style"
		"method":
			return "cultivation method"
		"body":
			return "body art"
		"cultivation":
			return "breathing art"
	return kind


## " (known)" / " (fighting style)" suffix for a manual's shop row; "" for other items.
static func manual_note(c: CharacterData, data: GameData, item_id: String) -> String:
	var tech_id := manual_technique(data, item_id)
	if tech_id == "":
		return ""
	if Techniques.knows(c, tech_id):
		return " (known)"
	return " (%s)" % kind_word(data.techniques[tech_id].kind)


## True when `text` fits a shop row at the button font size (WU-133).
static func row_fits(text: String) -> bool:
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	return w <= LIST_WIDTH - ROW_PADDING


## True when `item_id` is a combat manual and `c` knows no combat technique yet.
static func is_first_combat_manual(c: CharacterData, data: GameData, item_id: String) -> bool:
	var tech_id := manual_technique(data, item_id)
	if tech_id == "" or data.techniques[tech_id].kind != "combat":
		return false
	return not Techniques.knows_kind(c, data, "combat")


## The stat that makes gear better in its slot: attack for weapons, defense for armor.
static func slot_stat(slot: String) -> String:
	return "attack" if slot == "weapon" else "defense"


## WU-244: "upgrade" for affordable gear that beats what `c` wears (no equip stat lower, one higher; WU-254), "defence" for a body-art manual a
## Foundation-or-higher cultivator lacks, else "". `faction` is the shop's, so its discount counts.
static func upgrade_tag(c: CharacterData, data: GameData, item_id: String, faction: String = "") -> String:
	if Equipment.is_equipment(data, item_id):
		var slot := Equipment.slot_of(data, item_id)
		var worn := String(c.equipment.get(slot, ""))
		var worn_stats: Dictionary = {} if worn == "" else data.items[worn].get("equip", {}).get("stats", {})
		var stats: Dictionary = data.items[item_id].get("equip", {}).get("stats", {})
		var higher := false
		for stat in ["attack", "defense", "max_hp", "speed"]:
			var val := int(stats.get(stat, 0))
			var worn_val := int(worn_stats.get(stat, 0))
			if val < worn_val:
				return ""
			if val > worn_val:
				higher = true
		if higher and c.item_count("spirit_stone") >= unit_price(c, data, item_id, false, faction, GameState.buy_multiplier()):
			return "upgrade"
		return ""
	var tech_id := manual_technique(data, item_id)
	if tech_id != "" and data.techniques[tech_id].kind == "body" and not Techniques.knows(c, tech_id) \
			and c.realm_index >= data.realm_index_of("foundation_establishment"):
		return "defence"
	return ""


## Short row suffix for an upgrade or body-art defence tag.
static func tag_note(tag: String) -> String:
	if tag == "upgrade":
		return " (upgrade)"
	if tag == "defence":
		return "  (defence)"
	return ""


## What a qi item is worth in meditation (WU-314); "" when selling or the item gives no qi.
static func buy_worth_line(c: CharacterData, data: GameData, item_id: String, region_id: String, flags: Dictionary, selling: bool) -> String:
	if selling:
		return ""
	var worth := InventoryScreen.qi_worth_line(c, data, item_id, region_id, flags)
	return worth + " each" if worth != "" else ""


## WU-312: the Sell tab says when a sect mission wants the selected item.
static func sell_wanted_line(c: CharacterData, data: GameData, item_id: String, selling: bool, flags: Dictionary = {}) -> String:
	if not selling:
		return ""
	return InventoryScreen.wanted_by_sect_line(c, data, item_id, flags)


## "Equipped: Iron Sword (+5 attack)" for whatever `c` wears in the item's slot.
## At low artifact lives: a warning when paying `price` is what puts the recharge out of reach.
static func recharge_warning(c: CharacterData, data: GameData, price: int) -> String:
	if c.artifact_lives < 0 or c.artifact_lives > Guidance.LOW_ARTIFACT_LIVES:
		return ""
	var cost := CreationArtifact.recharge_cost(c, data)
	var stones := c.item_count("spirit_stone")
	if stones < cost or stones - price >= cost:
		return ""
	return "This leaves %d stones; recharging your Creation Artifact costs %d." % [stones - price, cost]


static func compare_text(c: CharacterData, data: GameData, item_id: String) -> String:
	var tech_id := manual_technique(data, item_id)
	if tech_id != "":
		var tech_name: String = data.techniques[tech_id].name
		if Techniques.knows(c, tech_id):
			return "Teaches %s. You already know it." % tech_name
		return "Teaches %s, a %s you do not know yet." % [tech_name, kind_word(data.techniques[tech_id].kind)]
	if not Equipment.is_equipment(data, item_id):
		return ""
	var worn := String(c.equipment.get(Equipment.slot_of(data, item_id), ""))
	if worn == "":
		return "Your %s slot is empty." % Equipment.slot_of(data, item_id)
	return "Equipped: %s (%s)" % [data.items[worn]["name"], Equipment.describe_stats(data, worn)]


func _set_tab(selling: bool) -> void:
	_selling = selling
	_category = "All"
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
	var buys := not (_stock_tags.is_empty() and _buy_tags.is_empty())
	_sell_tab.disabled = not buys
	_sell_tab.tooltip_text = "This merchant buys nothing." if not buys else ""
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var all_ids := item_ids()
	var cats := categories_in(data, all_ids)
	if not cats.has(_category):
		_category = "All"
	for child in _cat_row.get_children():
		_cat_row.remove_child(child)
		child.queue_free()
	_cat_row.visible = cats.size() > 2
	for cat in cats:
		var tb := UIStyle.button(cat, _set_category.bind(cat))
		tb.name = "Cat" + cat.replace(" ", "").replace("&", "")
		tb.toggle_mode = true
		tb.set_pressed_no_signal(cat == _category)
		_cat_row.add_child(tb)
	var ids := filter_by_category(data, all_ids, _category)
	_refresh_sell_all()
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
		_quantity = 1
	if ids.is_empty():
		var empty := "Nothing here."
		if _category == "All":
			empty = "You have nothing this merchant wants." if _selling else "Nothing for sale."
		_list.add_child(UIStyle.label(empty, 16, Color(0.7, 0.7, 0.7)))
	for item_id in ids:
		var price := unit_price(p, data, item_id, _selling, _faction, GameState.buy_multiplier())
		var label := "%s  %d" % [data.items[item_id]["name"], price]
		if _selling:
			label += "  (have %d)" % p.item_count(item_id)
		else:
			var note := manual_note(p, data, item_id)
			if row_fits(label + note):
				label += note
			var tag_text := tag_note(upgrade_tag(p, data, item_id, _faction))
			if tag_text != "" and row_fits(label + tag_text):
				label += tag_text
		if not _selling and GameState.festival_stock(_stock_tags).has(item_id) and not Items.shop_stock(data, _max_price, _stock_tags).has(item_id):
			label += " (festival)"
		if not _selling and item_id == _hinted:
			label = "! " + label
		var b := UIStyle.button(label, _select.bind(item_id))
		b.name = item_id
		if not _selling and item_id == _hinted:
			b.add_theme_color_override("font_color", UIStyle.ACCENT)
		if not _selling and is_first_combat_manual(p, data, item_id):
			b.add_theme_color_override("font_color", UIStyle.ACCENT)
		elif not _selling and upgrade_tag(p, data, item_id, _faction) != "":
			b.add_theme_color_override("font_color", UIStyle.ACCENT)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = label
		b.toggle_mode = true
		b.button_pressed = item_id == _selected
		b.focus_entered.connect(_select.bind(item_id))
		b.gui_input.connect(_on_item_input)
		_list.add_child(b)
	var gear_line := "" if _selling else Guidance.gear_elsewhere_line(p, data, GameState.current_region)
	_gear_note.text = gear_line
	_gear_note.visible = gear_line != ""
	_show_details()


func _loot_ids() -> Array:
	return Items.bulk_sell_ids(GameState.player, GameState.data, _stock_tags, _buy_tags, Sects.deliver_needs(GameState.player, GameState.data, GameState.world_flags))


func _refresh_sell_all() -> void:
	var loot := _loot_ids()
	var total := Items.bulk_sell_total(GameState.player, GameState.data, loot)
	_sell_all_button.visible = _selling and total > 0
	_sell_all_note.visible = _sell_all_button.visible
	if not _sell_all_button.visible:
		_sell_all_armed = false
		return
	var count := 0
	for id in loot:
		count += GameState.player.item_count(id)
	_sell_all_note.text = sell_all_summary(GameState.player, GameState.data, loot)
	var kept := kept_text(GameState.player, GameState.data, _stock_tags, _buy_tags)
	if kept != "":
		_sell_all_note.text += "\n" + kept
	if _sell_all_armed:
		_sell_all_button.text = "Press again to sell %d items for %d stones" % [count, total]
	else:
		_sell_all_button.text = "Sell all loot (%d stones)" % total


## "Sells: 6 Mist Wolf Pelt, 3 Iron Essence and 4 more kinds": the three most valuable stacks.
static func sell_all_summary(c: CharacterData, data: GameData, ids: Array) -> String:
	var sorted := ids.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool:
		return Items.sell_price(data, a) * c.item_count(a) > Items.sell_price(data, b) * c.item_count(b))
	var parts: Array[String] = []
	for id: String in sorted.slice(0, 3):
		parts.append("%d %s" % [c.item_count(id), Items.item_plural(data, id, c.item_count(id))])
	var text := "Sells: " + ", ".join(parts)
	var rest := sorted.size() - parts.size()
	if rest > 0:
		text += " and %d more kind%s" % [rest, "" if rest == 1 else "s"]
	return text


## "Kept: 3 Spirit Herbs (they feed your cultivation)": sellable stacks Sell all leaves alone
## because using them gives qi. "" when there are none.
static func kept_text(c: CharacterData, data: GameData, stock_tags: Array, buy_tags: Array = []) -> String:
	var worn: Array = c.equipment.values()
	var parts: Array[String] = []
	for id: String in Items.buyback_ids(c, data, stock_tags, buy_tags):
		if not worn.has(id) and Items.feeds_cultivation(data, id):
			parts.append("%d %s" % [c.item_count(id), Items.item_plural(data, id, c.item_count(id))])
	if parts.is_empty():
		return ""
	return "Kept: %s (they feed your cultivation)" % ", ".join(parts)


func _sell_all() -> void:
	if not _sell_all_armed:
		_sell_all_armed = true
		_refresh_sell_all()
		return
	_sell_all_armed = false
	GameState.sell_all(_loot_ids())
	_focus_selected.call_deferred()


func _disarm_sell_all() -> void:
	if _sell_all_armed and not _sell_all_button.has_focus():
		_sell_all_armed = false
		_refresh_sell_all()


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
	elif _is_ten_step(event, false):
		_step(-10)
		accept_event()
	elif _is_ten_step(event, true):
		_step(10)
		accept_event()


## The shoulder actions (LB/RB by default) or PageUp/PageDown step the quantity by 10.
func _is_ten_step(event: InputEvent, up: bool) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	return event.is_action_pressed("toggle_artifact" if up else "toggle_techniques") \
			or event.is_action_pressed("ui_page_down" if up else "ui_page_up")


func _step(delta: int) -> void:
	if _selected == "":
		return
	var most := max_quantity(GameState.player, GameState.data, _selected, _selling, _faction, GameState.buy_multiplier())
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
	if not _selling:
		var note := manual_note(p, data, _selected)
		var base := "%s  %d" % [item["name"], unit_price(p, data, _selected, false, _faction, GameState.buy_multiplier())]
		if note != "" and not row_fits(base + note):
			_name.text += note
	_description.text = String(item.get("description", ""))
	var lines := Items.describe_effects(item.get("effects", {}), data)
	if Equipment.is_equipment(data, _selected):
		lines.insert(0, Equipment.describe_stats(data, _selected))
	var worth := buy_worth_line(p, data, _selected, GameState.current_region, GameState.world_flags, _selling)
	if worth != "":
		lines.append(worth)
	_effects.text = "\n".join(lines)
	for line in Appraisal.describe_item(p, data, _selected):
		lines.append("Appraisal: " + line)
	_effects.text = "\n".join(lines)
	_compare.text = compare_text(p, data, _selected)
	_compare.visible = _compare.text != ""
	_wanted.text = sell_wanted_line(p, data, _selected, _selling, GameState.world_flags)
	_wanted.visible = _wanted.text != ""
	var most := max_quantity(p, data, _selected, _selling, _faction, GameState.buy_multiplier())
	_quantity = clampi(_quantity, 1, maxi(most, 1))
	var unit := unit_price(p, data, _selected, _selling, _faction, GameState.buy_multiplier())
	_quantity_label.text = "x%d  (you have %d)" % [_quantity, p.item_count(_selected)]
	_recharge_warn.text = "" if _selling else recharge_warning(p, data, unit * _quantity)
	_recharge_warn.visible = _recharge_warn.text != ""
	_trade_button.text = "%s %d for %d spirit stones" % ["Sell" if _selling else "Buy", _quantity, unit * _quantity]
	_trade_button.disabled = most < 1
	_trade_button.tooltip_text = "You cannot afford it." if most < 1 and not _selling else ""


func _trade() -> void:
	if _selected == "" or _trade_button.disabled:
		return
	if _selling:
		GameState.sell_item(_selected, _quantity)
	else:
		GameState.buy_item(_selected, _faction, _quantity)
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
