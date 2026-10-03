class_name Items
extends RefCounted
## Buying, selling and using items. Item definitions live in data/items.json.

## Merchants buy items back at this fraction of their price.
const SELL_RATE := 0.5


## Returns {ok, reason}.
static func buy(c: CharacterData, data: GameData, item_id: String, quantity: int = 1) -> Dictionary:
	var item: Dictionary = data.items.get(item_id, {})
	var price := int(item.get("price", 0)) * quantity
	if item.is_empty() or price <= 0:
		return {"ok": false, "reason": "That is not for sale."}
	if c.item_count("spirit_stone") < price:
		return {"ok": false, "reason": "You need %d spirit stones." % price}
	c.add_item("spirit_stone", -price)
	c.add_item(item_id, quantity)
	return {"ok": true, "reason": ""}


static func has_tag(data: GameData, item_id: String, tags: Array) -> bool:
	for tag in data.items.get(item_id, {}).get("tags", []):
		if tags.has(tag):
			return true
	return false


## Item ids a merchant sells, cheapest first: priced items up to `max_price`
## (0 = no limit) that carry one of `stock_tags`, or untagged goods (pills,
## manuals) when `stock_tags` is empty.
static func shop_stock(data: GameData, max_price: int, stock_tags: Array) -> Array:
	var ids: Array = []
	for item: Dictionary in data.items.values():
		var price := int(item.get("price", 0))
		if price <= 0 or (max_price > 0 and price > max_price):
			continue
		var tags: Array = item.get("tags", [])
		if (tags.is_empty() if stock_tags.is_empty() else has_tag(data, item["id"], stock_tags)):
			ids.append(item["id"])
	ids.sort_custom(func(a, b): return _price_then_name(data, a, b))
	return ids


## Item ids `c` holds that a merchant with `stock_tags` buys back. Only
## specialist (tagged) merchants buy, and only goods matching their tags.
static func buyback_ids(c: CharacterData, data: GameData, stock_tags: Array) -> Array:
	var ids: Array = []
	if stock_tags.is_empty():
		return ids
	for item_id in c.inventory:
		if c.item_count(item_id) > 0 and has_tag(data, item_id, stock_tags) and sell_price(data, item_id) > 0:
			ids.append(item_id)
	ids.sort_custom(func(a, b): return _price_then_name(data, a, b))
	return ids


static func _price_then_name(data: GameData, a: String, b: String) -> bool:
	var pa := int(data.items[a].get("price", 0))
	var pb := int(data.items[b].get("price", 0))
	if pa != pb:
		return pa < pb
	return String(data.items[a]["name"]).naturalnocasecmp_to(String(data.items[b]["name"])) < 0


static func sell_price(data: GameData, item_id: String) -> int:
	return int(int(data.items.get(item_id, {}).get("price", 0)) * SELL_RATE)


## Returns {ok, reason, stones}.
static func sell(c: CharacterData, data: GameData, item_id: String, quantity: int = 1) -> Dictionary:
	var price := sell_price(data, item_id) * quantity
	if price <= 0 or item_id == "spirit_stone":
		return {"ok": false, "reason": "No one will buy that.", "stones": 0}
	if c.item_count(item_id) < quantity:
		return {"ok": false, "reason": "You do not have enough.", "stones": 0}
	c.add_item(item_id, -quantity)
	c.add_item("spirit_stone", price)
	return {"ok": true, "reason": "", "stones": price}


## Returns {ok, reason, notes}.
static func use(c: CharacterData, data: GameData, item_id: String, flags: Dictionary) -> Dictionary:
	var item: Dictionary = data.items.get(item_id, {})
	if item.is_empty() or not item.get("usable", false):
		return {"ok": false, "reason": "That cannot be used.", "notes": PackedStringArray()}
	if c.item_count(item_id) <= 0:
		return {"ok": false, "reason": "You have none left.", "notes": PackedStringArray()}
	var reason := Effects.check(c, data, item.get("effects", {}))
	if reason != "":
		return {"ok": false, "reason": reason, "notes": PackedStringArray()}
	c.add_item(item_id, -1)
	return {"ok": true, "reason": "", "notes": Effects.apply(c, data, item.get("effects", {}), flags)}
