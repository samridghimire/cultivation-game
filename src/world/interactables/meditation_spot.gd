extends Interactable
## A place to cultivate. Denser spiritual energy = faster qi gathering.
## Spouses living in this region can join for dual cultivation (FAM-002b)
## or try for a child (FAM-003c). A breakthrough that brings a Heavenly
## Tribulation opens the TribulationScreen first (TRIB-001b).
## Glimpsed Dao insights can be contemplated here (DAO-001b), and the body
## tempered (BODY-001).

@export var qi_density := 1.0


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{"label": "Meditate (1 month)", "description": GameState.meditation_preview(Calendar.DAYS_PER_MONTH, qi_density), "action": GameState.cultivate.bind(Calendar.DAYS_PER_MONTH, qi_density), "keep_open": true},
		{"label": "Closed-door cultivation (1 year)", "description": GameState.meditation_preview(Calendar.DAYS_PER_YEAR, qi_density), "action": GameState.cultivate.bind(Calendar.DAYS_PER_YEAR, qi_density), "keep_open": true},
	]
	options.append_array(_dual_cultivation_options())
	if Cultivation.can_attempt_breakthrough(GameState.player, GameState.data):
		var chance := Cultivation.breakthrough_chance(GameState.player, GameState.data)
		var odds := Guidance.chance_text(GameState.player, GameState.data)
		var pill_hint := Guidance.pill_source_hint(GameState.player, GameState.data)
		if pill_hint != "":
			odds += "\n" + pill_hint
		if GameState.tribulation_preview()["has_tribulation"]:
			# A tribulation can kill: show the preparation screen before attempting.
			options.append({"label": "Attempt breakthrough (%d%% chance, Heavenly Tribulation!)" % int(chance * 100), "description": odds, "action": EventBus.tribulation_prepare_requested.emit})
		else:
			options.append({"label": "Attempt breakthrough (%d%% chance)" % int(chance * 100), "description": odds, "action": GameState.attempt_breakthrough, "keep_open": true})
	for tech_id in GameState.player.techniques:
		if Techniques.is_mastered(GameState.player, GameState.data, tech_id):
			continue
		var tech_name: String = GameState.data.techniques[tech_id].name
		options.append({"label": "Practice %s (1 month)" % tech_name, "action": GameState.practice_technique.bind(tech_id, Calendar.DAYS_PER_MONTH), "keep_open": true})
	options.append_array(_contemplation_options())
	var temper := _temper_option()
	if not temper.is_empty():
		options.append(temper)
	return options


## "Contemplate the <insight> (1 month)" for each glimpsed Dao insight (DAO-001b).
func _contemplation_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	for insight_id in Dao.known_ids(p, data):
		var label := "Contemplate the %s (1 month) [%s]" % [Dao.def_of(data, insight_id)["name"], Dao.progress_text(p, data, insight_id)]
		var reason := Dao.check_contemplate(p, data, insight_id)
		options.append({"label": label, "action": GameState.contemplate_dao.bind(insight_id, Calendar.DAYS_PER_MONTH), "disabled": reason != "", "reason": reason, "keep_open": true})
	return options


## "Temper your body: <stage> (cost)" with the BodyTempering.check_temper reason
## when disabled; {} once the body is fully tempered.
static func _temper_option() -> Dictionary:
	var p := GameState.player
	var data := GameState.data
	var stage := BodyTempering.next_stage(p, data)
	if stage.is_empty():
		return {}
	var label := "Temper your body: %s (%s)" % [stage["name"], BodyTempering.describe_next(p, data)]
	var reason := BodyTempering.check_temper(p, data)
	return {"label": label, "action": GameState.temper_body, "disabled": reason != "", "reason": reason, "keep_open": true}


func _dual_cultivation_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var p := GameState.player
	var data := GameState.data
	for spouse in Family.spouses_in_region(p, GameState.npcs, data, GameState.current_region):
		var bonus := roundi((Family.dual_multiplier(p, spouse, data) - 1.0) * 100.0)
		var label := "Dual cultivate with %s (1 month, +%d%% qi)" % [spouse.name, bonus]
		var reason := Family.check_dual_cultivation(p, spouse, data)
		options.append({"label": label, "description": GameState.meditation_preview(Calendar.DAYS_PER_MONTH, qi_density * Family.dual_multiplier(p, spouse, data)), "action": GameState.dual_cultivate.bind(spouse.id, Calendar.DAYS_PER_MONTH, qi_density), "disabled": reason != "", "reason": reason, "keep_open": true})
		var child_days := int(Children.rules(data).get("conception_days", 30))
		label = "Try for a child with %s (%s)" % [spouse.name, Calendar.format_duration(child_days)]
		reason = Children.check_conception(p, spouse, data)
		options.append({"label": label, "action": GameState.try_for_child.bind(spouse.id), "disabled": reason != "", "reason": reason, "keep_open": true})
	return options
