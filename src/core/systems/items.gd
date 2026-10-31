class_name Items
extends RefCounted
## Buying, selling and using items. Item definitions live in data/items.json.

## Merchants buy items back at this fraction of their price (see sell_price).
const SELL_RATE := 0.5


## Human-readable summary of an effects dictionary (see Effects for the keys).
## Never prints raw ids.
static func describe_effects(effects: Dictionary, data: GameData) -> PackedStringArray:
	var lines: PackedStringArray = []
	if effects.has("qi"):
		lines.append("+%d qi" % int(effects["qi"]))
	if effects.has("breakthrough_bonus"):
		lines.append("+%d%% to your next breakthrough" % int(float(effects["breakthrough_bonus"]) * 100))
	if effects.has("burn_lifespan"):
		lines.append("WARNING: burns %d years of your lifespan!" % int(effects["burn_lifespan"]))
	if effects.has("extend_lifespan"):
		lines.append("+%d years of lifespan" % int(effects["extend_lifespan"]))
	if effects.has("alignment"):
		lines.append("Alignment %+d" % int(effects["alignment"]))
	for sect_id in effects.get("reputation", {}):
		var sect: SectDef = data.sects.get(String(sect_id))
		lines.append("%+d standing with %s" % [int(effects["reputation"][sect_id]), sect.name if sect != null else "a sect"])
	for item_id in effects.get("items", {}):
		lines.append("%+d %s" % [int(effects["items"][item_id]), String(data.items.get(item_id, {}).get("name", "item"))])
	if effects.has("learn_technique"):
		var tech: TechniqueDef = data.techniques.get(String(effects["learn_technique"]))
		lines.append("Teaches the technique: %s" % (tech.name if tech != null else "a technique"))
	if effects.has("learn_recipe"):
		var recipe: Dictionary = data.recipes.get(String(effects["learn_recipe"]), {})
		lines.append("Teaches the recipe: %s" % String(recipe.get("name", "a recipe")))
	if effects.has("heal_injury"):
		var injury_id := String(effects["heal_injury"])
		lines.append("Heals every injury" if injury_id == "all" else "Heals: %s" % Injuries.injury_name(data, injury_id))
	if effects.has("shorten_injury"):
		lines.append("Eases injuries by %d days" % int(effects["shorten_injury"]))
	if effects.has("dao_insight"):
		lines.append("A glimpse of the %s" % String(Dao.def_of(data, String(effects["dao_insight"])).get("name", "Dao")))
	var attributes: Dictionary = effects.get("attributes", {})
	for attr_id in attributes:
		var attr_name := String(attr_id).capitalize()
		for a: Dictionary in data.attributes:
			if a.get("id", "") == attr_id:
				attr_name = String(a.get("name", attr_name))
		lines.append("%+d %s" % [int(attributes[attr_id]), attr_name])
	if effects.has("buff"):
		var buff: Dictionary = effects["buff"]
		var mults: Dictionary = buff.get("mults", {})
		var parts: PackedStringArray = []
		for stat in mults:
			parts.append("%+d%% %s" % [roundi(float(mults[stat]) * 100.0), String(stat).replace("_", " ")])
		var days := int(buff.get("days", 0))
		lines.append("%s for %d %s" % [", ".join(parts) if not parts.is_empty() else "A blessing", days, "day" if days == 1 else "days"])
	if effects.has("bloodline"):
		lines.append("Awakens the %s in your blood" % Bloodlines.bloodline_name(data, String(effects["bloodline"])))
	return lines


## What using `item_id` costs that cannot be undone ("" = nothing worth a
## confirmation): burned lifespan or a darkened heart (WU-032).
static func use_warning(data: GameData, item_id: String) -> String:
	var effects: Dictionary = data.items.get(item_id, {}).get("effects", {})
	var parts: PackedStringArray = []
	var burned := int(effects.get("burn_lifespan", 0))
	if burned > 0:
		parts.append("Burn %d %s of your life" % [burned, "year" if burned == 1 else "years"])
	var shift := int(effects.get("alignment", 0))
	if shift < 0:
		parts.append("stain your heart (alignment %d)" % shift)
	return ", ".join(parts)


## Buys at a merchant affiliated with sect `faction` ("" = none), whose
## prices follow the buyer's reputation (Reputation.buy_price).
## Returns {ok, reason, stones}.
static func buy(c: CharacterData, data: GameData, item_id: String, quantity: int = 1, faction: String = "", market_mult: float = 1.0, season: String = "") -> Dictionary:
	var item: Dictionary = data.items.get(item_id, {})
	var price := Reputation.buy_price(c, data, item_id, faction, market_mult, season) * quantity
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
	if stock_tags.has(item.get("id", "")):
		return true  # MARKET-002: stock_tags may also name single item ids
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


## Inventory tab an item belongs to, one of CATEGORIES (minus "All").
static func category(item: Dictionary) -> String:
	var tags: Array = item.get("tags", [])
	var effects: Dictionary = item.get("effects", {})
	if item.has("equip"):
		return "Equipment"
	if tags.has("talisman") or item.has("combat"):
		return "Talismans"
	if tags.has("herb") or tags.has("ore"):
		return "Herbs & Ores"
	if effects.has("learn_recipe") or effects.has("learn_technique"):
		return "Manuals & Scrolls"
	if bool(item.get("usable", false)):
		return "Pills"
	return "Other"


const CATEGORIES: Array[String] = ["All", "Pills", "Herbs & Ores", "Equipment", "Talismans", "Manuals & Scrolls", "Other"]


static func has_tag(data: GameData, item_id: String, tags: Array) -> bool:
	for tag in data.items.get(item_id, {}).get("tags", []):
		if tags.has(tag):
			return true
	return false


## Where `item_id` can be had, as "Sold at <merchant> (<region>)" /
## "Gathered at <place> (<region>)" lines, then one line per other kind of
## source ("Crafted", "Dropped by creatures", ...); "Found exploring" when
## nothing known gives it.
static func sources(data: GameData, item_id: String) -> Array[String]:
	var lines := _scan_sources(data, item_id)
	if lines.is_empty():
		lines.append("Found exploring")
	return lines


## True when something in the data really gives `item_id` (ITEM-002): a
## merchant, gather table, recipe, enemy drop, encounter or choice, mission,
## inheritance, secret realm, sect shop or stipend, auction lot, deed, world
## event or dialogue reward.
static func has_known_source(data: GameData, item_id: String) -> bool:
	return not _scan_sources(data, item_id).is_empty()


static func _scan_sources(data: GameData, item_id: String) -> Array[String]:
	if data.source_cache.has(item_id):
		var cached: Array[String] = []
		cached.assign(data.source_cache[item_id])
		return cached
	var lines := _compute_sources(data, item_id)
	data.source_cache[item_id] = lines.duplicate()
	return lines


static func _compute_sources(data: GameData, item_id: String) -> Array[String]:
	var lines: Array[String] = []
	var item: Dictionary = data.items.get(item_id, {})
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			var kind: String = place.get("type", "")
			var where := "%s (%s)" % [place.get("display_name", kind), region.get("name", region["id"])]
			if kind == "merchant" and merchant_sells(data, item, place.get("stock_tags", []), int(place.get("max_price", 0))):
				lines.append("Sold at " + where)
			elif kind == "fishing":
				for entry: Dictionary in place.get("catch_table", []):
					if entry.get("item", "") == item_id:
						lines.append("Caught at " + where)
						break
			elif kind == "gather":
				var found := false
				var year_round := false
				var seasons: Array = []
				for entry: Dictionary in place.get("gather_table", []):
					if entry.get("item", "") != item_id:
						continue
					found = true
					if entry.has("seasons"):
						for season: String in entry["seasons"]:
							if not seasons.has(season):
								seasons.append(season)
					else:
						year_round = true
				if found:
					lines.append("Gathered at %s%s" % [where, "" if year_round else " (%s)" % ", ".join(seasons)])
	if not _recipe_makers(data, item_id).is_empty():
		lines.append("Crafted")
	var other := {
		"Dropped by creatures": data.enemies, "Reward from encounters": data.encounters, "Reward from sect missions": data.sect_missions,
		"Reward from inheritances": data.inheritances, "Found in secret realms": data.secret_realms, "Offered at auction": data.auction_houses,
		"Reward for deeds": data.deeds, "Reward from world events": data.world_events, "Reward from conversations": data.dialogues,
		"Given as a gratitude gift": data.karma,
	}
	for label: String in other:
		if _gives(other[label], item_id):
			lines.append(label)
	for event: Dictionary in data.world_events.values():
		if (event.get("shop_items", []) as Array).has(item_id):
			lines.append("Festival stall: " + String(event.get("name", event["id"])))
	for sect: SectDef in data.sects.values():
		if _gives(sect.shop, item_id) or _gives(sect.ranks, item_id):
			lines.append("Sect reward (%s)" % sect.name)
	return lines


## Recipe ids whose output (or great_output) is `item_id`.
static func _recipe_makers(data: GameData, item_id: String) -> Array[String]:
	var out: Array[String] = []
	for recipe: Dictionary in data.recipes.values():
		if recipe.get("output", {}).get("item", "") == item_id or recipe.get("great_output", {}).get("item", "") == item_id:
			out.append(String(recipe["id"]))
	return out


## True when a reward-shaped value in `node` hands out `item_id`: an `items` /
## `herbs` map keyed by it, a `manuals` list, or an `item` / `item_id` field.
## Requirements and costs (`requires`, `if`, `ingredients`, ...) do not count.
static func _gives(node: Variant, item_id: String) -> bool:
	if node is Dictionary:
		var dict: Dictionary = node
		for key: Variant in dict:
			var value: Variant = dict[key]
			match String(key):
				"requires", "if", "has_items", "ingredients", "cost", "consume":
					continue
				"items", "herbs":
					if value is Dictionary and int((value as Dictionary).get(item_id, 0)) > 0:
						return true
				"manuals":
					if value is Array and (value as Array).has(item_id):
						return true
				"item", "item_id":
					if value is String and value == item_id:
						return true
			if _gives(value, item_id):
				return true
	elif node is Array:
		for entry: Variant in node:
			if _gives(entry, item_id):
				return true
	return false


## Item ids a merchant stocking `stock_tags` up to `max_price` sells
## (merchant_sells), cheapest first.
static func shop_stock(data: GameData, max_price: int, stock_tags: Array) -> Array:
	var ids: Array = []
	for item: Dictionary in data.items.values():
		if merchant_sells(data, item, stock_tags, max_price):
			ids.append(item["id"])
	ids.sort_custom(func(a, b): return _price_then_name(data, a, b))
	return ids


## True when a merchant with these tags would buy `item_id` back (tagged
## merchants only, and the item must have a sell price).
static func merchant_buys(data: GameData, item_id: String, stock_tags: Array, buy_tags: Array = []) -> bool:
	var tags: Array = stock_tags + buy_tags
	return not tags.is_empty() and has_tag(data, item_id, tags) and sell_price(data, item_id) > 0


## Merchant places that buy `item_id`, sorted by region name:
## {region_id, region_name, place_name}.
static func buyers(data: GameData, item_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for region: Dictionary in data.regions.values():
		for place: Dictionary in region.get("places", []):
			if place.get("type", "") == "merchant" and merchant_buys(data, item_id, place.get("stock_tags", []), place.get("buy_tags", [])):
				out.append({"region_id": region["id"], "region_name": region.get("name", region["id"]), "place_name": place.get("display_name", "Merchant")})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["region_name"]).naturalnocasecmp_to(String(b["region_name"])) < 0)
	return out


## Names of the recipes that use `item_id` as an ingredient, sorted.
static func recipes_using(data: GameData, item_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for recipe: Dictionary in data.recipes.values():
		if recipe.get("ingredients", {}).has(item_id):
			out.append(String(recipe.get("name", recipe["id"])))
	out.sort()
	return out


## Item ids `c` holds that a merchant with `stock_tags` buys back. Only
## specialist (tagged) merchants buy, and only goods matching their tags
## (plus `buy_tags`, which a merchant buys without selling).
static func buyback_ids(c: CharacterData, data: GameData, stock_tags: Array, buy_tags: Array = []) -> Array:
	var ids: Array = []
	for item_id in c.inventory:
		if c.item_count(item_id) > 0 and merchant_buys(data, item_id, stock_tags, buy_tags):
			ids.append(item_id)
	ids.sort_custom(func(a, b): return _price_then_name(data, a, b))
	return ids


## Why the item cannot be used at this realm (items.json `min_realm`); "" when it can.
static func realm_block(c: CharacterData, data: GameData, item_id: String) -> String:
	var item: Dictionary = data.items.get(item_id, {})
	var min_index := data.realm_index_of(String(item.get("min_realm", "")))
	if min_index < 0 or c.realm_index >= min_index:
		return ""
	return "Only a cultivator of the %s realm can draw on the %s." % [data.realms[min_index].name, item.get("name", item_id)]


## True when using the item feeds cultivation: it gives qi and is not harmful
## (no burn_lifespan, no negative alignment). Sell-all keeps these.
static func feeds_cultivation(data: GameData, item_id: String) -> bool:
	var fx: Dictionary = data.items.get(item_id, {}).get("effects", {})
	var harmful := fx.has("burn_lifespan") or int(fx.get("alignment", 0)) < 0
	return float(fx.get("qi", 0.0)) > 0.0 and not harmful


## Ids `sell all loot` may sell: buyback_ids minus anything worn, manuals and
## scrolls, qi items that feed cultivation, readied combat talismans, breakthrough pills, items in `keep` (item id -> count, e.g. Sects.deliver_needs) and items whose use/equip carries a warning.
static func bulk_sell_ids(c: CharacterData, data: GameData, stock_tags: Array, buy_tags: Array = [], keep: Dictionary = {}) -> Array:
	var worn: Array = c.equipment.values()
	return buyback_ids(c, data, stock_tags, buy_tags).filter(func(id: String) -> bool:
		var item: Dictionary = data.items[id]
		if keep.has(id) or worn.has(id) or c.readied_talismans.has(id) or category(item) == "Manuals & Scrolls":
			return false
		if float(item.get("effects", {}).get("breakthrough_bonus", 0.0)) > 0.0:
			return false
		if feeds_cultivation(data, id):
			return false
		return use_warning(data, id) == "" and Equipment.equip_warning(c, data, id) == "")


## Spirit stones selling every full stack of `ids` would pay.
static func bulk_sell_total(c: CharacterData, data: GameData, ids: Array, season: String = "") -> int:
	var total := 0
	for id in ids:
		total += sell_price(data, id, season) * c.item_count(id)
	return total


static func _price_then_name(data: GameData, a: String, b: String) -> bool:
	var pa := int(data.items[a].get("price", 0))
	var pb := int(data.items[b].get("price", 0))
	if pa != pb:
		return pa < pb
	return String(data.items[a]["name"]).naturalnocasecmp_to(String(data.items[b]["name"])) < 0


## The seasons in which some gather place yields `item_id` (only entries that carry
## `seasons`); empty = not a seasonal item.
static func harvest_seasons(data: GameData, item_id: String) -> Array:
	var seasons: Array = []
	for source: Dictionary in Exploration.seasonal_sources(data, item_id):
		for s: String in source["seasons"]:
			if not seasons.has(s):
				seasons.append(s)
	return seasons


## MARKET-001: price factor for `item_id` in `season`: seasonal_prices.in_season_mult
## while it is harvested, out_of_season_mult otherwise; 1.0 for other items, an
## empty season or absent data.
static func seasonal_mult(data: GameData, item_id: String, season: String) -> float:
	if season == "" or data.seasonal_prices.is_empty():
		return 1.0
	var seasons := harvest_seasons(data, item_id)
	if seasons.is_empty():
		return 1.0
	return float(data.seasonal_prices["in_season_mult" if seasons.has(season.to_lower()) else "out_of_season_mult"])


## GUIDE-204: +1 when `item_id` is dearer in `season` (seasonal_mult > 1), -1 when cheaper, 0 otherwise or for no season.
## Selling pays more when buying costs more, so +1 is a good season to sell.
static func season_trend(data: GameData, item_id: String, season: String) -> int:
	return signi(roundi((seasonal_mult(data, item_id, season) - 1.0) * 1000.0))


## "In season: cheaper now" / "Out of season: dearer" for the inventory, or "".
static func seasonal_note(data: GameData, item_id: String, season: String) -> String:
	var mult := seasonal_mult(data, item_id, season)
	if mult < 1.0:
		return "In season: cheaper now"
	if mult > 1.0:
		return "Out of season: dearer"
	return ""


static func validate_seasonal_prices(block: Dictionary, errors: Array[String]) -> void:
	for key: String in block:
		var v: Variant = block[key]
		if not ["in_season_mult", "out_of_season_mult"].has(key) or not (v is float or v is int) or float(v) < 0.5 or float(v) > 2.0:
			errors.append("seasonal_prices '%s' must be in_season_mult or out_of_season_mult with a value in 0.5..2.0" % key)
	if not block.is_empty() and (not block.has("in_season_mult") or not block.has("out_of_season_mult")):
		errors.append("seasonal_prices needs both in_season_mult and out_of_season_mult")


static func _seasonal_round(price: int, mult: float) -> int:
	if price <= 0 or mult == 1.0:
		return price
	return maxi(1, roundi(price * mult))


## Merchants buy items back at SELL_RATE of their price. Crafted goods (the
## output of any recipe) are also capped at their material cost per unit times
## recipes.json alchemy.crafted_sell_markup, so crafting cheap materials into
## pricey talismans or gear is a modest trade, not a money press.
static func sell_price(data: GameData, item_id: String, season: String = "") -> int:
	var price := _seasonal_round(int(int(data.items.get(item_id, {}).get("price", 0)) * SELL_RATE), seasonal_mult(data, item_id, season))
	var material := material_value(data, item_id)
	if price <= 0 or material < 0.0:
		return price
	var markup := float(data.alchemy.get("crafted_sell_markup", 1.3))
	return clampi(ceili(material * markup), 1, price)


## Spirit-stone value of the ingredients behind one unit of a crafted item
## (cheapest recipe that outputs it), or -1.0 if no
## recipe makes it. Ingredients use their shop price.
## Memoised per item on GameData (the recipe scan is costly for shop and
## commission lists); content is immutable after load.
static func material_value(data: GameData, item_id: String) -> float:
	if not data.material_value_cache.has(item_id):
		data.material_value_cache[item_id] = compute_material_value(data, item_id)
	return data.material_value_cache[item_id]


## Spirit stones spent by a recipe count 1 each in material value (their item price is 0).
const STONE_VALUE := 1


## Uncached scan behind material_value.
static func compute_material_value(data: GameData, item_id: String) -> float:
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
			var unit := STONE_VALUE if ingredient == "spirit_stone" else int(data.items.get(ingredient, {}).get("price", 0))
			cost += unit * int(ingredients[ingredient])
		var per_unit := float(cost) / count
		if best < 0.0 or per_unit < best:
			best = per_unit
	return best


## Returns {ok, reason, stones}.
static func sell(c: CharacterData, data: GameData, item_id: String, quantity: int = 1, season: String = "") -> Dictionary:
	var price := sell_price(data, item_id, season) * quantity
	if price <= 0 or item_id == "spirit_stone":
		return {"ok": false, "reason": "No one will buy that.", "stones": 0}
	if c.item_count(item_id) < quantity:
		return {"ok": false, "reason": "You do not have enough.", "stones": 0}
	c.add_item(item_id, -quantity)
	c.add_item("spirit_stone", price)
	LifeStats.record_stones(c, price)
	if crafted_by_own_profession(c, data, item_id):
		LifeStats.add(c, "profession_stones", price)
	return {"ok": true, "reason": "", "stones": price}


## True if a recipe of a profession `c` practises outputs `item_id` (YEAR-009:
## only those sales count as craft income, not a looted sword or a resold pill
## sold by someone without the craft).
static func crafted_by_own_profession(c: CharacterData, data: GameData, item_id: String) -> bool:
	for recipe: Dictionary in data.recipes.values():
		if not c.professions.has(String(recipe.get("profession", ""))):
			continue
		for key in ["output", "great_output"]:
			if String(recipe.get(key, {}).get("item", "")) == item_id:
				return true
	return false


## Returns {ok, reason, notes}.
static func use(c: CharacterData, data: GameData, item_id: String, flags: Dictionary) -> Dictionary:
	var item: Dictionary = data.items.get(item_id, {})
	if item.is_empty() or not item.get("usable", false):
		return {"ok": false, "reason": "That cannot be used.", "notes": PackedStringArray()}
	if c.item_count(item_id) <= 0:
		return {"ok": false, "reason": "You have none left.", "notes": PackedStringArray()}
	var blocked := realm_block(c, data, item_id)
	if blocked != "":
		return {"ok": false, "reason": blocked, "notes": PackedStringArray()}
	var reason := Effects.check(c, data, item.get("effects", {}))
	if reason != "":
		return {"ok": false, "reason": reason, "notes": PackedStringArray()}
	c.add_item(item_id, -1)
	return {"ok": true, "reason": "", "notes": Effects.apply(c, data, item.get("effects", {}), flags)}


## The item's name for `count` of them ("3 Spirit Herbs"); items.json `plural` overrides the rule.
static func item_plural(data: GameData, item_id: String, count: int) -> String:
	var item: Dictionary = data.items.get(item_id, {})
	var name := String(item.get("name", item_id))
	if count != 1 and item.has("plural"):
		return String(item["plural"])
	return Text.plural(name, count)


## The technique a manual item teaches ("" for any other item).
static func manual_technique(data: GameData, item_id: String) -> String:
	var id := String(data.items.get(item_id, {}).get("effects", {}).get("learn_technique", ""))
	return id if data.techniques.has(id) else ""
