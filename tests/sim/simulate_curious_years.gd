extends SceneTree
## QA-041: three curious years. Runs the curious first-hour policy (tests/sim/first_hour.gd)
## for many months and prints, per 6-month block, distinct action kinds, new features first
## used, stones and realm, then flags dull blocks.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_curious_years.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const BLOCK := 6
## Features the sim reports; the curious policy cannot use the ones never seen in `kind_sets`
## (crafting, profession work, secret realms, gifts, pointers, spars, lectures).
const FEATURES: Array[String] = ["mission", "deed", "talk", "commission", "breakthrough", "craft", "work", "secret_realm", "gift", "pointer", "spar", "lecture"]


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 36
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var blocks := months / BLOCK
	var kinds_by_block: Array = []
	var new_by_block: Array = []
	var stones_by_block: Array = []
	var first_month := {}
	var stretches: Array = []
	var died: Array[int] = []
	for b in blocks:
		kinds_by_block.append([])
		new_by_block.append([])
		stones_by_block.append([])
	for f in FEATURES:
		first_month[f] = []
	print("Curious player, %d seeds, %d months" % [seeds, months])
	print("  seed  block  kinds  new  stones  realm")
	for s in range(1, seeds + 1):
		var r: Dictionary = FirstHour.play(gs, clock, s, months, true)
		var sets: Array = r["kind_sets"]
		if sets.size() < months:
			died.append(s)
		var seen := {}
		var last_new := -1
		var longest := 0
		var longest_start := 0
		for m in sets.size():
			var fresh := 0
			for k: String in sets[m]:
				if k != "explore" and not seen.has(k):
					seen[k] = m + 1
					fresh += 1
					if first_month.has(k):
						first_month[k].append(m + 1)
			if fresh > 0:
				last_new = m
			elif m - last_new > longest:
				longest = m - last_new
				longest_start = last_new + 1
			sets[m] = {"kinds": sets[m].size(), "new": fresh}
		stretches.append({"seed": s, "length": longest, "from": longest_start + 1, "realm": r["realms"][mini(longest_start, r["realms"].size() - 1)] if not r["realms"].is_empty() else "-", "stones": r["stones"][mini(longest_start, r["stones"].size() - 1)] if not r["stones"].is_empty() else 0})
		for b in mini(blocks, ceili(float(sets.size()) / BLOCK)):
			var ks := 0
			var nw := 0
			var n := 0
			for m in range(b * BLOCK, mini((b + 1) * BLOCK, sets.size())):
				ks += int(sets[m]["kinds"])
				nw += int(sets[m]["new"])
				n += 1
			var avg := float(ks) / maxi(1, n)
			var stones: int = r["stones"][mini((b + 1) * BLOCK, sets.size()) - 1]
			kinds_by_block[b].append(avg)
			new_by_block[b].append(nw)
			stones_by_block[b].append(stones)
			print("  %4d  %5d  %5.1f  %3d  %6d  %s" % [s, b + 1, avg, nw, stones, r["realms"][mini((b + 1) * BLOCK, sets.size()) - 1]])
		gs.end_session()
	print("Medians per %d-month block: distinct kinds / seeds with a new feature / stones" % BLOCK)
	for b in blocks:
		var with_new := 0
		for v: int in new_by_block[b]:
			if v > 0:
				with_new += 1
		var flag := ""
		if _median(kinds_by_block[b].duplicate()) <= 2.0:
			flag += " [kinds<=2]"
		if _median(new_by_block[b].duplicate()) == 0.0:
			flag += " [nothing new]"
		print("  months %2d-%2d: %.1f kinds, %d of %d seeds new feature, %.0f stones%s" % [b * BLOCK + 1, (b + 1) * BLOCK, _median(kinds_by_block[b].duplicate()), with_new, kinds_by_block[b].size(), _median(stones_by_block[b].duplicate()), flag])
	print("Seeds whose life ended before month %d: %s" % [months, str(died) if not died.is_empty() else "none"])
	print("First month each feature was used (median over seeds that used it):")
	for f in FEATURES:
		var v: Array = first_month[f]
		print("  %-13s %s" % [f, ("month %.0f (%d of %d seeds)" % [_median(v.duplicate()), v.size(), seeds]) if not v.is_empty() else "never (policy does not use it)"])
	stretches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["length"] > b["length"])
	print("Longest 'nothing new' stretches:")
	for i in mini(3, stretches.size()):
		var st: Dictionary = stretches[i]
		print("  seed %d: %d months from month %d (%s, %d stones)" % [st["seed"], st["length"], st["from"], st["realm"], st["stones"]])
	quit()
