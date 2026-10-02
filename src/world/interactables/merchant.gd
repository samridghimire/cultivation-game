extends Interactable
## Sells items with a price in data/items.json. Merchants that stock tagged
## materials (herbs, ores) also buy them back.

## Only stock items up to this price (0 = no limit).
@export var max_price := 0
## Only stock items with one of these tags. Empty = untagged goods (pills, manuals).
@export var stock_tags: Array = []


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var data := GameState.data
	for item: Dictionary in data.items.values():
		var price := int(item.get("price", 0))
		if price <= 0 or (max_price > 0 and price > max_price) or not _stocks(item):
			continue
		options.append({
			"label": "Buy %s (%d spirit stones)" % [item["name"], price],
			"action": GameState.buy_item.bind(item["id"]),
			"disabled": GameState.player.item_count("spirit_stone") < price,
			"keep_open": true,
		})
	if not stock_tags.is_empty():
		for item_id in GameState.player.inventory:
			if Items.has_tag(data, item_id, stock_tags) and Items.sell_price(data, item_id) > 0:
				options.append({
					"label": "Sell %s (%d spirit stones, have %d)" % [data.items[item_id]["name"], Items.sell_price(data, item_id), GameState.player.item_count(item_id)],
					"action": GameState.sell_item.bind(item_id),
					"keep_open": true,
				})
	return options


func _stocks(item: Dictionary) -> bool:
	var tags: Array = item.get("tags", [])
	if stock_tags.is_empty():
		return tags.is_empty()
	for tag in tags:
		if stock_tags.has(tag):
			return true
	return false
