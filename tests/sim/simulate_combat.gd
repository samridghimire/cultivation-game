extends SceneTree
## Combat balance sim (QA-007): a typical player (see combat_balance.gd) at the
## realm where each enemy first appears vs that enemy, plus a realm-by-enemy
## win-rate grid. Flags enemies that are trivial or unbeatable where they appear.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_combat.gd -- [samples]

const Balance := preload("res://tests/sim/combat_balance.gd")
## Realms shown in the grid (Mortal .. this index).
const GRID_REALMS := 5


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var samples := int(args[0]) if args.size() > 0 else 200
	var data := GameData.load_from_dir()
	print("Combat balance, %d fights per cell. Typical player: attributes 10, Iron Fist + Stone Skin, best buyable gear." % samples)
	print("")
	print("Where each enemy first appears (typical player entering the realm / at its peak / entering with talismans; bare player entering):")
	var seen := {}
	for a: Dictionary in Balance.appearances(data):
		seen[a["enemy"]] = true
		var r := Balance.rate(data, a, samples)
		var note := ""
		if r["verdict"] == "unbeatable" and not a["forced"]:
			note = " (lethal: a Deadly foe is sensed and evaded)"
		print("  %-9s %-22s %-28s %-24s entry %3d%%  peak %3d%%  talisman %3d%%  bare %3d%%  %s%s" % [
			data.realms[a["realm_index"]].name.substr(0, 9), a["enemy"], a["source"].substr(0, 28), "forced" if a["forced"] else "evadable",
			roundi(r["entry"] * 100), roundi(r["peak"] * 100), roundi(r["talisman"] * 100), roundi(r["bare"] * 100), r["verdict"].to_upper(), note])
	for enemy_id: String in data.enemies:
		if not seen.has(enemy_id):
			print("  UNUSED   %s never appears in an encounter or mission" % enemy_id)
	print("")
	var header := "  %-22s" % "enemy \\ player"
	for realm in mini(GRID_REALMS, data.realms.size()):
		header += " %10s" % data.realms[realm].name.substr(0, 10)
	print("Win rate at stage 0 of each realm (no talismans):")
	print(header)
	for enemy_id: String in data.enemies:
		var line := "  %-22s" % enemy_id
		for realm in mini(GRID_REALMS, data.realms.size()):
			line += " %9d%%" % roundi(Balance.win_rate(Balance.typical_player(data, realm, 0), data, data.enemies[enemy_id], samples) * 100)
		print(line)
	print("")
	print("Typical player vs a plain enemy of the same realm and stage (QA-007d target ~60-90%), and at the realm's peak vs a plain enemy one realm up:")
	for realm in range(1, mini(GRID_REALMS, data.realms.size() - 1)):
		var peak := data.realms[realm].stage_count() - 1
		var line := "  %-22s" % data.realms[realm].name
		for stage in [0, peak / 2, peak]:
			line += "  stage %d: %3d%%" % [stage, roundi(Balance.same_stage_rate(data, realm, stage, samples) * 100)]
		var up := Balance.win_rate(Balance.typical_player(data, realm, peak), data, Balance.plain_enemy(data, realm + 1, 0), samples)
		print(line + "   next realm: %3d%%" % roundi(up * 100))
	quit()
