extends Interactable
## A road out of the region. Lists every route from data/regions.json.


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for route in Exploration.routes(GameState.player, GameState.data, GameState.current_region):
		var label := "Travel to %s (%s)" % [route["name"], Calendar.format_duration(route["days"])]
		if not route["ok"]:
			label += " - too dangerous"
		var option := {"label": label, "action": GameState.travel.bind(route["to"]), "disabled": not route["ok"]}
		var note := Exploration.road_note(GameState.data, int(route["days"]))
		if not Exploration.visited(GameState.player, route["to"]):
			option["description"] = "(never visited) " + note
		else:
			option["description"] = note
		options.append(option)
	return options
