extends Interactable
## Sells every item with a price in data/items.json.

## Only stock items up to this price (0 = no limit).
@export var max_price := 0


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for item: Dictionary in GameState.data.items.values():
		var price := int(item.get("price", 0))
		if price <= 0 or (max_price > 0 and price > max_price):
			continue
		options.append({
			"label": "Buy %s (%d spirit stones)" % [item["name"], price],
			"action": GameState.buy_item.bind(item["id"]),
			"disabled": GameState.player.item_count("spirit_stone") < price,
			"keep_open": true,
		})
	return options
