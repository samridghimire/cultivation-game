extends SceneTree
## Per-stage win rates (G-008f): a typical player (combat_balance.gd) at each
## stage of an enemy's realm vs that enemy, to pick min_stage for missions and
## encounters. Usage:
## tools/godot.sh --headless --path . -s res://tests/sim/simulate_stage_rates.gd -- enemy_id [enemy_id ...]

const Balance := preload("res://tests/sim/combat_balance.gd")
const SAMPLES := 200


func _init() -> void:
	var data := GameData.load_from_dir()
	for enemy_id in OS.get_cmdline_user_args():
		if not data.enemies.has(enemy_id):
			print("unknown enemy %s" % enemy_id)
			continue
		var e: Dictionary = data.enemies[enemy_id]
		var realm := data.realm_index_of(e["realm"])
		var line := "%-24s" % enemy_id
		for stage in data.realms[realm].stage_count():
			line += " s%d:%3d%%" % [stage, roundi(100 * Balance.win_rate(Balance.typical_player(data, realm, stage), data, e, SAMPLES))]
		print(line)
	quit()
