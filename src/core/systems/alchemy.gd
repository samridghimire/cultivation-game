class_name Alchemy
extends RefCounted
## The Alchemist's loop: refining herbs into pills from recipes in data/recipes.json.
## Success chance grows with Alchemist rank and Comprehension; a failed
## refinement burns every ingredient. Tunables live under "alchemy" in recipes.json.


## Chance in [min_chance, max_chance] that refining `recipe_id` succeeds.
static func success_chance(c: CharacterData, data: GameData, recipe_id: String) -> float:
	var recipe: Dictionary = data.recipes.get(recipe_id, {})
	if recipe.is_empty():
		return 0.0
	var t := data.alchemy
	var rank_over := Professions.rank_of(c, recipe["profession"]) - int(recipe.get("min_rank", 0))
	var chance := float(t.get("base_chance", 0.5)) \
		+ float(t.get("rank_bonus", 0.08)) * rank_over \
		+ float(t.get("comprehension_step", 0.02)) * (c.attribute("comprehension") - 10) \
		- float(recipe.get("difficulty", 0.0))
	return clampf(chance, float(t.get("min_chance", 0.05)), float(t.get("max_chance", 0.95)))


## Why `c` cannot refine `recipe_id` right now, or "" if they can.
static func check(c: CharacterData, data: GameData, recipe_id: String) -> String:
	var recipe: Dictionary = data.recipes.get(recipe_id, {})
	if recipe.is_empty():
		return "You know no such recipe."
	var min_rank := int(recipe.get("min_rank", 0))
	if Professions.rank_of(c, recipe["profession"]) < min_rank:
		return "Requires %s %s." % [data.profession_rank_names[min_rank], data.professions[recipe["profession"]].name]
	var missing: PackedStringArray = []
	for item_id in recipe["ingredients"]:
		var need := int(recipe["ingredients"][item_id])
		if c.item_count(item_id) < need:
			missing.append("%d %s" % [need - c.item_count(item_id), data.items[item_id].get("name", item_id)])
	if not missing.is_empty():
		return "Missing ingredients: %s." % ", ".join(missing)
	return ""


## Recipe ids of `prof_id` whose rank requirement `c` meets, in data order.
static func known_recipes(c: CharacterData, data: GameData, prof_id: String = "alchemist") -> PackedStringArray:
	var ids: PackedStringArray = []
	for recipe: Dictionary in data.recipes.values():
		if recipe["profession"] == prof_id and Professions.rank_of(c, prof_id) >= int(recipe.get("min_rank", 0)):
			ids.append(recipe["id"])
	return ids


## Attempt one refinement. Ingredients are consumed either way; on success the
## output is added. Returns {ok, reason, success, chance, days, item, count, xp, ranks_gained}.
static func refine(c: CharacterData, data: GameData, recipe_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var reason := check(c, data, recipe_id)
	if reason != "":
		return {"ok": false, "reason": reason, "success": false, "chance": 0.0, "days": 0, "item": "", "count": 0, "xp": 0.0, "ranks_gained": 0}
	var recipe: Dictionary = data.recipes[recipe_id]
	var chance := success_chance(c, data, recipe_id)
	for item_id in recipe["ingredients"]:
		c.add_item(item_id, -int(recipe["ingredients"][item_id]))
	var success := rng.randf() < chance
	var item: String = recipe["output"]["item"]
	var count := int(recipe["output"].get("count", 1)) if success else 0
	if success:
		c.add_item(item, count)
	var xp := float(recipe.get("xp", 0)) * (1.0 if success else float(data.alchemy.get("failure_xp_fraction", 0.5)))
	return {"ok": true, "reason": "", "success": success, "chance": chance, "days": int(recipe.get("days", 1)), "item": item, "count": count, "xp": xp, "ranks_gained": Professions.add_xp(c, data, recipe["profession"], xp)}
