extends Interactable
## A merchant. "Browse wares" opens the ShopScreen (Buy/Sell tabs); the stock
## rules live in Items.shop_stock / Items.buyback_ids. Merchants that stock
## tagged materials (herbs, ores) also buy them back. "Ask about rumors" tells
## of world events under way and the next auction (GameState.hear_rumors).

## Only stock items up to this price (0 = no limit).
@export var max_price := 0
## Only stock items with one of these tags. Empty = untagged goods (pills, manuals).
@export var stock_tags: Array = []
## Extra item tags this merchant buys back without selling them (e.g. a general trader taking herbs and ore).
@export var buy_tags: Array = []
## Only trades with players whose alignment is within these bounds (inclusive).
@export var min_alignment := -1000000
@export var max_alignment := 1000000
## Sect this merchant belongs to (data/sects.json id); prices follow your reputation with it.
@export var faction := ""
## Day-of-month ints this merchant is there (MARKET-002); empty = always. Closed: no menu entries.
@export var open_days: Array = []
## MARKET-008: {pool: [item ids], mult 1.2..2.0}; one pool item is bought at mult x on each open day (Places.wanted_today).
@export var wanted: Dictionary = {}
## MARKET-007: {pool: [{item, weight}], count}; today's picks are added to stock_tags when the shop opens.
@export var rotating_stock: Dictionary = {}


func get_options() -> Array[Dictionary]:
	if not Places.is_open({"open_days": open_days}, GameClock.total_days):
		return []
	var refusal := Items.check_merchant(GameState.player, min_alignment, max_alignment)
	if refusal != "":
		return [{"label": refusal, "action": Callable(), "disabled": true}]
	var tags_today: Array = Places.stock_tags_today({"display_name": display_name, "open_days": open_days, "stock_tags": stock_tags, "rotating_stock": rotating_stock}, GameClock.total_days)
	var want := Places.wanted_today({"display_name": display_name, "open_days": open_days, "rotating_stock": rotating_stock, "wanted": wanted}, GameClock.total_days)
	var buys_today: Array = buy_tags.duplicate()
	if not want.is_empty():
		buys_today.append(want["item"])
	var options: Array[Dictionary] = [
		{"label": "Browse wares", "action": EventBus.shop_requested.emit.bind(display_name, max_price, tags_today, faction, buys_today)},
		{"label": "Ask about rumors", "action": _ask_rumors},
	]
	var festival := GameState.festival_activity_here(stock_tags)
	if festival != "":
		options.append(festival_entry(festival))
	return options


## True while this merchant (by display_name) is the one teaching the player's first
## fighting style in `region_id` (WU-120): drives the scroll mark above it.
static func shows_manual_mark(c: CharacterData, data: GameData, region_id: String, merchant_name: String) -> bool:
	if c == null or data == null:
		return false
	var found := Guidance.first_combat_manual(c, data, region_id)
	return not found.is_empty() and String(found["merchant"]) == merchant_name


func _draw() -> void:
	super._draw()
	if GameState.player != null and shows_manual_mark(GameState.player, GameState.data, GameState.current_region, display_name):
		_draw_manual_mark()
	if shows_market_mark(open_days, rotating_stock, GameClock.total_days):
		_draw_market_mark()


## WU-445: true on a day this rotating-stock stall is open.
static func shows_market_mark(days: Array, rotating: Dictionary, today: int) -> bool:
	return Places.is_market_day_stall({"open_days": days, "rotating_stock": rotating}, today)


## Bunting flag on a pole at the stall's top-right corner plus a gold "new wares" sparkle (static, so reduce_motion-safe).
func _draw_market_mark() -> void:
	var pole := Vector2(size.x / 2.0 - 4.0, -size.y / 2.0)
	var gold := Color(1.0, 0.85, 0.3)
	draw_line(pole, pole + Vector2(0, -26), Color(0.4, 0.28, 0.16), 2.0)
	draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -26), pole + Vector2(16, -21), pole + Vector2(0, -16)]), Color(0.8, 0.2, 0.2))
	var s := pole + Vector2(-14, -22)
	draw_line(s + Vector2(-5, 0), s + Vector2(5, 0), gold, 2.0)
	draw_line(s + Vector2(0, -5), s + Vector2(0, 5), gold, 2.0)
	draw_circle(s, 2.0, Color(1, 1, 0.8))


## A small scroll above the merchant (placeholder art).
func _draw_manual_mark() -> void:
	var top := Vector2(0, -size.y / 2.0 - 34.0) + label_offset
	var paper := Color(0.93, 0.87, 0.68)
	draw_rect(Rect2(top + Vector2(-8, -6), Vector2(16, 12)), paper)
	draw_rect(Rect2(top + Vector2(-10, -7), Vector2(3, 14)), UIStyle.ACCENT)
	draw_rect(Rect2(top + Vector2(7, -7), Vector2(3, 14)), UIStyle.ACCENT)
	draw_line(top + Vector2(-4, -2), top + Vector2(4, -2), UIStyle.ACCENT.darkened(0.4), 1.0)
	draw_line(top + Vector2(-4, 2), top + Vector2(4, 2), UIStyle.ACCENT.darkened(0.4), 1.0)


## Posts the gossip and shows it in a window you can read (WU-111).
func _ask_rumors() -> void:
	var lines := GameState.hear_rumors()
	if not lines.is_empty():  # empty means _can_act refused and already posted why
		EventBus.gossip_requested.emit(lines)


## "<activity> (festival)" for the festival activity under way here (WU-100); disabled with the
## check_festival_activity reason once taken part. Plays the festival chime on success.
func festival_entry(event_id: String) -> Dictionary:
	var activity := WorldEvents.activity_of(GameState.data, event_id)
	var reason := GameState.check_festival_activity(event_id)
	return {
		"label": "%s (festival)" % activity["name"],
		"description": String(activity["text"]),
		"action": _take_part.bind(event_id),
		"disabled": reason != "",
		"reason": reason,
		"keep_open": true,
	}


func _take_part(event_id: String) -> void:
	if GameState.check_festival_activity(event_id) != "":
		return
	GameState.festival_activity(event_id)
	Audio.play("chime_progress")
