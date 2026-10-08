extends Interactable
## A wild place to search for herbs, treasures and trouble. Encounters come
## from data/encounters.json, chosen by tag.

## Encounter tags for this spot. Empty = the region's encounter_tags.
@export var explore_tags: Array = []


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = [{"label": "Explore", "action": GameState.explore.bind(explore_tags), "keep_open": true}]
	options.append({"label": "Explore for a week (stops when something happens)", "action": GameState.explore_many.bind(7, explore_tags), "keep_open": true})
	options.append_array(event_options())
	return options


## Entries to join the world events under way in this region (LW-003).
static func event_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var data := GameState.data
	for event_id in data.world_events:
		var def: Dictionary = data.world_events[event_id]
		for kind in ["tournament", "defence"]:
			if not def.has(kind) or WorldEvents.instance_in(GameState.world_events, event_id, GameState.current_region).is_empty():
				continue
			var reason := WorldEvents.check_join(data, GameState.world_events, GameState.player, event_id, kind, GameState.current_region)
			var label := ("Enter the %s" if kind == "tournament" else "Defend against the %s") % String(def["name"]).to_lower()
			if reason != "":
				label += " (%s)" % reason
			var action: Callable = GameState.enter_tournament.bind(event_id) if kind == "tournament" else GameState.defend_against_incursion.bind(event_id)
			options.append({"label": label, "action": action, "disabled": reason != "", "keep_open": true})
	return options
