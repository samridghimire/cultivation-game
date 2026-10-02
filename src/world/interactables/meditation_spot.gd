extends Interactable
## A place to cultivate. Denser spiritual energy = faster qi gathering.

@export var qi_density := 1.0


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{"label": "Meditate (1 month)", "action": GameState.cultivate.bind(Calendar.DAYS_PER_MONTH, qi_density), "keep_open": true},
		{"label": "Closed-door cultivation (1 year)", "action": GameState.cultivate.bind(Calendar.DAYS_PER_YEAR, qi_density), "keep_open": true},
	]
	if Cultivation.can_attempt_breakthrough(GameState.player, GameState.data):
		var chance := Cultivation.breakthrough_chance(GameState.player, GameState.data)
		options.append({"label": "Attempt breakthrough (%d%% chance)" % int(chance * 100), "action": GameState.attempt_breakthrough, "keep_open": true})
	for tech_id in GameState.player.techniques:
		if Techniques.is_mastered(GameState.player, GameState.data, tech_id):
			continue
		var tech_name: String = GameState.data.techniques[tech_id].name
		options.append({"label": "Practice %s (1 month)" % tech_name, "action": GameState.practice_technique.bind(tech_id, Calendar.DAYS_PER_MONTH), "keep_open": true})
	return options
