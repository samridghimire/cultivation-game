extends SceneTree
## QA-067: do "Fights you can win" (Guidance.fair_fights) win? The curious first-hour policy
## (tests/sim/first_hour.gd) logs the list each month and the rated chance and outcome of every
## listed fight it takes. Prints entries listed per month, empty months and actual vs rated win rate.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/fair_fights.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 12
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var listed: Array = []
	var taken := 0
	var wins := 0
	var rated_sum := 0.0
	print("Fair-fights sim: %d seeds, %d months (curious player)" % [seeds, months])
	for s in range(1, seeds + 1):
		var r: Dictionary = FirstHour.play(gs, clock, s, months, true)
		listed.append_array(r["fair_log"]["listed"])
		for t: Dictionary in r["fair_log"]["taken"]:
			taken += 1
			wins += 1 if t["won"] else 0
			rated_sum += float(t["chance"])
		gs.end_session()
	listed.sort()
	var empty := 0
	for n: int in listed:
		empty += 1 if n == 0 else 0
	print("Entries listed per month: median %d, max %d; empty months %d of %d" % [listed[listed.size() / 2] if not listed.is_empty() else 0, listed.back() if not listed.is_empty() else 0, empty, listed.size()])
	if taken == 0:
		print("Listed fights taken: 0")
	else:
		print("Listed fights taken: %d, won %d (%.0f%%), mean rated chance %.0f%%" % [taken, wins, 100.0 * wins / taken, 100.0 * rated_sum / taken])
	quit()
