extends Interactable
## Recruitment hall where sects accept (or reject) new disciples, and where
## members open the mission board, attempt promotion trials (G-011b) and spend
## contribution in their sect's shop (Sects.shop_items).


## "leave" or "join:<sect id>" while the menu asks "are you sure?" (WU-032).
var _pending := ""


func on_menu_closed() -> void:
	_pending = ""


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var player := GameState.player
	if _pending != "":
		return _confirm_options()
	if not player.is_rogue():
		var ids := Sects.available_missions(player, GameState.data, GameState.world_flags)
		var ready := ids.filter(func(id: String) -> bool: return Sects.check_mission(player, GameState.data, id, GameState.world_flags) == "").size()
		options.append({"label": "Mission board (%d of %d available)" % [ready, ids.size()], "action": EventBus.mission_board_requested.emit})
		var trial := trial_option()
		if not trial.is_empty():
			options.append(trial)
	for sect: SectDef in GameState.data.sects.values():
		if player.sect.get("id", "") == sect.id:
			options.append({"label": "Leave the %s" % sect.name, "action": _ask.bind("leave"), "keep_open": true})
		else:
			var check := Sects.check_join(player, GameState.data, sect.id)
			var label := "Join the %s (%s)" % [sect.name, sect.alignment_tag]
			options.append({"label": label, "action": _ask.bind("join:" + sect.id), "disabled": not check["ok"], "reason": "" if check["ok"] else check["reason"], "keep_open": true})
	options.append({"label": "Balance of power", "action": EventBus.sect_balance_requested.emit})
	options.append_array(shop_options())
	options.append_array(preload("res://src/world/interactables/explore_site.gd").event_options())
	return options


func _ask(what: String) -> void:
	_pending = what


## "No" first (so gamepad focus lands on the safe choice), then "Yes".
func _confirm_options() -> Array[Dictionary]:
	var text := confirm_text(GameState.player, GameState.data, _pending)
	var yes: Callable = GameState.leave_sect if _pending == "leave" else GameState.join_sect.bind(_pending.trim_prefix("join:"))
	var yes_label := "Yes, leave the sect" if _pending == "leave" else "Yes, join the sect"
	return [
		{"label": "No", "action": _ask.bind(""), "keep_open": true, "description": text},
		{"label": yes_label, "action": func() -> void:
			_pending = ""
			yes.call(), "keep_open": true, "description": text},
	]


## What the player gives up (leave) or takes on (join "join:<id>").
static func confirm_text(player: CharacterData, data: GameData, what: String) -> String:
	if what == "leave":
		var sect: SectDef = data.sects.get(String(player.sect.get("id", "")))
		if sect == null:
			return "Leave your sect?"
		var text := "Leave %s? You lose your rank (%s), %d contribution and standing with the sect." % [sect.name, sect.rank_name(int(player.sect.get("rank", 0))), int(player.sect.get("contribution", 0))]
		var penalty := int(data.sect_reputation.get("leave_penalty", 0))
		if penalty > 0:
			text += " Your reputation with them drops by %d." % penalty
		return text
	var join: SectDef = data.sects.get(what.trim_prefix("join:"))
	if join == null:
		return "Join this sect?"
	var duty := ""
	if not join.ranks.is_empty() and int(join.ranks[0].get("monthly_duty", 0)) > 0:
		duty = " Monthly duty: %d contribution." % int(join.ranks[0]["monthly_duty"])
	return "Join %s (%s sect)?%s You can leave later, at a cost." % [join.name, join.alignment_tag, duty]


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
	return {"label": label, "action": GameState.attempt_promotion_trial, "disabled": reason != "", "reason": reason}


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
		options.append({"label": label, "action": GameState.buy_with_contribution.bind(item_id), "disabled": reason != "", "reason": reason, "keep_open": true})
	return options
