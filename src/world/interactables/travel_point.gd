class_name TravelPoint
extends Interactable
## A road out of the region. Lists every route from data/regions.json.
## The region the top hint names when no place here is named (set by World._mark_hinted, WU-283).
var hint_region := ""


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var hop := Guidance.first_hop(GameState.player, GameState.data, GameState.current_region, hint_region) if hint_region != "" else ""
	var weather := Weather.of(GameState.data, GameState.current_region, GameClock.total_days)
	var snow := Weather.travel_extra_days(GameState.data, GameState.current_region, GameClock.total_days)
	var weather_note := Weather.effect_note(GameState.data, weather, "travel")
	for route in Exploration.routes(GameState.player, GameState.data, GameState.current_region):
		var days: int = int(route["days"]) + (snow if route["ok"] else 0)
		var label := "Travel to %s (%s)" % [route["name"], Calendar.format_duration(days)]
		if weather_note != "" and route["ok"]:
			label += " " + weather_note
		if not route["ok"]:
			label += " - too dangerous"
		var option := {"label": label, "action": GameState.travel.bind(route["to"]), "disabled": not route["ok"]}
		var note := Exploration.road_note(GameState.data, days)
		if not Exploration.visited(GameState.player, route["to"]):
			option["description"] = "(never visited) " + note
		else:
			option["description"] = note
		option["description"] = String(option["description"]) + "\n" + destination_note(GameState.player, GameState.data, route["to"], GameState.world_flags)
		if hop != "" and route["to"] == hop:
			option["description"] = "The hint points this way. " + String(option["description"])
		options.append(option)
	return options


const _PLACE_WORDS := {"merchant": "Merchant", "clinic": "clinic", "bounty_board": "bounty board", "sect_hall": "sect hall"}
const _NOTE_MAX := 90


## WU-319: what waits at the far end of a road, e.g. "Qi x2.5 (Cloud-Sea Cliff x5)", plus the
## places that matter (merchant, clinic, bounty board, sect hall) once the region is visited.
static func destination_note(c: CharacterData, data: GameData, to_id: String, flags: Dictionary) -> String:
	var best := Guidance.best_qi_in_region(c, data, to_id, flags)
	var note := "Qi x%s" % _num(Exploration.qi_density(data, to_id, flags, GameClock.total_days))
	if String(best["name"]) != "":
		note += " (%s x%s)" % [GameData.plain_name(String(best["name"])), _num(float(best["density"]))]
	if Exploration.visited(c, to_id):
		var found := {}
		for place: Dictionary in data.regions.get(to_id, {}).get("places", []):
			found[String(place.get("type", ""))] = true
		var words := PackedStringArray()
		for type: String in _PLACE_WORDS:
			if found.has(type):
				words.append(_PLACE_WORDS[type])
		while not words.is_empty():
			var line := note + ". " + ", ".join(words)
			if line.length() < _NOTE_MAX:
				return line
			words.remove_at(words.size() - 1)
	return note


static func _num(v: float) -> String:
	return String.num(snappedf(v, 0.1), 1).trim_suffix(".0")
