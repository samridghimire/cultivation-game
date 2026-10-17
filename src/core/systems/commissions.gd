class_name Commissions
extends RefCounted
## Crafting commissions (PROF-001): each month a buyer orders a few units of
## something a crafter can already make, for a multiple of its material value
## plus profession xp. Rules live in data/recipes.json `commissions`.
## PROF-002: delivery_hint and lapse_warnings remind the player about open orders.


const LAPSE_WARNING_DAYS := 7
const DUE_SOON_DAYS := 14


static func rules(data: GameData) -> Dictionary:
	return data.commissions


static func _open_count(c: CharacterData, prof_id: String) -> int:
	var n := 0
	for order in c.commissions:
		if order["profession"] == prof_id:
			n += 1
	return n


## Posts at most per_profession open orders for each profession `c` practises
## (only `only_prof` when given). Returns the new orders. With a `region_id` (PROF-009) the order
## is picked among recipes whose ingredients are spirit stones, already in the pack or available
## nearby (Guidance.available_nearby) when there are any; "" picks uniformly as before.
static func roll(c: CharacterData, data: GameData, rng: RandomNumberGenerator, today: int, only_prof: String = "", region_id: String = "") -> Array[Dictionary]:
	var added: Array[Dictionary] = []
	var r := rules(data)
	if r.is_empty():
		return added
	var prof_ids: Array = c.professions.keys()
	prof_ids.sort()
	for prof_id: String in prof_ids:
		if only_prof != "" and prof_id != only_prof:
			continue
		if not data.professions.has(prof_id) or _open_count(c, prof_id) >= int(r["per_profession"]):
			continue
		var options: Array[Dictionary] = []
		for recipe_id in Alchemy.known_recipes(c, data, prof_id):
			var recipe: Dictionary = data.recipes[recipe_id]
			if int(recipe.get("min_rank", 0)) > Professions.rank_of(c, prof_id):
				continue
			if Items.material_value(data, String(recipe["output"]["item"])) < 0.0:
				continue
			options.append(recipe)
		if options.is_empty():
			continue
		if region_id != "":
			var near: Array[Dictionary] = []
			for opt: Dictionary in options:
				if _ingredients_near(c, data, opt, region_id, today):
					near.append(opt)
			if not near.is_empty():
				options = near
		var recipe: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var item_id := String(recipe["output"]["item"])
		var count := rng.randi_range(int(r["count"][0]), int(r["count"][1]))
		var order := {
			"profession": prof_id, "recipe": String(recipe["id"]), "item": item_id, "count": count,
			"reward": maxi(1, ceili(unit_reward(data, item_id) * count)),
			"xp": float(recipe.get("xp", 0)) * float(r["xp_fraction"]) * count,
			"due_day": today + int(r["days"]),
		}
		c.commissions.append(order)
		added.append(order)
	return added


static func _ingredients_near(c: CharacterData, data: GameData, recipe: Dictionary, region_id: String, today: int) -> bool:
	for ing: String in recipe["ingredients"]:
		if ing == "spirit_stone" or c.item_count(ing) >= int(recipe["ingredients"][ing]):
			continue
		if not Guidance.available_nearby(c, data, ing, region_id, today):
			return false
	return true


## Spirit stones paid per unit of `item_id`: material value x reward_mult, but
## for an item shops sell, at most max_price_fraction of its price, so buying
## the order in a shop and handing it in loses stones (review of PROF-001).
static func unit_reward(data: GameData, item_id: String) -> float:
	var r := rules(data)
	var material := Items.material_value(data, item_id)
	var reward := material * float(r.get("reward_mult", 1.0))
	var price := int(data.items.get(item_id, {}).get("price", 0))
	if price > 0 and r.has("max_price_fraction"):
		reward = minf(reward, price * float(r["max_price_fraction"]))
	return reward


static func _item_name(data: GameData, item_id: String) -> String:
	return String(data.items.get(item_id, {}).get("name", item_id))


## "" if order `index` can be delivered now, else why not.
static func check_deliver(c: CharacterData, data: GameData, index: int) -> String:
	if index < 0 or index >= c.commissions.size():
		return "No such order."
	var order: Dictionary = c.commissions[index]
	var missing: int = int(order["count"]) - c.item_count(String(order["item"]))
	if missing > 0:
		return "You need %d more %s." % [missing, Items.item_plural(data, String(order["item"]), missing)]
	return ""


## Fills order `index`. Returns {ok, reason, stones, xp, ranks_gained, item, count, profession}.
static func deliver(c: CharacterData, data: GameData, index: int) -> Dictionary:
	var reason := check_deliver(c, data, index)
	if reason != "":
		return {"ok": false, "reason": reason}
	var order: Dictionary = c.commissions[index]
	c.add_item(String(order["item"]), -int(order["count"]))
	c.add_item("spirit_stone", int(order["reward"]))
	LifeStats.record_stones(c, int(order["reward"]))
	LifeStats.add(c, "profession_stones", int(order["reward"]))
	var ranks := Professions.add_xp(c, data, String(order["profession"]), float(order["xp"]))
	c.commissions.remove_at(index)
	LifeStats.add(c, "commissions_done")
	return {"ok": true, "reason": "", "stones": int(order["reward"]), "xp": float(order["xp"]), "ranks_gained": ranks,
		"item": String(order["item"]), "count": int(order["count"]), "profession": String(order["profession"])}


## Removes and returns the orders whose deadline has passed.
static func expire(c: CharacterData, today: int) -> Array[Dictionary]:
	var lapsed: Array[Dictionary] = []
	var kept: Array[Dictionary] = []
	for order in c.commissions:
		if int(order["due_day"]) < today:
			lapsed.append(order)
		else:
			kept.append(order)
	c.commissions = kept
	return lapsed


## "Deliver your 3 Qi Gathering Pills order at a workshop (12 days left)." for the first open
## order whose items you hold, else "" (orders you cannot fill yet are not nagged about).
static func delivery_hint(c: CharacterData, data: GameData, today: int) -> String:
	for i in c.commissions.size():
		if check_deliver(c, data, i) == "":
			var order: Dictionary = c.commissions[i]
			return "Deliver your %d %s order at a workshop (%d days left)." % [int(order["count"]), Items.item_plural(data, String(order["item"]), int(order["count"])), days_left(order, today)]
	return ""


## Orders whose time left dropped to LAPSE_WARNING_DAYS while the clock went from `from_day`
## to `to_day` (each order crosses that day once, so each is warned about once).
static func lapse_warnings(c: CharacterData, data: GameData, from_day: int, to_day: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for order in c.commissions:
		var warn_day := int(order["due_day"]) - LAPSE_WARNING_DAYS
		if from_day < warn_day and warn_day <= to_day and int(order["due_day"]) >= to_day:
			out.append("The order for %d %s lapses in %d days." % [int(order["count"]), Items.item_plural(data, String(order["item"]), int(order["count"])), LAPSE_WARNING_DAYS])
	return out


static func days_left(entry: Dictionary, today: int) -> int:
	return maxi(0, int(entry["due_day"]) - today)


## "3 Qi Gathering Pills for 54 spirit stones and 30 alchemist xp, 41 days left (you have 1)".
static func describe(c: CharacterData, data: GameData, entry: Dictionary, today: int) -> String:
	var prof_name: String = data.professions[entry["profession"]].name.to_lower() if data.professions.has(entry["profession"]) else String(entry["profession"])
	return "%d %s for %d spirit stones and %d %s xp, %d days left (you have %d)" % [
		int(entry["count"]), Items.item_plural(data, String(entry["item"]), int(entry["count"])), int(entry["reward"]), int(entry["xp"]),
		prof_name, days_left(entry, today), c.item_count(String(entry["item"]))]


const LABEL_NAME_MAX := 18


## WU-219: keep whole words while the result stays within LABEL_NAME_MAX, then "…". A single
## first word longer than that keeps the hard cut.
static func _cut_at_word(name: String) -> String:
	var kept := ""
	for word: String in name.split(" "):
		var next := word if kept == "" else kept + " " + word
		if next.length() > LABEL_NAME_MAX:
			break
		kept = next
	if kept == "":
		return name.substr(0, 14) + "…"
	return kept + "…"


## Menu label: "Deliver 3 Qi Gathering Pills: 54 stones, 30 xp, 41 days (have 1/3)".
static func short_label(c: CharacterData, data: GameData, entry: Dictionary, today: int) -> String:
	var name := Items.item_plural(data, String(entry["item"]), int(entry["count"]))
	if name.length() > LABEL_NAME_MAX:
		name = _cut_at_word(name)
	return "Deliver %d %s: %d stones, %d xp, %dd (have %d/%d)" % [
		int(entry["count"]), name, int(entry["reward"]), int(entry["xp"]),
		days_left(entry, today), mini(c.item_count(String(entry["item"])), int(entry["count"])), int(entry["count"])]


## GUIDE-052: what an open order still lacks. "" when the pack already holds the order's items;
## "Needs <ingredient>: <where>." for the first ingredient (data order, no spirit stones) the
## remaining crafts need more of; "You have the ingredients: craft it at a workshop." when none is short.
static func missing_line(c: CharacterData, data: GameData, entry: Dictionary, region_id: String, today: int) -> String:
	var item_id := String(entry.get("item", ""))
	var have := c.item_count(item_id)
	var count := int(entry.get("count", 0))
	if have >= count:
		return ""
	var recipe: Dictionary = data.recipes.get(String(entry.get("recipe", "")), {})
	if recipe.is_empty():
		for rid: String in data.recipes:
			if String(data.recipes[rid].get("output", {}).get("item", "")) == item_id:
				recipe = data.recipes[rid]
				break
	if recipe.is_empty():
		return ""
	var per_craft := maxi(1, int(recipe["output"].get("count", 1)))
	var crafts := ceili(float(count - have) / per_craft)
	var ingredients: Dictionary = recipe["ingredients"]
	for id: String in ingredients:
		if id == "spirit_stone":
			continue
		if c.item_count(id) < int(ingredients[id]) * crafts:
			var where := Guidance.source_phrase(c, data, id, region_id, today)
			return "Needs %s%s." % [_item_name(data, id), ": " + where if where != "" else ""]
	return "You have the ingredients: craft it at a workshop."


## GUIDE-052: for the order due soonest (14 days or less left) that is still short, "Order due in
## <time>: <missing line>"; "" otherwise.
static func due_soon_hint(c: CharacterData, data: GameData, region_id: String, today: int) -> String:
	var best: Dictionary = {}
	var line := ""
	for order in c.commissions:
		if days_left(order, today) > DUE_SOON_DAYS or (not best.is_empty() and int(order["due_day"]) >= int(best["due_day"])):
			continue
		var missing := missing_line(c, data, order, region_id, today)
		if missing != "":
			best = order
			line = missing
	if best.is_empty():
		return ""
	return "Order due in %s: %s" % [Calendar.format_duration(days_left(best, today)), line]
