extends Interactable
## A spot to gather herbs or ores. Its loot table comes from data/regions.json:
## gather_table = [{item, weight, min, max}] ("" item = nothing found).

@export var gather_table: Array = []
@export var gather_days := 5


func get_options() -> Array[Dictionary]:
	return [{"label": "Gather (%s)" % Calendar.format_duration(gather_days), "action": GameState.gather.bind(gather_table, gather_days), "keep_open": true}]
