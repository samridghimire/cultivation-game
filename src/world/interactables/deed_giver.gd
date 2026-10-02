extends Interactable
## An NPC or place that offers moral choices from data/deeds.json.
## Disappears if `hidden_by_flag` is set in the world flags.

@export var deed_context := "villager"
@export var hidden_by_flag := ""


func is_available() -> bool:
	return hidden_by_flag == "" or not GameState.world_flags.get(hidden_by_flag, false)


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for deed in Deeds.available(GameState.data, deed_context, GameState.world_flags):
		options.append({"label": deed["name"], "action": GameState.perform_deed.bind(deed["id"])})
	return options
