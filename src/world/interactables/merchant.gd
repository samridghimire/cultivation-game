extends Interactable
## Sells items with a price in data/items.json. Merchants that stock tagged
## materials (herbs, ores) also buy them back.

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
	var options: Array[Dictionary] = []
	var data := GameState.data
	var refusal := Items.check_merchant(GameState.player, min_alignment, max_alignment)
	if refusal != "":
		options.append({"label": refusal, "action": Callable(), "disabled": true})
		return options
	var price_note := ""
	if not is_equal_approx(Reputation.price_multiplier(GameState.player, data, faction), 1.0):
		price_note = " (%s price)" % Reputation.tier_name(GameState.player, data, faction)
	for item: Dictionary in data.items.values():
		if not Items.merchant_sells(data, item, stock_tags, max_price):
			continue
		var price := Reputation.buy_price(GameState.player, data, item["id"], faction)
		options.append({
			"label": "Buy %s (%d spirit stones)%s" % [item["name"], price, price_note],
			"action": GameState.buy_item.bind(item["id"], faction),
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
