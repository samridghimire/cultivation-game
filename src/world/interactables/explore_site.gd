extends Interactable
## A wild place to search for herbs, treasures and trouble. Encounters come
## from data/encounters.json, chosen by tag.

## Encounter tags for this spot. Empty = the region's encounter_tags.
@export var explore_tags: Array = []


func get_options() -> Array[Dictionary]:
	var outlook := GameState.explore_outlook(explore_tags)
	var known := familiarity_line(GameState.player, GameState.data, GameState.current_region)
	if known != "":
		outlook += "\n" + known
	outlook += quarry_note(GameState.player, GameState.data, GameState.current_region, GameClock.total_days)
	var options: Array[Dictionary] = [{"label": "Explore", "description": outlook, "action": GameState.explore.bind(explore_tags), "keep_open": true}]
	options.append({"label": "Explore for a week (stops when something happens)", "description": outlook, "action": GameState.explore_many.bind(7, explore_tags), "keep_open": true})
	options.append_array(event_options())
	return options


## Ends the Explore descriptions when the active bounty's quarry roams this region (WU-082).
static func quarry_note(c: CharacterData, data: GameData, region_id: String, today: int) -> String:
	var b := Bounties.active(c, data, today)
	if b.is_empty() or String(b["region"]) != region_id:
		return ""
	return "\nYour quarry's trail may be found here."


## How well you know this region's paths, and when a deeper one may open (WU-078).
static func familiarity_line(c: CharacterData, data: GameData, region_id: String) -> String:
	var days := Exploration.familiarity(c, region_id)
	var deeper := Exploration.next_deep_path(c, data, region_id)
	var line := ""
	if days >= 1:
		line = "You know these paths well (%d day%s explored)." % [days, "" if days == 1 else "s"]
	if deeper >= 0:
		line += " Something deeper may open after %d days." % deeper
	return line.strip_edges()


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
			if reason == "":
				var foe := WorldEvents.opponent(data, event_id, kind, GameState.player, 0, RandomNumberGenerator.new())
				label += " (%s)" % Appraisal.danger_text(GameState.player, data, foe)
			var action: Callable = GameState.enter_tournament.bind(event_id) if kind == "tournament" else GameState.defend_against_incursion.bind(event_id)
			options.append({"label": label, "action": action, "disabled": reason != "", "reason": reason, "keep_open": true})
	return options
