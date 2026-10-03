extends Interactable
## Sells items with a price in data/items.json. Merchants that stock tagged
## materials (herbs, ores) also buy them back. "Browse wares" opens the
## ShopScreen; the stock rules live in Items.shop_stock / Items.buyback_ids.

## Only stock items up to this price (0 = no limit).
@export var max_price := 0
## Only stock items with one of these tags. Empty = untagged goods (pills, manuals).
@export var stock_tags: Array = []


func get_options() -> Array[Dictionary]:
	return [{"label": "Browse wares", "action": EventBus.shop_requested.emit.bind(display_name, max_price, stock_tags)}]
