class_name Items
extends RefCounted
## Buying and using items. Item definitions live in data/items.json.


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
