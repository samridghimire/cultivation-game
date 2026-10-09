extends Interactable
## A bounty board (BOUNTY-001, WU-076): lists the hunts posted for the player and
## lets them take one or abandon the active hunt.


## " (here)", " (N days away)" for a direct road, "" for regions further off (WU-092).
static func distance_note(c: CharacterData, data: GameData, from_id: String, to_id: String) -> String:
	if from_id == to_id:
		return " (here)"
	for route: Dictionary in Exploration.routes(c, data, from_id):
		if route["to"] == to_id and route["ok"]:
			return " (%s away)" % Calendar.format_duration(int(route["days"]))
	return ""


func get_options() -> Array[Dictionary]:
	var c: CharacterData = GameState.player
	var data: GameData = GameState.data
	var today := GameClock.total_days
	var options: Array[Dictionary] = []
	for b: Dictionary in Bounties.offers(c, data, today, GameState.current_region):
		var enemy: Dictionary = data.enemies.get(String(b["enemy"]), {})
		var paid := Bounties.paid_stones(c, data, b)
		var pay := "%d stones" % paid
		if paid > int(b["reward_stones"]):
			pay += " (+%d%% for your name)" % int(round((float(paid) / float(b["reward_stones"]) - 1.0) * 100.0))
		var label := "Hunt: %s in %s%s, %s (%s)" % [enemy.get("name", b["enemy"]), Exploration.region_name(data, String(b["region"])), distance_note(c, data, GameState.current_region, String(b["region"])), pay, Appraisal.danger_text(c, data, enemy)]
		var reason := Bounties.check_take(c, data, String(b["id"]), today)
		options.append({"label": label, "description": Warnings.append_to(c, "%s (%s to finish)" % [b["text"], Calendar.format_duration(int(b["days"]))]), "action": GameState.take_bounty.bind(String(b["id"])), "disabled": reason != "", "reason": reason, "keep_open": true})
	var hunt := Bounties.active(c, data, today)
	if not hunt.is_empty():
		var prey: String = data.enemies.get(String(hunt["enemy"]), {}).get("name", hunt["enemy"])
		options.append({"label": "Abandon your hunt (%s)" % prey, "action": GameState.abandon_bounty, "keep_open": true})
	if options.is_empty():
		options.append({"label": "Nothing is posted for you", "disabled": true, "reason": "Come back as you grow stronger.", "action": func() -> void: pass})
	return options
