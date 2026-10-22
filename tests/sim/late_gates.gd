extends SceneTree
## Late-realm fight gates (QA-106, QA-110): every fight encounter, enemy choice and inheritance
## guardian from Soul Formation to Tribulation Transcendence, with its gate and the typical player's win rate at the
## gate's lowest stage. Flags forced fights (non-lethal, so never slipped away from; choices are opt-in)
## under 20% and names the first stage that clears 20%. Inheritance guardians are forced but never lethal
## and can be retried, so they are listed only.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/late_gates.gd -- [samples]

const Balance := preload("res://tests/sim/combat_balance.gd")
const FIRST_REALM := "soul_formation"
const LAST_REALM := "tribulation_transcendence"
const FLAG_BELOW := 0.2


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


## The lowest stage (within the gate's realm) at which the typical player wins >= FLAG_BELOW, or "none".
func _first_ok_stage(data: GameData, f: Dictionary, enemy: Dictionary, samples: int) -> String:
	var realm: int = f["realm"]
	for stage in range(int(f["stage"]), data.realms[realm].stage_count()):
		if Balance.win_rate(Balance.typical_player(data, realm, stage), data, enemy, samples) >= FLAG_BELOW:
			return "stage %d" % stage
	return "none"


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var samples := int(args[0]) if args.size() > 0 else 200
	var data := GameData.load_from_dir()
	var first := data.realm_index_of(FIRST_REALM)
	var last := data.realm_index_of(LAST_REALM)
	print("Late-realm fight gates, %d fights per row. Typical player at the gate's lowest stage." % samples)
	print("  realm      encounter                         foe                    gate  tags                 lethal  win%  escape  flag")
	var flagged := 0
	for enc_id: String in data.encounters:
		var enc: Dictionary = data.encounters[enc_id]
		var min_realm := maxi(0, data.realm_index_of(String(enc.get("min_realm", "mortal"))))
		var fights: Array = []
		if enc.has("enemy"):
			fights.append({"enemy": String(enc["enemy"]), "choice": false, "realm": min_realm, "stage": int(enc.get("min_stage", 0))})
		for choice: Dictionary in enc.get("choices", []):
			if choice.has("enemy"):
				var need := maxi(min_realm, data.realm_index_of(String(choice.get("requires", {}).get("min_realm", "mortal"))))
				fights.append({"enemy": String(choice["enemy"]), "choice": true, "realm": need, "stage": int(enc.get("min_stage", 0)) if need == min_realm else 0})
		for f: Dictionary in fights:
			if f["realm"] < first or f["realm"] > last or not data.enemies.has(f["enemy"]):
				continue
			var enemy: Dictionary = data.enemies[f["enemy"]]
			var win := Balance.win_rate(Balance.typical_player(data, f["realm"], f["stage"]), data, enemy, samples)
			var lethal: bool = enemy.get("lethal", false)
			var evadable: bool = lethal and not f["choice"]
			var forced: bool = not lethal and not f["choice"]
			var flag: bool = forced and win < FLAG_BELOW
			flagged += 1 if flag else 0
			print("  %-10s %-33s %-22s %s/%d  %-20s %-6s %4d%%  %-6s %s" % [data.realms[f["realm"]].id.substr(0, 10), enc_id.substr(0, 33), f["enemy"].substr(0, 22), data.realms[f["realm"]].id.substr(0, 4), f["stage"],
				",".join(PackedStringArray(enc.get("tags", []))).substr(0, 20), "yes" if lethal else "no", roundi(win * 100), "yes" if evadable else "no", ("FLAG, 20%%+ from %s" % _first_ok_stage(data, f, enemy, samples)) if flag else ("choice" if f["choice"] else "")])
	for inh: Dictionary in data.inheritances.values():
		var gate_realm := 0
		var gate_stage := 0
		var enemy_id := ""
		for stage: Dictionary in inh.get("stages", []):
			if stage.get("test", "") == "realm":
				var r := data.realm_index_of(String(stage.get("min_realm", "mortal")))
				if r > gate_realm:
					gate_realm = r
					gate_stage = int(stage.get("min_stage", 0))
				elif r == gate_realm:
					gate_stage = maxi(gate_stage, int(stage.get("min_stage", 0)))
			elif stage.get("test", "") == "fight":
				enemy_id = String(stage.get("enemy", ""))
		if gate_realm < first or gate_realm > last or not data.enemies.has(enemy_id):
			continue
		var win := Balance.win_rate(Balance.typical_player(data, gate_realm, gate_stage), data, data.enemies[enemy_id], samples)
		print("  %-10s %-33s %-22s %s/%d  %-20s %-6s %4d%%  %-6s inheritance (retry)" % [data.realms[gate_realm].id.substr(0, 10), String(inh["id"]).substr(0, 33), enemy_id.substr(0, 22), data.realms[gate_realm].id.substr(0, 4), gate_stage,
			"inheritance", "no", roundi(win * 100), "no"])
	print("flagged: %d" % flagged)
	quit()
