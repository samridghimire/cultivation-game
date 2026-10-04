extends SceneTree
## Tribulation balance sim (QA-010): survival / failure / death odds for each
## realm with a Heavenly Tribulation, per cultivator profile (see
## tribulation_balance.gd) and alignment (heart demon).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_tribulation.gd -- [samples]

const Trib := preload("res://tests/sim/tribulation_balance.gd")
const ALIGNMENTS: Array[int] = [0, -300, -600, -1000]


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var samples := int(args[0]) if args.size() > 0 else 400
	var data := GameData.load_from_dir()
	print("Tribulation odds, %d tribulations per cell: survive / fail (injured) / die. Attempter at the previous realm's peak." % samples)
	for realm in Trib.tribulation_realms(data):
		print("")
		var preview := Tribulation.preview(Trib.attempter(data, realm, "typical"), data, realm)
		print("%s (%d waves; typical attempter expects %d damage vs %d hp)" % [data.realms[realm].name, preview["waves"], preview["expected_damage"], preview["max_hp"]])
		for profile in Trib.PROFILES:
			var line := "  %-9s" % profile
			for alignment in ALIGNMENTS:
				var o := Trib.odds(data, realm, profile, alignment, samples)
				line += "  al %5d: %3d/%3d/%3d" % [alignment, roundi(o["survive"] * 100), roundi(o["fail"] * 100), roundi(o["die"] * 100)]
			print(line)
	quit()
