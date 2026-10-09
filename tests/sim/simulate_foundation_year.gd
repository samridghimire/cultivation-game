extends SceneTree
## QA-039: first-year sim for a realm (tests/sim/foundation_year.gd).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_foundation_year.gd -- [seeds] [realm_index]

const FoundationYear := preload("res://tests/sim/foundation_year.gd")


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var realm := int(args[1]) if args.size() > 1 else 2
	var gs: Node = root.get_node("GameState")
	var realm_name: String = gs.data.realms[realm].name
	print("First %s year: %d seeds" % [realm_name, seeds])
	print("  region / variant               won  lost  fled  injur  lives  stones  stage")
	var all := {"won": [], "lost": [], "fled": [], "injuries": [], "lives_spent": [], "stones": [], "stage": []}
	var no_life := 0
	var runs := 0
	for region_id in FoundationYear.friendly_regions(gs.data, realm):
		for sect in [false, true]:
			var rows := {"won": [], "lost": [], "fled": [], "injuries": [], "lives_spent": [], "stones": [], "stage": []}
			for s in range(1, seeds + 1):
				var r: Dictionary = FoundationYear.play(gs, s, realm, region_id, sect)
				for k: String in rows:
					rows[k].append(r[k])
					all[k].append(r[k])
				runs += 1
				if int(r["lives_spent"]) == 0:
					no_life += 1
			print("  %-30s %4.0f  %4.0f  %4.0f  %5.0f  %5.0f  %6.0f  %5.0f" % [("%s %s" % [region_id, "sect" if sect else "rogue"]).left(30), _median(rows["won"]), _median(rows["lost"]), _median(rows["fled"]), _median(rows["injuries"]), _median(rows["lives_spent"]), _median(rows["stones"]), _median(rows["stage"])])
	var fought := _median(all["won"]) + _median(all["lost"])
	print("  median of all runs: won %.0f lost %.0f fled %.0f injuries %.0f lives %.0f stones %.0f stage %.0f" % [_median(all["won"]), _median(all["lost"]), _median(all["fled"]), _median(all["injuries"]), _median(all["lives_spent"]), _median(all["stones"]), _median(all["stage"])])
	print("  runs with no artifact life spent: %d of %d" % [no_life, runs])
	print("  median win share of fought fights: %.0f%%" % (100.0 * _median(all["won"]) / maxf(1.0, fought)))
	quit()
