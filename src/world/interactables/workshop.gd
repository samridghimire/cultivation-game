extends Interactable
## Odd jobs that train a profession and pay spirit stones. Alchemists refine
## pills, Blacksmiths forge artifacts and Talisman Masters inscribe talismans and Array Masters refine array discs from recipes (data/recipes.json)
## instead of doing odd jobs; each craft opens the CraftingScreen.

const CRAFTS := ["alchemist", "blacksmith", "talisman_master", "array_master"]


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var c: CharacterData = GameState.player
	var data: GameData = GameState.data
	for prof_id in CRAFTS:
		if data.professions.has(prof_id):
			var known := Alchemy.known_recipes(c, data, prof_id).size()
			options.append({"label": "%s (%s, %d recipes)" % [CraftingScreen.TITLES[prof_id], Professions.rank_title(c, data, prof_id), known], "action": EventBus.crafting_requested.emit.bind(prof_id)})
	for def: ProfessionDef in data.professions.values():
		if CRAFTS.has(def.id):
			continue
		var title := Professions.rank_title(c, data, def.id)
		options.append({"label": "Work as %s (1 month) [%s]" % [def.name, title], "action": GameState.work_profession.bind(def.id, Calendar.DAYS_PER_MONTH), "keep_open": true})
	return options
