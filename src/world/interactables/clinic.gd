extends Interactable
## A clinic: work as a Doctor treating patients, treat your own injuries
## (trains Doctor), or pay the resident doctor to heal an injury outright.


func get_options() -> Array[Dictionary]:
	var c: CharacterData = GameState.player
	var data: GameData = GameState.data
	var options: Array[Dictionary] = [
		{"label": "Treat patients (1 month) [%s]" % Professions.rank_title(c, data, Medicine.DOCTOR), "action": GameState.treat_patients.bind(Calendar.DAYS_PER_MONTH), "keep_open": true},
	]
	var self_days := int(data.medicine.get("self_treatment_days", 7))
	var power := Medicine.self_treatment_power(c, data)
	var stones := c.item_count("spirit_stone")
	for injury_id: String in c.injuries:
		var injury_name := Injuries.injury_name(data, injury_id)
		var left := Calendar.format_duration(int(c.injuries[injury_id]))
		options.append({"label": "Treat your %s (%s, heals %s; %s left)" % [injury_name, Calendar.format_duration(self_days), Calendar.format_duration(power), left], "action": GameState.treat_own_injury.bind(injury_id), "disabled": power <= 0, "keep_open": true})
		var cost := Medicine.clinic_cost(c, data, injury_id)
		var label := "Pay the doctor to heal your %s (%d spirit stones)" % [injury_name, cost]
		if stones < cost:
			label += " (you have %d)" % stones
		options.append({"label": label, "action": GameState.visit_clinic.bind(injury_id), "disabled": stones < cost, "keep_open": true})
	return options
