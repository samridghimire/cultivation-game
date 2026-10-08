class_name Commissions
extends RefCounted
## Crafting commissions (PROF-001): each month a buyer orders a few units of
## something a crafter can already make, for a multiple of its material value
## plus profession xp. Rules live in data/recipes.json `commissions`.
## PROF-002: delivery_hint and lapse_warnings remind the player about open orders.


const LAPSE_WARNING_DAYS := 7


static func rules(data: GameData) -> Dictionary:
	return data.commissions


static func _open_count(c: CharacterData, prof_id: String) -> int:
	var n := 0
	for order in c.commissions:
		if order["profession"] == prof_id:
			n += 1
	return n


## Posts at most per_profession open orders for each profession `c` practises.
## Returns the new orders.
static func roll(c: CharacterData, data: GameData, rng: RandomNumberGenerator, today: int) -> Array[Dictionary]:
	var added: Array[Dictionary] = []
	var r := rules(data)
	if r.is_empty():
		return added
	var prof_ids: Array = c.professions.keys()
	prof_ids.sort()
	for prof_id: String in prof_ids:
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
		return "You need %d more %s." % [missing, _item_name(data, String(order["item"]))]
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
			return "Deliver your %d %s order at a workshop (%d days left)." % [int(order["count"]), _item_name(data, String(order["item"])), days_left(order, today)]
	return ""


## Orders whose time left dropped to LAPSE_WARNING_DAYS while the clock went from `from_day`
## to `to_day` (each order crosses that day once, so each is warned about once).
static func lapse_warnings(c: CharacterData, data: GameData, from_day: int, to_day: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for order in c.commissions:
		var warn_day := int(order["due_day"]) - LAPSE_WARNING_DAYS
		if from_day < warn_day and warn_day <= to_day and int(order["due_day"]) >= to_day:
			out.append("The order for %d %s lapses in %d days." % [int(order["count"]), _item_name(data, String(order["item"])), LAPSE_WARNING_DAYS])
	return out


static func days_left(entry: Dictionary, today: int) -> int:
	return maxi(0, int(entry["due_day"]) - today)


## "3 Qi Gathering Pills for 54 spirit stones and 30 alchemist xp, 41 days left (you have 1)".
static func describe(c: CharacterData, data: GameData, entry: Dictionary, today: int) -> String:
	var prof_name: String = data.professions[entry["profession"]].name.to_lower() if data.professions.has(entry["profession"]) else String(entry["profession"])
	return "%d %s for %d spirit stones and %d %s xp, %d days left (you have %d)" % [
		int(entry["count"]), _item_name(data, String(entry["item"])), int(entry["reward"]), int(entry["xp"]),
		prof_name, days_left(entry, today), c.item_count(String(entry["item"]))]


## Menu label: "Deliver 3 Qi Gathering Pills: 54 stones, 30 xp, 41 days (have 1/3)".
static func short_label(c: CharacterData, data: GameData, entry: Dictionary, today: int) -> String:
	var name := _item_name(data, String(entry["item"]))
	if name.length() > 15:
		name = name.substr(0, 14) + "…"
	return "Deliver %d %s: %d stones, %d xp, %dd (have %d/%d)" % [
		int(entry["count"]), name, int(entry["reward"]), int(entry["xp"]),
		days_left(entry, today), mini(c.item_count(String(entry["item"])), int(entry["count"])), int(entry["count"])]
