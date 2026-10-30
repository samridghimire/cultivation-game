extends Interactable
## Odd jobs that train a profession and pay spirit stones. Alchemists refine
## pills, Blacksmiths forge artifacts and Talisman Masters inscribe talismans and Array Masters refine array discs and Beast Tamers mix beast feed from recipes (data/recipes.json)
## instead of doing odd jobs; each craft opens the CraftingScreen. A crafter the
## player practises can also take "Odd jobs" in that craft for the same pay as other work (PROF-004).

const CRAFTS := ["alchemist", "blacksmith", "talisman_master", "array_master", "beast_tamer"]


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var c: CharacterData = GameState.player
	var data: GameData = GameState.data
	for prof_id in CRAFTS:
		if data.professions.has(prof_id):
			var known := Alchemy.known_recipes(c, data, prof_id).size()
			options.append({"label": "%s (%s, %d %s)" % [CraftingScreen.TITLES[prof_id], Professions.rank_title(c, data, prof_id), known, "recipe" if known == 1 else "recipes"], "action": EventBus.crafting_requested.emit.bind(prof_id)})
	for m: Dictionary in data.home_meals:
		var meal_reason := Cooking.check(c, data, String(m["id"]))
		options.append({"label": "Cook: %s" % m["name"], "description": "No profession needed. Eases injuries once eaten.", "reason": meal_reason, "action": GameState.cook_meal.bind(String(m["id"])), "disabled": meal_reason != "", "keep_open": true})
	for i in c.commissions.size():
		var reason := Commissions.check_deliver(c, data, i)
		var label := Commissions.short_label(c, data, c.commissions[i], GameClock.total_days)
		options.append({"label": label, "reason": reason, "action": GameState.deliver_commission.bind(i), "disabled": reason != "", "keep_open": true})
	for def: ProfessionDef in data.professions.values():
		var is_craft := CRAFTS.has(def.id)
		if is_craft and not c.professions.has(def.id):
			continue
		var title := Professions.rank_title(c, data, def.id)
		var verb := "Odd jobs as %s" % def.name if is_craft else "Work as %s" % def.name
		options.append({"label": "%s (1 month) [%s]" % [verb, title], "description": _pay_note(c, data, def.id), "action": GameState.work_profession.bind(def.id, Calendar.DAYS_PER_MONTH), "keep_open": true})
	return options


static func _pay_note(c: CharacterData, data: GameData, prof_id: String) -> String:
	var pay := Professions.work_preview(c, data, prof_id, Calendar.DAYS_PER_MONTH)
	return "About %d spirit stones and %d xp this month." % [int(pay["income"]), roundi(float(pay["xp"]))]
