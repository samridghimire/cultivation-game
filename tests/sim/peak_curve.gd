extends SceneTree
## How hard is a late realm's Peak? (QA-113) For each realm from Foundation Establishment to Tribulation
## Transcendence: the typical player's median win% against that realm's own foes (every plain and forced
## appearance whose gate is that realm, foes at their data stage) at the realm's Early and Peak stage, plus the
## stat lines behind it (typical player vs enemies.json realm_training). Prints the first realm whose Peak
## median falls under 50%.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/peak_curve.gd -- [samples]

const Balance := preload("res://tests/sim/combat_balance.gd")
const FIRST_REALM := "foundation_establishment"
const LAST_REALM := "tribulation_transcendence"


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return values[values.size() / 2]


func _pct(v: float) -> String:
	return "  n/a" if v < 0.0 else "%4d%%" % roundi(v * 100)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var samples := int(args[0]) if args.size() > 0 else 100
	var data := GameData.load_from_dir()
	var first := data.realm_index_of(FIRST_REALM)
	var last := data.realm_index_of(LAST_REALM)
	var apps := Balance.appearances(data)
	print("Peak curve, %d fights per foe. Typical player vs the realm's own foes at their data stage." % samples)
	print("  realm                      foes  Early   Peak  | player hp/atk/def at Peak | plain foe hp/atk/def at Peak | training atk/def/hp")
	var first_below := ""
	for r in range(first, last + 1):
		var peak_stage := data.realms[r].stage_count() - 1
		var early: Array[float] = []
		var peak: Array[float] = []
		var foes := 0
		var seen := {}
		for a in apps:
			if a["realm_index"] != r or not data.enemies.has(a["enemy"]) or seen.has(a["enemy"]):
				continue
			seen[a["enemy"]] = true
			var enemy: Dictionary = data.enemies[a["enemy"]]
			foes += 1
			early.append(Balance.win_rate(Balance.typical_player(data, r, 0), data, enemy, samples))
			peak.append(Balance.win_rate(Balance.typical_player(data, r, peak_stage), data, enemy, samples))
		var me := Combat.stats(Balance.typical_player(data, r, peak_stage), data)
		var foe := Combat.enemy_stats(Balance.plain_enemy(data, r, peak_stage), data)
		var tr := Combat.realm_training(data, r)
		var med := _median(peak.duplicate())
		if first_below == "" and med >= 0.0 and med < 0.5:
			first_below = data.realms[r].id
		print("  %-26s %4d %s %s  | %5d/%4d/%4d | %5d/%4d/%4d | %d/%d/%d" % [data.realms[r].id, foes, _pct(_median(early)), _pct(med),
			me["max_hp"], me["attack"], me["defense"], foe["max_hp"], foe["attack"], foe["defense"], int(tr.get("attack", 0)), int(tr.get("defense", 0)), int(tr.get("max_hp", 0))])
	print("First realm whose median Peak win%% is under 50%%: %s" % (first_below if first_below != "" else "none"))
	quit()
