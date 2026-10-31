extends Interactable
## A pond to fish (FISH-001). Its catch comes from data/regions.json:
## catch_table = [{item, weight, min, max}] ("" item = nothing bites); the weather moves the odds.

@export var catch_table: Array = []
@export var gather_days := 2


func get_options() -> Array[Dictionary]:
	var kind := Weather.of(GameState.data, GameState.current_region, GameClock.total_days)
	var note := Weather.effect_note(GameState.data, Weather.of(GameState.data, GameState.current_region, GameClock.total_days), "fish")
	var label := "Fish (%s)" % Calendar.format_duration(gather_days)
	return [{"label": label, "description": note, "action": _fish, "keep_open": true}]


## Opens the timing bar, or fishes at once with an ordinary cast when "auto cast" is on.
func _fish() -> void:
	if Settings.get_value("auto_cast"):
		GameState.fish(catch_table, gather_days, display_name)
	else:
		EventBus.cast_requested.emit(catch_table, gather_days, display_name)
