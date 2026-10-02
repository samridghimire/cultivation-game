class_name Alchemy
extends RefCounted
## The crafting loop: Alchemists refine herbs into pills and Blacksmiths forge
## ores into artifacts, from recipes in data/recipes.json. Success chance grows
## with profession rank and the profession's primary attribute; a failed
## refinement burns every ingredient. Tunables live under "alchemy" in recipes.json.
## Recipes must be known before they can be refined: "starter" recipes are known
## by everyone, the rest are learned from recipe scrolls (the learn_recipe effect).
## A great success (the roll lands well under the success chance) yields a
## recipe's optional `great_output` instead, e.g. a higher-grade pill.


## Chance in [min_chance, max_chance] that refining `recipe_id` succeeds.
static func success_chance(c: CharacterData, data: GameData, recipe_id: String) -> float:
	var recipe: Dictionary = data.recipes.get(recipe_id, {})
	if recipe.is_empty():
		return 0.0
	var t := data.alchemy
	var rank_over := Professions.rank_of(c, recipe["profession"]) - int(recipe.get("min_rank", 0))
	var chance := float(t.get("base_chance", 0.5)) \
		+ float(t.get("rank_bonus", 0.08)) * rank_over \
		+ float(t.get("comprehension_step", 0.02)) * (c.attribute(_primary_attribute(data, recipe["profession"])) - 10) \
		- float(recipe.get("difficulty", 0.0))
	return clampf(chance, float(t.get("min_chance", 0.05)), float(t.get("max_chance", 0.95)))


## The attribute that helps crafting for `prof_id` (comprehension for alchemists).
static func _primary_attribute(data: GameData, prof_id: String) -> String:
	var def: ProfessionDef = data.professions.get(prof_id)
	return def.primary_attribute if def != null else "comprehension"


## Chance in [0, success_chance] of a great success: the success chance above
## great_threshold, times great_scale (recipes.json "alchemy"). 0 for recipes
## without a great_output.
static func great_chance(c: CharacterData, data: GameData, recipe_id: String) -> float:
	var recipe: Dictionary = data.recipes.get(recipe_id, {})
	if recipe.is_empty() or not recipe.has("great_output"):
		return 0.0
	var chance := success_chance(c, data, recipe_id)
	var t := data.alchemy
	var great := (chance - float(t.get("great_threshold", 0.5))) * float(t.get("great_scale", 0.5))
	return clampf(great, 0.0, chance)


## Why `c` cannot refine `recipe_id` right now, or "" if they can.
static func check(c: CharacterData, data: GameData, recipe_id: String) -> String:
	var recipe: Dictionary = data.recipes.get(recipe_id, {})
	if recipe.is_empty():
		return "You know no such recipe."
	if not knows(c, data, recipe_id):
		return "You have not learned the %s recipe." % recipe.get("name", recipe_id)
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


## True if `c` knows `recipe_id`: a starter recipe, or one learned from a scroll.
static func knows(c: CharacterData, data: GameData, recipe_id: String) -> bool:
	var recipe: Dictionary = data.recipes.get(recipe_id, {})
	return not recipe.is_empty() and (bool(recipe.get("starter", false)) or c.known_recipes.has(recipe_id))


## Why `c` cannot learn `recipe_id`, or "" if they can. Learning ignores rank:
## a recipe above your rank is known but cannot be refined yet (see check).
static func can_learn(c: CharacterData, data: GameData, recipe_id: String) -> String:
	if not data.recipes.has(recipe_id):
		return "This scroll describes no recipe you can make sense of."
	if knows(c, data, recipe_id):
		return "You already know the %s recipe." % data.recipes[recipe_id].get("name", recipe_id)
	return ""


## Learns `recipe_id`. Returns false if it cannot be learned (see can_learn).
static func learn(c: CharacterData, data: GameData, recipe_id: String) -> bool:
	if can_learn(c, data, recipe_id) != "":
		return false
	c.known_recipes.append(recipe_id)
	return true


## Recipe ids of `prof_id` that `c` knows, in data order, including ones above
## their rank (check() explains the rank requirement).
static func known_recipes(c: CharacterData, data: GameData, prof_id: String = "alchemist") -> PackedStringArray:
	var ids: PackedStringArray = []
	for recipe: Dictionary in data.recipes.values():
		if recipe["profession"] == prof_id and knows(c, data, recipe["id"]):
			ids.append(recipe["id"])
	return ids


## Save migration for characters from before recipe learning existed: they
## knew every recipe their rank allowed, so they keep those.
static func grant_rank_recipes(c: CharacterData, data: GameData) -> void:
	for recipe: Dictionary in data.recipes.values():
		if Professions.rank_of(c, recipe["profession"]) >= int(recipe.get("min_rank", 0)):
			learn(c, data, recipe["id"])


## Attempt one refinement. Ingredients are consumed either way; on success the
## output is added (the great_output on a great success, which shares the
## success roll: roll < great_chance). Returns {ok, reason, success, great,
## chance, days, item, count, xp, ranks_gained}.
static func refine(c: CharacterData, data: GameData, recipe_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var reason := check(c, data, recipe_id)
	if reason != "":
		return {"ok": false, "reason": reason, "success": false, "great": false, "chance": 0.0, "days": 0, "item": "", "count": 0, "xp": 0.0, "ranks_gained": 0}
	var recipe: Dictionary = data.recipes[recipe_id]
	var chance := success_chance(c, data, recipe_id)
	for item_id in recipe["ingredients"]:
		c.add_item(item_id, -int(recipe["ingredients"][item_id]))
	var roll := rng.randf()
	var success := roll < chance
	var great := roll < great_chance(c, data, recipe_id)
	var output: Dictionary = recipe["great_output"] if great else recipe["output"]
	var item: String = output["item"]
	var count := int(output.get("count", 1)) if success else 0
	if success:
		c.add_item(item, count)
	var xp := float(recipe.get("xp", 0)) * (1.0 if success else float(data.alchemy.get("failure_xp_fraction", 0.5)))
	return {"ok": true, "reason": "", "success": success, "great": great, "chance": chance, "days": int(recipe.get("days", 1)), "item": item, "count": count, "xp": xp, "ranks_gained": Professions.add_xp(c, data, recipe["profession"], xp)}
