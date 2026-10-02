extends Interactable
## Odd jobs that train a profession and pay spirit stones. Alchemists refine
## pills and Blacksmiths forge artifacts from recipes (data/recipes.json)
## instead of doing odd jobs; an option without the ingredients posts what is missing.

const CRAFTS := {"alchemist": "Refine", "blacksmith": "Forge"}


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var c: CharacterData = GameState.player
	var data: GameData = GameState.data
	for prof_id in CRAFTS:
		for recipe_id in Alchemy.known_recipes(c, data, prof_id):
			var recipe: Dictionary = data.recipes[recipe_id]
			var parts: PackedStringArray = []
			for item_id in recipe["ingredients"]:
				parts.append("%d %s" % [recipe["ingredients"][item_id], data.items[item_id].get("name", item_id)])
			var label := "%s %s (%s) [%d%%, %s]" % [CRAFTS[prof_id], recipe["name"], ", ".join(parts), roundi(Alchemy.success_chance(c, data, recipe_id) * 100), Calendar.format_duration(int(recipe["days"]))]
			options.append({"label": label, "action": GameState.refine.bind(recipe_id), "keep_open": true})
	for def: ProfessionDef in data.professions.values():
		if CRAFTS.has(def.id):
			continue
		var title := Professions.rank_title(c, data, def.id)
		options.append({"label": "Work as %s (1 month) [%s]" % [def.name, title], "action": GameState.work_profession.bind(def.id, Calendar.DAYS_PER_MONTH), "keep_open": true})
	return options
