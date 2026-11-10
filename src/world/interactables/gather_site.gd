class_name GatherSite
extends Interactable
## A spot to gather herbs or ores. Its loot table comes from data/regions.json:
## gather_table = [{item, weight, min, max}] ("" item = nothing found).

@export var gather_table: Array = []
@export var gather_days := 5


## WU-502: "Village Herb Slope (n/3)" while the terrace project is unfinished, in the project's region.
func label_text() -> String:
	if not tags.has("terraces") or not GameState.has_session():
		return super()
	var idx := SeasonTasks.project_index(GameState.data, "terraces")
	if idx < 0 or String(SeasonTasks.project_list(GameState.data)[idx].get("region", "")) != GameState.current_region:
		return super()
	return FishingSpot.jetty_label(display_name, SeasonTasks.project_progress(GameState.player, GameState.data, "terraces"))


func get_options() -> Array[Dictionary]:
	var note := Exploration.seasonal_note(gather_table, Calendar.season_of(GameClock.total_days), GameState.data)
	var uses := Alchemy.recipe_uses(GameState.player, GameState.data, Exploration.gather_table_for(GameState.player, GameState.data, gather_table))
	if not uses.is_empty():
		note += "%sUsed in: %s." % [". " if note != "" else "", ", ".join(uses)]
	note += gather_weather_note(note)
	var terraces := SeasonTasks.gather_project_line(GameState.player, GameState.data, GameState.current_region)
	if terraces != "":
		note += (" " if note != "" else "") + terraces
	return [{"label": "Gather (%s)" % Calendar.format_duration(gather_days), "description": note, "action": GameState.gather.bind(gather_table, gather_days), "keep_open": true}]


## "(rain: herbs thrive)" on a rain day, as a sentence tail after `note`; "" otherwise (WU-403).
static func gather_weather_note(note: String) -> String:
	var weather := Weather.effect_note(GameState.data, Weather.of(GameState.data, GameState.current_region, GameClock.total_days), "gather")
	if weather == "":
		return ""
	return (" " if note != "" else "") + weather
