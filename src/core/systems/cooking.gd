class_name Cooking
extends RefCounted
## FISH-002: home cooking. Anyone can turn simple ingredients (the fish from the pond) into a meal
## at a workshop or the Family Home, no profession needed. Meals are data/recipes.json `home_meals`:
## {id, name, ingredients {item: count}, output {item, count}, days}. Pure and deterministic.


static func meal(data: GameData, meal_id: String) -> Dictionary:
	for m: Dictionary in data.home_meals:
		if String(m["id"]) == meal_id:
			return m
	return {}


## "" if `c` can cook the meal now, else why not.
static func check(c: CharacterData, data: GameData, meal_id: String) -> String:
	var m := meal(data, meal_id)
	if m.is_empty():
		return "You do not know that dish."
	var ingredients: Dictionary = m["ingredients"]
	for item_id: Variant in ingredients:
		var need := int(ingredients[item_id])
		if c.item_count(String(item_id)) < need:
			return "You need %d %s." % [need, Items.item_plural(data, String(item_id), need)]
	return ""


## Cooks the meal: takes the ingredients and adds the output. Returns {ok, reason, item, count, days}.
static func cook(c: CharacterData, data: GameData, meal_id: String) -> Dictionary:
	var reason := check(c, data, meal_id)
	if reason != "":
		return {"ok": false, "reason": reason}
	var m := meal(data, meal_id)
	var ingredients: Dictionary = m["ingredients"]
	for item_id: Variant in ingredients:
		c.add_item(String(item_id), -int(ingredients[item_id]))
	var output: Dictionary = m["output"]
	var item := String(output["item"])
	var count := int(output["count"])
	c.add_item(item, count)
	return {"ok": true, "reason": "", "item": item, "count": count, "days": int(m["days"])}
