extends SceneTree
## QA-039: first-year sim for a realm (tests/sim/foundation_year.gd).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_foundation_year.gd -- [seeds] [realm_index] [--threats=slip|fight]

const FoundationYear := preload("res://tests/sim/foundation_year.gd")


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])


## "n fights rated <50%: a, ..." for the rated win chances in `odds`.
func _histogram(odds: Array) -> String:
	var b := [0, 0, 0, 0]
	for o: float in odds:
		b[0 if o < 0.5 else (1 if o < 0.75 else (2 if o < 0.95 else 3))] += 1
	return "%d fights rated <50%%: %d, 50-75%%: %d, 75-95%%: %d, >95%%: %d" % [odds.size(), b[0], b[1], b[2], b[3]]


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var realm := int(args[1]) if args.size() > 1 else 2
	var fight_threats := args.has("--threats=fight")
	var gs: Node = root.get_node("GameState")
	var realm_name: String = gs.data.realms[realm].name
	print("First %s year: %d seeds, sensed threats: %s" % [realm_name, seeds, "fight" if fight_threats else "slip away"])
	print("  region / variant               won  lost  fled  injur  lives  stones  stage")
	var all := {"won": [], "lost": [], "fled": [], "injuries": [], "lives_spent": [], "stones": [], "stage": []}
	var no_life := 0
	var all_odds: Array = []
	var runs := 0
	var foe_counts := {}
	for region_id in FoundationYear.friendly_regions(gs.data, realm):
		for sect in [false, true]:
			var met := 0
			var evaded := 0
			var m3: Array = []
			var m6: Array = []
			var region_odds: Array = []
			var rows := {"won": [], "lost": [], "fled": [], "injuries": [], "lives_spent": [], "stones": [], "stage": []}
			for s in range(1, seeds + 1):
				var r: Dictionary = FoundationYear.play(gs, s, realm, region_id, sect, 12, fight_threats)
				for k: String in rows:
					rows[k].append(r[k])
					all[k].append(r[k])
				runs += 1
				met += int(r["won"]) + int(r["lost"]) + int(r["fled"]) + int(r["evaded"])
				evaded += int(r["fled"]) + int(r["evaded"])
				m3.append(r["stage_m3"])
				m6.append(r["stage_m6"])
				region_odds.append_array(r["odds"])
				for f: Array in r["foes"]:
					if float(f[1]) > 0.95:
						foe_counts[f[0]] = int(foe_counts.get(f[0], 0)) + 1
				if int(r["lives_spent"]) == 0:
					no_life += 1
			print("  %-30s %4.0f  %4.0f  %4.0f  %5.0f  %5.0f  %6.0f  %5.0f" % [("%s %s" % [region_id, "sect" if sect else "rogue"]).left(30), _median(rows["won"]), _median(rows["lost"]), _median(rows["fled"]), _median(rows["injuries"]), _median(rows["lives_spent"]), _median(rows["stones"]), _median(rows["stage"])])
			print("      met %d foes in all, evaded %d; stage by month 3/6/12: %.0f/%.0f/%.0f; %s" % [met, evaded, _median(m3), _median(m6), _median(rows["stage"]), _histogram(region_odds)])
			all_odds.append_array(region_odds)
	var fought := _median(all["won"]) + _median(all["lost"])
	print("  median of all runs: won %.0f lost %.0f fled %.0f injuries %.0f lives %.0f stones %.0f stage %.0f" % [_median(all["won"]), _median(all["lost"]), _median(all["fled"]), _median(all["injuries"]), _median(all["lives_spent"]), _median(all["stones"]), _median(all["stage"])])
	print("  runs with no artifact life spent: %d of %d" % [no_life, runs])
	print("  rated odds of every fight fought (all runs): %s" % _histogram(all_odds))
	var ranked: Array = foe_counts.keys()
	ranked.sort_custom(func(a: Variant, b: Variant) -> bool: return foe_counts[a] > foe_counts[b])
	var report := []
	for fid: String in ranked.slice(0, 8):
		report.append("%s %d" % [fid, foe_counts[fid]])
	print("  foe report (fights rated >95%%): %s" % ", ".join(report))
	print("  median win share of fought fights: %.0f%%" % (100.0 * _median(all["won"]) / maxf(1.0, fought)))
	quit()
