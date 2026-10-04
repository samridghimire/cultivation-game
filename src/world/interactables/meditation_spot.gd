extends Interactable
## A place to cultivate. Denser spiritual energy = faster qi gathering.
## Spouses living in this region can join for dual cultivation (FAM-002b)
## or try for a child (FAM-003c). Glimpsed Dao insights can be contemplated here (DAO-001b).

@export var qi_density := 1.0


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{"label": "Meditate (1 month)", "action": GameState.cultivate.bind(Calendar.DAYS_PER_MONTH, qi_density), "keep_open": true},
		{"label": "Closed-door cultivation (1 year)", "action": GameState.cultivate.bind(Calendar.DAYS_PER_YEAR, qi_density), "keep_open": true},
	]
	options.append_array(_dual_cultivation_options())
	if Cultivation.can_attempt_breakthrough(GameState.player, GameState.data):
		var chance := Cultivation.breakthrough_chance(GameState.player, GameState.data)
		options.append({"label": "Attempt breakthrough (%d%% chance)" % int(chance * 100), "action": GameState.attempt_breakthrough, "keep_open": true})
	for tech_id in GameState.player.techniques:
		if Techniques.is_mastered(GameState.player, GameState.data, tech_id):
			continue
		var tech_name: String = GameState.data.techniques[tech_id].name
		options.append({"label": "Practice %s (1 month)" % tech_name, "action": GameState.practice_technique.bind(tech_id, Calendar.DAYS_PER_MONTH), "keep_open": true})
	options.append_array(_contemplation_options())
	return options


## "Contemplate the <insight> (1 month)" for each glimpsed Dao insight (DAO-001b).
func _contemplation_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	for insight_id in Dao.known_ids(p, data):
		var label := "Contemplate the %s (1 month) [%s]" % [Dao.def_of(data, insight_id)["name"], Dao.progress_text(p, data, insight_id)]
		var reason := Dao.check_contemplate(p, data, insight_id)
		if reason != "":
			label += " (%s)" % reason
		options.append({"label": label, "action": GameState.contemplate_dao.bind(insight_id, Calendar.DAYS_PER_MONTH), "disabled": reason != "", "keep_open": true})
	return options


func _dual_cultivation_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	for spouse in Family.spouses_in_region(p, GameState.npcs, data, GameState.current_region):
		var bonus := roundi((Family.dual_multiplier(p, spouse, data) - 1.0) * 100.0)
		var label := "Dual cultivate with %s (1 month, +%d%% qi)" % [spouse.name, bonus]
		var reason := Family.check_dual_cultivation(p, spouse, data)
		if reason != "":
			label += " (%s)" % reason
		options.append({"label": label, "action": GameState.dual_cultivate.bind(spouse.id, Calendar.DAYS_PER_MONTH, qi_density), "disabled": reason != "", "keep_open": true})
		var child_days := int(Children.rules(data).get("conception_days", 30))
		label = "Try for a child with %s (%s)" % [spouse.name, Calendar.format_duration(child_days)]
		reason = Children.check_conception(p, spouse, data)
		if reason != "":
			label += " (%s)" % reason
		options.append({"label": label, "action": GameState.try_for_child.bind(spouse.id), "disabled": reason != "", "keep_open": true})
	return options
