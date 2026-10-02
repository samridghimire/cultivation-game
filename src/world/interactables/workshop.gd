extends Interactable
## Odd jobs that train a profession and pay spirit stones.


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for def: ProfessionDef in GameState.data.professions.values():
		var title := Professions.rank_title(GameState.player, GameState.data, def.id)
		options.append({"label": "Work as %s (1 month) [%s]" % [def.name, title], "action": GameState.work_profession.bind(def.id, Calendar.DAYS_PER_MONTH), "keep_open": true})
	return options
