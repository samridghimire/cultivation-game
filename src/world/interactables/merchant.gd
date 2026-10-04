extends Interactable
## A merchant. "Browse wares" opens the ShopScreen (Buy/Sell tabs); the stock
## rules live in Items.shop_stock / Items.buyback_ids. Merchants that stock
## tagged materials (herbs, ores) also buy them back. "Ask about rumors" tells
## of world events under way and the next auction (GameState.hear_rumors).

## Only stock items up to this price (0 = no limit).
@export var max_price := 0
## Only stock items with one of these tags. Empty = untagged goods (pills, manuals).
@export var stock_tags: Array = []
## Only trades with players whose alignment is within these bounds (inclusive).
@export var min_alignment := -1000000
@export var max_alignment := 1000000
## Sect this merchant belongs to (data/sects.json id); prices follow your reputation with it.
@export var faction := ""


func get_options() -> Array[Dictionary]:
	var refusal := Items.check_merchant(GameState.player, min_alignment, max_alignment)
	if refusal != "":
		return [{"label": refusal, "action": Callable(), "disabled": true}]
	return [
		{"label": "Browse wares", "action": EventBus.shop_requested.emit.bind(display_name, max_price, stock_tags, faction)},
		{"label": "Ask about rumors", "action": GameState.hear_rumors, "keep_open": true},
	]
