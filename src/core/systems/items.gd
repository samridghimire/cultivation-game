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


## Whether a merchant stocking `stock_tags` (empty = untagged goods) up to
## `max_price` (0 = no limit) sells `item`. Items with a restricted tag
## (items.json "restricted_tags", e.g. demonic artifacts) are only sold by
## merchants that list that tag in their stock_tags.
static func merchant_sells(data: GameData, item: Dictionary, stock_tags: Array, max_price: int = 0) -> bool:
	var price := int(item.get("price", 0))
	if price <= 0 or (max_price > 0 and price > max_price):
		return false
	var tags: Array = item.get("tags", [])
	for tag in tags:
		if data.restricted_item_tags.has(tag) and not stock_tags.has(tag):
			return false
	if stock_tags.is_empty():
		return tags.is_empty()
	for tag in tags:
		if stock_tags.has(tag):
			return true
	return false


## Why a merchant that only deals with alignments in [min_alignment, max_alignment]
## refuses `c`, or "" if they will trade.
static func check_merchant(c: CharacterData, min_alignment: int, max_alignment: int) -> String:
	if c.alignment > max_alignment:
		return "The merchant eyes your righteous aura and claims to have nothing for sale."
	if c.alignment < min_alignment:
		return "The merchant will not trade with someone of your evil reputation."
	return ""


static func has_tag(data: GameData, item_id: String, tags: Array) -> bool:
	for tag in data.items.get(item_id, {}).get("tags", []):
		if tags.has(tag):
			return true
	return false


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
