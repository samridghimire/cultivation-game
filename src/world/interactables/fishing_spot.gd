class_name FishingSpot
extends Interactable
## A pond to fish (FISH-001). Its catch comes from data/regions.json:
## catch_table = [{item, weight, min, max}] ("" item = nothing bites); the weather moves the odds.

@export var catch_table: Array = []
@export var gather_days := 2


## WU-494: "Village Pond Jetty (n/3)" while the jetty project is unfinished, in the project's region.
static func jetty_label(base: String, progress: Array) -> String:
	if progress.size() < 2 or int(progress[1]) == 0 or int(progress[0]) >= int(progress[1]):
		return base
	return "%s (%d/%d)" % [base, int(progress[0]), int(progress[1])]


func label_text() -> String:
	if not tags.has("jetty") or not GameState.has_session():
		return super()
	var idx := SeasonTasks.project_index(GameState.data, "jetty")
	if idx < 0 or String(SeasonTasks.project_list(GameState.data)[idx].get("region", "")) != GameState.current_region:
		return super()
	return jetty_label(display_name, SeasonTasks.project_progress(GameState.player, GameState.data, "jetty"))


func get_options() -> Array[Dictionary]:
	var kind := Weather.of(GameState.data, GameState.current_region, GameClock.total_days)
	var note := Weather.effect_note(GameState.data, Weather.of(GameState.data, GameState.current_region, GameClock.total_days), "fish")
	var jetty := SeasonTasks.fish_project_line(GameState.player, GameState.data, GameState.current_region)
	if jetty != "":
		note = jetty if note == "" else "%s %s" % [note, jetty]
	var label := "Fish (%s)" % Calendar.format_duration(gather_days)
	var line := Fishing.weather_line(GameState.data, kind)
	if line != "":
		note = line if note == "" else "%s %s" % [note, line]
	return [{"label": label, "description": note, "action": _fish, "keep_open": true}]


## Opens the timing bar, or fishes at once with an ordinary cast when "auto cast" is on.
func _fish() -> void:
	var kind := Weather.of(GameState.data, GameState.current_region, GameClock.total_days)
	if Settings.get_value("auto_cast") or Fishing.too_wild(kind):
		GameState.fish(catch_table, gather_days, display_name)
	else:
		EventBus.cast_requested.emit(catch_table, gather_days, display_name)
