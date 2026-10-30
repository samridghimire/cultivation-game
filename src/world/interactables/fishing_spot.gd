extends Interactable
## A pond to fish (FISH-001). Its catch comes from data/regions.json:
## catch_table = [{item, weight, min, max}] ("" item = nothing bites); the weather moves the odds.

@export var catch_table: Array = []
@export var gather_days := 2


func get_options() -> Array[Dictionary]:
	var kind := Weather.of(GameState.data, GameState.current_region, GameClock.total_days)
	var mult := Weather.fishing_multiplier(GameState.data, kind)
	var note := ""
	if mult > 1.0:
		note = "%s: the fish are biting." % kind.capitalize()
	elif mult < 1.0:
		note = "%s: the fish are shy." % kind.capitalize()
	var label := "Fish (%s)" % Calendar.format_duration(gather_days)
	return [{"label": label, "description": note, "action": GameState.fish.bind(catch_table, gather_days, display_name), "keep_open": true}]
