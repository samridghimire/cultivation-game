class_name Items
extends RefCounted
## Buying, selling and using items. Item definitions live in data/items.json.

## Merchants buy items back at this fraction of their price (see sell_price).
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


## Merchants buy items back at SELL_RATE of their price. Crafted goods (the
## output of any recipe) are also capped at their material cost per unit times
## recipes.json alchemy.crafted_sell_markup, so crafting cheap materials into
## pricey talismans or gear is a modest trade, not a money press.
static func sell_price(data: GameData, item_id: String) -> int:
	var price := int(int(data.items.get(item_id, {}).get("price", 0)) * SELL_RATE)
	var material := material_value(data, item_id)
	if price <= 0 or material < 0.0:
		return price
	var markup := float(data.alchemy.get("crafted_sell_markup", 1.3))
	return clampi(ceili(material * markup), 1, price)


## Spirit-stone value of the ingredients behind one unit of a crafted item
## (cheapest recipe that outputs it), or -1.0 if no
## recipe makes it. Ingredients use their shop price.
static func material_value(data: GameData, item_id: String) -> float:
	var best := -1.0
	for recipe: Dictionary in data.recipes.values():
		# The normal output sets the yield; great_output only counts for an item
		# made solely by great successes (e.g. a higher-grade pill).
		var count := 0
		for key in ["great_output", "output"]:
			var output: Dictionary = recipe.get(key, {})
			if output.get("item", "") == item_id:
				count = int(output.get("count", 1))
		if count <= 0:
			continue
		var cost := 0
		var ingredients: Dictionary = recipe.get("ingredients", {})
		for ingredient in ingredients:
			cost += int(data.items.get(ingredient, {}).get("price", 0)) * int(ingredients[ingredient])
		var per_unit := float(cost) / count
		if best < 0.0 or per_unit < best:
			best = per_unit
	return best


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
