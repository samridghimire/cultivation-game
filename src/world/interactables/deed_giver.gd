extends Interactable
## An NPC or place that offers moral choices from data/deeds.json.
## Disappears if `hidden_by_flag` is set in the world flags.

@export var deed_context := "villager"
@export var hidden_by_flag := ""


func is_available() -> bool:
	return hidden_by_flag == "" or not GameState.world_flags.get(hidden_by_flag, false)


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for entry in Deeds.options(GameState.player, GameState.data, deed_context, GameState.world_flags):
		var deed: Dictionary = entry["deed"]
		var label := String(deed["name"])
		if entry["danger"] != "":
			label += " [fight: %s]" % entry["danger"]
		if entry["disabled"]:
			label += " (%s)" % entry["reason"]
		options.append({"label": label, "action": GameState.perform_deed.bind(deed["id"]), "disabled": entry["disabled"]})
	return options
