extends SceneTree
## Forage-share sim (C-389): per region and season, the share of days whose slot-0 find is a village weed.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/forage_share.gd

const WEEDS := ["village_mugwort", "dew_grass", "spirit_herb"]


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var data: GameData = root.get_node("GameState").data
	for rid: String in ["qingshi_village", "misty_forest", "azure_peak", "withered_bone_marsh", "myriad_peaks_ridge"]:
		var line := "%-22s" % rid
		for s in 4:
			var days := 0
			var weeds := 0
			var none := 0
			for d in range(s * 90, s * 90 + 90):
				days += 1
				var got := Foraging.nodes(data, rid, d, 1, {}, 0)
				var first := ""
				for g in got:
					if int(g["slot"]) == 0:
						first = String(g["item"])
				if first == "":
					none += 1
				elif WEEDS.has(first):
					weeds += 1
			line += " %s=%3d%%" % [Calendar.season_of(s * 90), 100 * weeds / maxi(1, days - none)]
		print(line)
	quit()
