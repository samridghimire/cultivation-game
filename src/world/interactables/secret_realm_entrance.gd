extends Interactable
## The entrance to the region's secret realms (W-005b, data/secret_realms.json).
## Lists each realm whose entrance is in the current region with its status and,
## while it is open, a "Delve into floor N" entry (GameState.enter_secret_realm).


## The rift glows while any realm here is open (W-005e).
func art_active() -> bool:
	return GameState.data != null and SecretRealms.open_in_region(GameState.data, GameState.current_region, GameClock.total_days)


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var c := GameState.player
	var data := GameState.data
	var today: int = GameClock.total_days
	for realm_id in SecretRealms.in_region(data, GameState.current_region):
		var def := SecretRealms.realm(data, realm_id)
		options.append({"label": "%s: %s" % [def["name"], SecretRealms.status_text(c, data, realm_id, today)], "action": func(): pass, "disabled": true})
		if not SecretRealms.is_open(def, today):
			continue
		var floor_def := SecretRealms.next_floor(c, def, today)
		if floor_def.is_empty():
			continue
		options.append(delve_option(c, data, realm_id, today))
	if options.is_empty():
		options.append({"label": "The air ripples, but no realm answers.", "action": func(): pass, "disabled": true})
	return options


## The "Delve into floor N" entry for an open realm with floors left.
static func delve_option(c: CharacterData, data: GameData, realm_id: String, today: int) -> Dictionary:
	var def := SecretRealms.realm(data, realm_id)
	var floor_def := SecretRealms.next_floor(c, def, today)
	var floor_count: int = (def.get("floors", []) as Array).size()
	var notes: PackedStringArray = [Calendar.format_duration(int(floor_def.get("days", 1)))]
	var guardian := String(floor_def.get("guardian", ""))
	if guardian != "" and data.enemies.has(guardian):
		var enemy: Dictionary = data.enemies[guardian]
		notes.append("guardian: %s, %s" % [enemy.get("name", guardian), Combat.danger_label(c, data, enemy)])
	var cost := SecretRealms.entry_cost(c, def, today)
	if cost > 0:
		notes.append("entry %d spirit stones" % cost)
	var label := "Delve into floor %d/%d, %s (%s)" % [SecretRealms.floors_cleared(c, def, today) + 1, floor_count, floor_def.get("name", ""), ", ".join(notes)]
	var reason := SecretRealms.check_enter(c, data, realm_id, GameState.current_region, today)
	if reason != "":
		label += " [%s]" % reason
	return {"label": label, "action": GameState.enter_secret_realm.bind(realm_id), "disabled": reason != "", "keep_open": true}
