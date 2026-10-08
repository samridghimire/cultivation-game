class_name Items
extends RefCounted
## Buying, selling and using items. Item definitions live in data/items.json.

## Merchants buy items back at this fraction of their price (see sell_price).
const SELL_RATE := 0.5


## Buys at a merchant affiliated with sect `faction` ("" = none), whose
## prices follow the buyer's reputation (Reputation.buy_price).
## Returns {ok, reason, stones}.
static func buy(c: CharacterData, data: GameData, item_id: String, quantity: int = 1, faction: String = "", market_mult: float = 1.0) -> Dictionary:
	var item: Dictionary = data.items.get(item_id, {})
	var price := Reputation.buy_price(c, data, item_id, faction, market_mult) * quantity
	if item.is_empty() or price <= 0:
		return {"ok": false, "reason": "That is not for sale."}
	if c.item_count("spirit_stone") < price:
		return {"ok": false, "reason": "You need %d spirit stones." % price}
	c.add_item("spirit_stone", -price)
	c.add_item(item_id, quantity)
	return {"ok": true, "reason": "", "stones": price}


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


## Where `item_id` can be had, as "Sold at <merchant> (<region>)" /
## "Gathered at <place> (<region>)" lines; "Found exploring" when no merchant
## or gather site has it (loot, rewards).
static func sources(data: GameData, item_id: String) -> Array[String]:
	var lines: Array[String] = []
	var item: Dictionary = data.items.get(item_id, {})
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			var kind: String = place.get("type", "")
			var where := "%s (%s)" % [place.get("display_name", kind), region.get("name", region["id"])]
			if kind == "merchant" and merchant_sells(data, item, place.get("stock_tags", []), int(place.get("max_price", 0))):
				lines.append("Sold at " + where)
			elif kind == "gather":
				for entry: Dictionary in place.get("gather_table", []):
					if entry.get("item", "") == item_id:
						lines.append("Gathered at " + where)
						break
	if lines.is_empty():
		lines.append("Found exploring")
	return lines


## Item ids a merchant stocking `stock_tags` up to `max_price` sells
## (merchant_sells), cheapest first.
static func shop_stock(data: GameData, max_price: int, stock_tags: Array) -> Array:
	var ids: Array = []
	for item: Dictionary in data.items.values():
		if merchant_sells(data, item, stock_tags, max_price):
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
