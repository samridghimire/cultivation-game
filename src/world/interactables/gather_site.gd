class_name GatherSite
extends Interactable
## A spot to gather herbs or ores. Its loot table comes from data/regions.json:
## gather_table = [{item, weight, min, max}] ("" item = nothing found).

@export var gather_table: Array = []
@export var gather_days := 5


func get_options() -> Array[Dictionary]:
	var note := Exploration.seasonal_note(gather_table, Calendar.season_of(GameClock.total_days), GameState.data)
	var uses := Alchemy.recipe_uses(GameState.player, GameState.data, Exploration.gather_table_for(GameState.player, GameState.data, gather_table))
	if not uses.is_empty():
		note += "%sUsed in: %s." % [". " if note != "" else "", ", ".join(uses)]
	note += gather_weather_note(note)
	return [{"label": "Gather (%s)" % Calendar.format_duration(gather_days), "description": note, "action": GameState.gather.bind(gather_table, gather_days), "keep_open": true}]


## "(rain: herbs thrive)" on a rain day, as a sentence tail after `note`; "" otherwise (WU-403).
static func gather_weather_note(note: String) -> String:
	var weather := Weather.effect_note(GameState.data, Weather.of(GameState.data, GameState.current_region, GameClock.total_days), "gather")
	if weather == "":
		return ""
	return (" " if note != "" else "") + weather
