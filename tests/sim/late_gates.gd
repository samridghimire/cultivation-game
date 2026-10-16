extends SceneTree
## Late-realm fight gates (QA-106): every fight encounter and enemy choice from Soul Formation to
## Body Integration, with its gate and the typical player's win rate at the gate's lowest stage.
## Flags foes the player cannot slip away from (non-lethal, or a choice) at under 20%.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/late_gates.gd -- [samples]

const Balance := preload("res://tests/sim/combat_balance.gd")
const FIRST_REALM := "soul_formation"
const LAST_REALM := "body_integration"
const FLAG_BELOW := 0.2


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


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
			var flag := lethal and not evadable and win < FLAG_BELOW
			flagged += 1 if flag else 0
			print("  %-10s %-33s %-22s %s/%d  %-20s %-6s %4d%%  %-6s %s" % [data.realms[f["realm"]].id.substr(0, 10), enc_id.substr(0, 33), f["enemy"].substr(0, 22), data.realms[f["realm"]].id.substr(0, 4), f["stage"],
				",".join(PackedStringArray(enc.get("tags", []))).substr(0, 20), "yes" if lethal else "no", roundi(win * 100), "yes" if evadable else "no", "FLAG" if flag else ""])
	print("flagged: %d" % flagged)
	quit()
