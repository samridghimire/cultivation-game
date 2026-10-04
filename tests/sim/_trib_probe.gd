extends SceneTree
const Trib := preload("res://tests/sim/tribulation_balance.gd")
const Balance := preload("res://tests/sim/combat_balance.gd")
func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)
func _run() -> void:
	var data := GameData.load_from_dir()
	for i in 10:
		print("rp(%d)=%s" % [i, Combat.realm_power(i, 0)])
	for realm in Trib.tribulation_realms(data):
		var c := Trib.attempter(data, realm, "typical")
		var p := Tribulation.preview(c, data, realm)
		var best := Balance.best_talisman(data, realm - 1, "shield")
		print("%s E=%d hp=%d best=%s amount=%d" % [data.realms[realm].name, p["expected_damage"], p["max_hp"], best, CombatTalismans.amount(data, best) if best != "" else 0])
	quit()
