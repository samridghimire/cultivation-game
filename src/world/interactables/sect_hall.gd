extends Interactable
## Recruitment hall where sects accept (or reject) new disciples, and where
## members open the mission board, attempt promotion trials (G-011b) and spend
## contribution in their sect's shop (Sects.shop_items).


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var player := GameState.player
	if not player.is_rogue():
		var ids := Sects.available_missions(player, GameState.data, GameState.world_flags)
		var ready := ids.filter(func(id: String) -> bool: return Sects.check_mission(player, GameState.data, id, GameState.world_flags) == "").size()
		options.append({"label": "Mission board (%d of %d available)" % [ready, ids.size()], "action": EventBus.mission_board_requested.emit})
		var trial := trial_option()
		if not trial.is_empty():
			options.append(trial)
	for sect: SectDef in GameState.data.sects.values():
		if player.sect.get("id", "") == sect.id:
			options.append({"label": "Leave the %s" % sect.name, "action": GameState.leave_sect, "keep_open": true})
		else:
			var check := Sects.check_join(player, GameState.data, sect.id)
			var label := "Join the %s (%s)" % [sect.name, sect.alignment_tag]
			if not check["ok"]:
				label += " (%s)" % check["reason"]
			options.append({"label": label, "action": GameState.join_sect.bind(sect.id), "disabled": not check["ok"], "keep_open": true})
	options.append({"label": "Balance of power", "action": EventBus.sect_balance_requested.emit})
	options.append_array(shop_options())
	options.append_array(preload("res://src/world/interactables/explore_site.gd").event_options())
	return options


## "Attempt the trial for <rank> (vs <foe>, <danger>)" when the next rank of the
## player's sect has a promotion trial (Sects.check_promotion reason when
## disabled); {} otherwise.
func trial_option() -> Dictionary:
	var player := GameState.player
	var data := GameState.data
	var enemy_id := Sects.trial_enemy(player, data)
	if enemy_id == "":
		return {}
	var sect: SectDef = data.sects[player.sect["id"]]
	var enemy: Dictionary = data.enemies[enemy_id]
	var label := "Attempt the trial for %s (vs %s, %s)" % [sect.rank_name(Sects.next_rank(player, data)), enemy["name"], UIStyle.fight_label(player, data, enemy)]
	var reason := Sects.check_promotion(player, data)
	if reason != "":
		label += " (%s)" % reason
	return {"label": label, "action": GameState.attempt_promotion_trial, "disabled": reason != ""}


## One "Claim <item>" entry per item in the player's sect shop; unavailable
## ones are disabled with the Sects.check_purchase reason.
func shop_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var player := GameState.player
	var data := GameState.data
	for entry in Sects.shop_items(player, data):
		var item_id := String(entry["item_id"])
		var label := "Claim %s (%d of %d contribution)" % [data.items[item_id].get("name", item_id), int(entry["contribution"]), Sects.contribution_balance(player)]
		var reason := Sects.check_purchase(player, data, item_id)
		if reason != "":
			label += " (%s)" % reason
		options.append({"label": label, "action": GameState.buy_with_contribution.bind(item_id), "disabled": reason != "", "keep_open": true})
	return options
