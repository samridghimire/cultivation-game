extends SceneTree
## QA-078: how the rivalry plays out. Plays seeds 1-N for M months with the default and the
## curious first-hour policy and reports, per policy: the day of the first meeting, the rival's
## realm/stage next to the player's every 6 months, the day the player surpasses the rival (or
## never), rival breakthrough news lines, and rival encounters met (encounters with a `rival` field).
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/rival_story.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const NEWS_PREFIX := "Word reaches you: your rival"


func _initialize() -> void:
	root.get_node("SaveManager").autosave_enabled = false
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var months := int(args[1]) if args.size() > 1 else 36
	for curious in [false, true]:
		_policy(seeds, months, curious)
	quit(0)


func _short(c: CharacterData, data: GameData) -> String:
	return "%s%d" % [data.realms[c.realm_index].id.substr(0, 2), c.stage]


func _policy(seeds: int, months: int, curious: bool) -> void:
	var gs: Node = root.get_node("GameState")
	var clock: Node = root.get_node("GameClock")
	var bus: Node = gs.get_node("/root/EventBus")
	print("Rival story, %s policy, %d seeds, %d months (cells: player/rival realm+stage; \"-\" = no rival or dead)" % ["curious" if curious else "default", seeds, months])
	var meet_days: Array = []
	var surpass_days: Array = []
	var under_year := 0
	var news_total := 0
	var enc_total := 0
	var sampled := 0
	for s in range(1, seeds + 1):
		var news := [0]
		var on_msg := func(text: String, _cat: String) -> void:
			if text.begins_with(NEWS_PREFIX):
				news[0] += 1
		bus.message_posted.connect(on_msg)
		var cells: Array[String] = []
		var meet := [-1]
		var surpass := [-1]
		var hook := func(month: int) -> void:
			if meet[0] < 0 and gs.world_flags.get(Rivals.FIRST_MEETING_FLAG, false):
				meet[0] = clock.total_days
			if surpass[0] < 0 and gs.world_flags.get(Rivals.SURPASSED_FLAG, false):
				surpass[0] = clock.total_days
			if (month + 1) % 6 == 0:
				var rv := Rivals.rival_of(gs.player, gs.npcs)
				cells.append("%s/%s" % [_short(gs.player, gs.data), _short(rv, gs.data) if rv != null else "-"])
		var r: Dictionary = FirstHour.play(gs, clock, s, months, curious, hook)
		bus.message_posted.disconnect(on_msg)
		var c: CharacterData = r["player"]
		var enc := 0
		for id: String in c.encounter_counts:
			var def: Dictionary = gs.data.encounters.get(id, {})
			if def.has("rival"):
				enc += int(c.encounter_counts[id])
		enc_total += enc
		news_total += news[0]
		sampled += 1
		if meet[0] >= 0:
			meet_days.append(meet[0])
		if surpass[0] >= 0:
			surpass_days.append(surpass[0])
			if surpass[0] < 365:
				under_year += 1
		print("  seed %2d  met day %s  surpassed day %s  news %d  rival encounters %d  %s" % [s, str(meet[0]) if meet[0] >= 0 else "-", str(surpass[0]) if surpass[0] >= 0 else "never", news[0], enc, " ".join(cells)])
		gs.end_session()
	meet_days.sort()
	surpass_days.sort()
	print("  summary: met %d/%d (median day %s), surpassed %d/%d (median day %s, under a year %d), news lines %d, rival encounters %d" % [meet_days.size(), sampled, _med(meet_days), surpass_days.size(), sampled, _med(surpass_days), under_year, news_total, enc_total])
	if sampled > 0 and under_year * 2 > sampled:
		print("  FLAG: the rival is surpassed in under a year in most seeds; they never feel like a threat")


static func _med(v: Array) -> String:
	return "-" if v.is_empty() else str(v[v.size() / 2])
