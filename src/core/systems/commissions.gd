class_name Commissions
extends RefCounted
## Crafting commissions (PROF-001): each month a buyer orders a few units of
## something a crafter can already make, for a multiple of its material value
## plus profession xp. Rules live in data/recipes.json `commissions`.


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
			"reward": maxi(1, ceili(Items.material_value(data, item_id) * count * float(r["reward_mult"]))),
			"xp": float(recipe.get("xp", 0)) * float(r["xp_fraction"]) * count,
			"due_day": today + int(r["days"]),
		}
		c.commissions.append(order)
		added.append(order)
	return added


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


static func days_left(entry: Dictionary, today: int) -> int:
	return maxi(0, int(entry["due_day"]) - today)


## "3 Qi Gathering Pills for 54 spirit stones and 30 alchemist xp, 41 days left (you have 1)".
static func describe(c: CharacterData, data: GameData, entry: Dictionary, today: int) -> String:
	var prof_name: String = data.professions[entry["profession"]].name.to_lower() if data.professions.has(entry["profession"]) else String(entry["profession"])
	return "%d %s for %d spirit stones and %d %s xp, %d days left (you have %d)" % [
		int(entry["count"]), _item_name(data, String(entry["item"])), int(entry["reward"]), int(entry["xp"]),
		prof_name, days_left(entry, today), c.item_count(String(entry["item"]))]
