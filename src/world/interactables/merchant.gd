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


func get_options() -> Array[Dictionary]:
	if not Places.is_open({"open_days": open_days}, GameClock.total_days):
		return []
	var refusal := Items.check_merchant(GameState.player, min_alignment, max_alignment)
	if refusal != "":
		return [{"label": refusal, "action": Callable(), "disabled": true}]
	var options: Array[Dictionary] = [
		{"label": "Browse wares", "action": EventBus.shop_requested.emit.bind(display_name, max_price, stock_tags, faction, buy_tags)},
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
