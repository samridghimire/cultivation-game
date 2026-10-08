extends Interactable
## The Family Home (FAM-011): drawn in a region where the player's living
## spouses or children live (regions.json "family_home"). Spend time with the
## family there, bring the rest of the household under this roof, or open the
## family tree. Rules live in FamilyHome.


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	if p == null:
		return options
	var region := GameState.current_region
	var rules: Dictionary = data.family.get("home", {})
	var here := FamilyHome.at_home(p, GameState.npcs, data, region)
	var visit_reason := FamilyHome.check_visit(p, GameState.npcs, data, region)
	var visit_label := "Spend %s with your family" % Calendar.format_duration(int(rules.get("visit_days", 1)))
	if visit_reason == "" and not here.is_empty():
		visit_label += " (%s)" % ", ".join(here.map(func(c: CharacterData) -> String: return c.name))
	options.append({"label": visit_label, "action": GameState.visit_family_home, "disabled": visit_reason != "", "reason": visit_reason, "keep_open": true})
	var move_reason := FamilyHome.check_move(p, GameState.npcs, data, region)
	var move_label := "Bring your household here (%s)" % Calendar.format_duration(int(rules.get("move_days", 1)))
	if move_reason == "":
		var movers := FamilyHome.movers(p, GameState.npcs, data, region)
		move_label += ": %s" % ", ".join(movers.map(func(c: CharacterData) -> String: return c.name))
	options.append({"label": move_label, "action": GameState.move_household_here, "disabled": move_reason != "", "reason": move_reason, "keep_open": true})
	options.append({"label": "Family tree", "action": func(): EventBus.family_requested.emit()})
	return options

