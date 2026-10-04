extends Interactable
## An NPC: a named one from data/npcs.json or a generated one (Npcs.spawn,
## no def), who can be looked at. Talking opens its dialogue: in the dialogue
## window if one listens to EventBus.dialogue_requested, otherwise inline in
## this menu (each line is posted to the message log).
## Eligible partners also offer Court / Propose entries (FAM-002d); disabled
## entries show why (Family.check_court / check_proposal).
## Injured NPCs offer "Treat <name>'s <injury>" (G-007d, Medicine.check_treat_npc)
## and "Look" lists their injuries.
## Orphaned children offer "Adopt <name>" (FAM-003e, Adoption.check_adoption).
## Hostile acts (RIV-001d: humiliate, rob, kill) hide behind a "Turn hostile"
## entry so a stray button press never kills anyone; "Make amends" appears
## while the NPC holds a grudge (Karma.check_act / check_amends reasons).

@export var npc_id := ""

## Set when an inline conversation ends, so the menu does not restart it.
var _just_ended := false
## True while the hostile-act entries are shown instead of the normal menu.
var _hostile := false


func is_available() -> bool:
	var npc: CharacterData = GameState.npcs.get(npc_id)
	return npc != null and npc.alive


func get_options() -> Array[Dictionary]:
	if _hostile:
		return _hostile_options()
	var options: Array[Dictionary] = []
	var def: Dictionary = GameState.data.npcs.get(npc_id, {})
	if def.is_empty():
		options.append({"label": "Look", "action": _look, "keep_open": true})
	if GameState.has_dialogue(npc_id):
		if _has_dialogue_window():
			options.append({"label": "Talk", "action": GameState.start_dialogue.bind(npc_id)})
		else:
			options.append_array(_inline_dialogue_options())
	if def.has("deed_context"):
		for deed in Deeds.available(GameState.data, def["deed_context"], GameState.world_flags):
			options.append({"label": deed["name"], "action": GameState.perform_deed.bind(deed["id"])})
	options.append_array(_treatment_options())
	options.append_array(_adoption_options())
	options.append_array(_courtship_options())
	options.append_array(_karma_options())
	return options


## One entry treating the NPC's worst injury, only while they are injured.
func _treatment_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var npc: CharacterData = GameState.npcs.get(npc_id)
	if GameState.player == null or npc == null:
		return options
	var injury_id := Medicine.worst_injury(npc)
	if injury_id == "":
		return options
	var days := int(GameState.data.medicine.get("npc_treatment_days", 3))
	var label := "Treat %s's %s (%s)" % [npc.name, Injuries.injury_name(GameState.data, injury_id).to_lower(), Calendar.format_duration(days)]
	var reason := Medicine.check_treat_npc(GameState.player, npc)
	options.append(_entry(label, reason, GameState.treat_npc.bind(npc_id)))
	return options


## "Adopt <name>" for orphaned children young enough to adopt, not already the player's.
func _adoption_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	var child: CharacterData = GameState.npcs.get(npc_id)
	if p == null or child == null or Adoption.rules(data).is_empty():
		return options
	if child.age_years() > int(Adoption.rules(data).get("max_age", 12)) or child.parents.has(p.id) or not Adoption.is_orphan(child, GameState.npcs):
		return options
	var days := int(Adoption.rules(data).get("days", 1))
	var label := "Adopt %s (%s)" % [child.name, Calendar.format_duration(days)]
	options.append(_entry(label, Adoption.check_adoption(p, child, GameState.npcs, data), GameState.adopt.bind(npc_id)))
	return options


## "Make amends" while the NPC holds a grudge, and the "Turn hostile" entry
## for adults who are not family (other targets would only show refusals).
func _karma_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	var npc: CharacterData = GameState.npcs.get(npc_id)
	if p == null or npc == null or data.karma.is_empty():
		return options
	var cost := Karma.amends_cost(p, npc_id, data)
	if cost > 0:
		var label := "Make amends with %s (%d stones, grudge %d)" % [npc.name, cost, Karma.grudge(p, npc_id)]
		options.append(_entry(label, Karma.check_amends(p, npc, data), GameState.make_amends.bind(npc_id)))
	for act_id in Karma.act_ids(data):
		if Karma.check_act(p, npc, act_id, data) == "":
			options.append({"label": "Turn hostile...", "action": _set_hostile.bind(true), "keep_open": true})
			break
	return options


## One entry per karma act: fights show Combat.danger_label of the NPC, and
## every entry names its alignment cost. "Back" returns to the normal menu.
func _hostile_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	var npc: CharacterData = GameState.npcs.get(npc_id)
	if p == null or npc == null or not npc.alive:
		_hostile = false
		return options
	for act_id in Karma.act_ids(data):
		var act := Karma.act(data, act_id)
		var bits: PackedStringArray = []
		if bool(act.get("fight", false)):
			bits.append("fight: %s" % Combat.danger_label(p, data, Karma.npc_enemy(npc, data)))
		if int(act.get("alignment", 0)) != 0:
			bits.append("alignment %+d" % int(act["alignment"]))
		var label := "%s %s" % [String(act.get("name", act_id)), npc.name]
		if not bits.is_empty():
			label += " [%s]" % ", ".join(bits)
		var reason := Karma.check_act(p, npc, act_id, data)
		options.append(_entry(label, reason, _commit_hostile.bind(act_id)))
	options.append({"label": "Back", "action": _set_hostile.bind(false), "keep_open": true})
	return options


func _on_body_exited(body: Node2D) -> void:
	super(body)
	if body is Player:
		_hostile = false


func _set_hostile(on: bool) -> void:
	_hostile = on


func _commit_hostile(act_id: String) -> void:
	_hostile = false
	GameState.hostile_act(npc_id, act_id)


## Court and one Propose entry per spousal rank, only for NPCs the player
## could pursue at all (Family.check_partner), so children, the married and
## the wrong gender do not clutter the menu.
func _courtship_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	var npc: CharacterData = GameState.npcs.get(npc_id)
	if p == null or Family.check_partner(p, npc, data, GameState.npcs) != "":
		return options
	var favor := int(GameState.npc_favor.get(npc_id, 0))
	var days := int(data.family.get("courtship", {}).get("days", 1))
	var label := "Court %s (%s, favor %d)" % [npc.name, Calendar.format_duration(days), favor]
	var reason := Family.check_court(p, npc, favor, data, GameState.npcs)
	options.append(_entry(label, reason, GameState.court.bind(npc_id)))
	for rank in Family.ranks(data, p.gender):
		label = "Propose to %s as your %s" % [npc.name, Family.rank_name(data, p.gender, rank).to_lower()]
		reason = Family.check_proposal(p, npc, favor, rank, data, GameState.npcs)
		options.append(_entry(label, reason, GameState.propose.bind(npc_id, rank)))
	return options


func _entry(label: String, reason: String, action: Callable) -> Dictionary:
	if reason != "":
		label += " (%s)" % reason
	return {"label": label, "action": action, "disabled": reason != "", "keep_open": true}


func _look() -> void:
	var npc: CharacterData = GameState.npcs.get(npc_id)
	if npc == null:
		return
	var text := Npcs.describe(npc, GameState.data)
	var injuries := Injuries.describe(npc, GameState.data)
	if not injuries.is_empty():
		text += " Injuries: %s." % ", ".join(injuries)
	EventBus.post(text)


func _has_dialogue_window() -> bool:
	return not EventBus.dialogue_requested.get_connections().is_empty()


func _inline_dialogue_options() -> Array[Dictionary]:
	if _just_ended:
		_just_ended = false
		return []
	if GameState.dialogue_npc != npc_id:
		GameState.start_dialogue(npc_id)
		_post_line()
	var options: Array[Dictionary] = []
	var view := GameState.dialogue_view()
	for choice: Dictionary in view.get("choices", []):
		var label: String = choice["label"]
		if choice["disabled"]:
			label += " (%s)" % choice["reason"]
		options.append({"label": label, "action": _choose.bind(choice["index"]), "disabled": choice["disabled"], "keep_open": true})
	return options


func _choose(index: int) -> void:
	GameState.choose_dialogue(index)
	if GameState.dialogue_npc == npc_id:
		_post_line()
	else:
		_just_ended = true


func _post_line() -> void:
	var view := GameState.dialogue_view()
	if not view.is_empty():
		EventBus.post("%s: \"%s\"" % [view["speaker"], view["text"]])
