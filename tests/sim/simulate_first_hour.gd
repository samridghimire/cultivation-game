extends SceneTree
## First-hour sim (QA-016): scripted newcomers in Qingshi Village (tests/sim/first_hour.gd).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/simulate_first_hour.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	values.sort()
	return float(values[values.size() / 2])


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var curious := args.has("--curious")
	var nums: Array[int] = []
	for a in args:
		if a != "--curious":
			nums.append(int(a))
	var seeds := nums[0] if nums.size() > 0 else 30
	var months := nums[1] if nums.size() > 1 else 12
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var layers := {1: [], 3: [], 9: []}
	var sects: Array = []
	var injuries: Array = []
	var lines: Array = []
	var won: Array = []
	var lost: Array = []
	var fled: Array = []
	var by_cat := {}
	var kinds_all: Array = []
	var zero_months := 0
	print("First-hour sim%s: %d seeds, %d months" % [" (curious player)" if curious else "", seeds, months])
	print("  seed  QR1  QR3  QR9  sect  injuries  won  lost  fled  lines/month")
	for s in range(1, seeds + 1):
		var r: Dictionary = FirstHour.play(gs, clock, s, months, curious)
		var total := 0
		for k: int in r["kinds"]:
			kinds_all.append(k)
		for m in range(1, r["month_lines"].size()):
			if r["month_lines"][m].is_empty():
				zero_months += 1
		for counts: Dictionary in r["month_lines"]:
			for cat: String in counts:
				by_cat[cat] = int(by_cat.get(cat, 0)) + int(counts[cat])
				total += int(counts[cat])
		var per_month := float(total) / maxi(1, r["month_lines"].size())
		for layer: int in layers:
			if r["layer_day"].has(layer):
				layers[layer].append(r["layer_day"][layer])
		if r["sect_day"] >= 0:
			sects.append(r["sect_day"])
		injuries.append(r["injuries"])
		lines.append(per_month)
		won.append(r["fights_won"])
		lost.append(r["fights_lost"])
		fled.append(r["fights_fled"])
		print("  %4d  %3s  %3s  %3s  %4s  %8d  %3d  %4d  %4d  %.1f" % [s, r["layer_day"].get(1, "-"), r["layer_day"].get(3, "-"), r["layer_day"].get(9, "-"), r["sect_day"] if r["sect_day"] >= 0 else "-", r["injuries"], r["fights_won"], r["fights_lost"], r["fights_fled"], per_month])
		gs.end_session()
	print("Medians (day): QR1 %.0f, QR3 %.0f, QR9 %.0f, sect %.0f; injuries %.0f; fights won %.0f, lost %.0f, fled %.0f; %.1f log lines/month" % [_median(layers[1]), _median(layers[3]), _median(layers[9]), _median(sects), _median(injuries), _median(won), _median(lost), _median(fled), _median(lines)])
	if curious:
		var sum := 0
		for k: int in kinds_all:
			sum += k
		print("Distinct action kinds per month: %.1f; months after the first with no log lines: %d" % [float(sum) / maxi(1, kinds_all.size()), zero_months])
	print("Lines by category: %s" % str(by_cat))
	quit()
