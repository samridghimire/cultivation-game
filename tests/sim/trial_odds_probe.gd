extends SceneTree
## Trial odds probe (QA-133): replays curious seed 11 and, every month the sect trial is open, prints the odds, the unhurt odds and the odds at stages 4..11.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/trial_odds_probe.gd

const FirstHour := preload("res://tests/sim/first_hour.gd")


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var hook := func(month: int) -> void:
		var p: CharacterData = gs.player
		if p.sect.is_empty() or Sects.check_promotion(p, gs.data) != "":
			return
		var eid := Sects.trial_enemy(p, gs.data)
		var opp := Sects.trial_opponent(gs.data, eid)
		print("m%02d %s stage %d injuries %s trial_odds %.2f unhurt %.2f clause: %s" % [month + 1, Cultivation.realm_label(p, gs.data), p.stage, str(p.injuries.keys()), Guidance.trial_odds(p, gs.data), Guidance.odds_unhurt(p, gs.data, opp), Guidance._trial_odds_clause(p, gs.data)])
		print("   techs ", str(p.techniques), " enemy ", str(opp))
		var copy := CharacterData.from_dict(p.to_dict())
		copy.injuries.clear()
		for st in range(4, 12):
			copy.stage = st
			print("   stage %d unhurt odds %.2f" % [st, Combat.win_chance(copy, gs.data, opp)])
	FirstHour.play(gs, clock, 11, 12, true, hook)
	quit()
