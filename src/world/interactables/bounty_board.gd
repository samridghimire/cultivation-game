extends Interactable
## A bounty board (BOUNTY-001, WU-076): lists the hunts posted for the player and
## lets them take one or abandon the active hunt.


func get_options() -> Array[Dictionary]:
	var c: CharacterData = GameState.player
	var data: GameData = GameState.data
	var today := GameClock.total_days
	var options: Array[Dictionary] = []
	for b: Dictionary in Bounties.offers(c, data, today):
		var enemy: Dictionary = data.enemies.get(String(b["enemy"]), {})
		var label := "Hunt: %s in %s, %d stones (%s)" % [enemy.get("name", b["enemy"]), Exploration.region_name(data, String(b["region"])), int(b["reward_stones"]), Appraisal.danger_text(c, data, enemy)]
		var reason := Bounties.check_take(c, data, String(b["id"]), today)
		options.append({"label": label, "description": "%s (%s to finish)" % [b["text"], Calendar.format_duration(int(b["days"]))], "action": GameState.take_bounty.bind(String(b["id"])), "disabled": reason != "", "reason": reason, "keep_open": true})
	var hunt := Bounties.active(c, data, today)
	if not hunt.is_empty():
		var prey: String = data.enemies.get(String(hunt["enemy"]), {}).get("name", hunt["enemy"])
		options.append({"label": "Abandon your hunt (%s)" % prey, "action": GameState.abandon_bounty, "keep_open": true})
	if options.is_empty():
		options.append({"label": "Nothing is posted for you", "disabled": true, "reason": "Come back as you grow stronger.", "action": func() -> void: pass})
	return options
