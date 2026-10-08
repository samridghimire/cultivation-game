extends Interactable
## An NPC or place that offers moral choices from data/deeds.json.
## Disappears if `hidden_by_flag` is set in the world flags.

@export var deed_context := "villager"
@export var hidden_by_flag := ""


func is_available() -> bool:
	return hidden_by_flag == "" or not GameState.world_flags.get(hidden_by_flag, false)


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for entry in Deeds.options(GameState.player, GameState.data, deed_context, GameState.world_flags, GameClock.total_days):
		var deed: Dictionary = entry["deed"]
		var label := String(deed["name"])
		if entry["danger"] != "":
			label += " [fight: %s%s]" % [entry["danger"], ", to the death" if entry.get("lethal", false) else ""]
		options.append({"label": label, "action": GameState.perform_deed.bind(deed["id"]), "disabled": entry["disabled"], "reason": entry["reason"] if entry["disabled"] else ""})
	return options
