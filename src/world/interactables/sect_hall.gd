extends Interactable
## Recruitment hall where sects accept (or reject) new disciples.


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
	return options
