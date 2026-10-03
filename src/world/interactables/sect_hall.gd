extends Interactable
## Recruitment hall where sects accept (or reject) new disciples, and where
## members spend contribution in their sect's shop (Sects.shop_items).


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var player := GameState.player
	for sect: SectDef in GameState.data.sects.values():
		if player.sect.get("id", "") == sect.id:
			options.append({"label": "Leave the %s" % sect.name, "action": GameState.leave_sect, "keep_open": true})
		else:
			var check := Sects.check_join(player, GameState.data, sect.id)
			var label := "Join the %s (%s)" % [sect.name, sect.alignment_tag]
			options.append({"label": label, "action": GameState.join_sect.bind(sect.id), "disabled": not check["ok"], "keep_open": true})
	options.append_array(shop_options())
	return options


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
