extends SceneTree
## QA-078: how the rivalry plays out. Plays seeds 1-N for M months with the default and the
## curious first-hour policy and reports, per policy: the day of the first meeting, the rival's
## realm/stage next to the player's every 6 months, the day the player surpasses the rival (or
## never), rival breakthrough news lines, and rival encounters met (encounters with a `rival` field).
## QA-083: also the rival's attitude (Rivals.attitude: p roud / f riendly / b itter) at every 6-month
## checkpoint, with the share of checkpoints per attitude, and C-093's three attitude encounters met
## (checked monthly; the attitude is the one at the end of the month they were met).
## QA-090: also the explore days spent in regions the bitter spoiled-herbs encounter can fire in
## (its tags) while the rival is bitter, and how many were before it was first met.
## QA-087: also the bouts won/lost against the rival (world flags rival_bouts_won/lost; the curious policy
## challenges the rival when GUIDE-033 lists the bout) and the month of the first win.
## Usage: tools/godot.sh --headless --path . -s res://tests/sim/rival_story.gd -- [seeds] [months]

const FirstHour := preload("res://tests/sim/first_hour.gd")
const NEWS_PREFIX := "Word reaches you: your rival"
const C093 := ["rival_shares_insight", "rival_spoils_gathering", "rival_public_challenge"]


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
	var att_total := {"proud": 0, "friendly": 0, "bitter": 0}
	var c093_met := {}
	for id: String in C093:
		c093_met[id] = []
	var bouts_won_total := 0
	var bouts_lost_total := 0
	var first_wins: Array = []
	var bitter_days: Array = []
	var bitter_before: Array = []
	for s in range(1, seeds + 1):
		var spoils_tags: Array = gs.data.encounters["rival_spoils_gathering"]["tags"]
		var bit := [0, 0]
		FirstHour.explore_observer = func(region: String, days: int) -> void:
			var rv1 := Rivals.rival_of(gs.player, gs.npcs)
			if rv1 == null or Rivals.attitude(gs.player, rv1, int(gs.npc_favor.get(rv1.id, 0)), gs.data) != "bitter":
				return
			for t: String in gs.data.regions[region].get("encounter_tags", []):
				if t in spoils_tags:
					bit[0] += days
					if int(gs.player.encounter_counts.get("rival_spoils_gathering", 0)) == 0:
						bit[1] += days
					return
		var news := [0]
		var on_msg := func(text: String, _cat: String) -> void:
			if text.begins_with(NEWS_PREFIX):
				news[0] += 1
		bus.message_posted.connect(on_msg)
		var cells: Array[String] = []
		var meet := [-1]
		var surpass := [-1]
		var atts: Array[String] = []
		var seen := {}
		var first_win := [-1]
		var hook := func(month: int) -> void:
			if meet[0] < 0 and gs.world_flags.get(Rivals.FIRST_MEETING_FLAG, false):
				meet[0] = clock.total_days
			if surpass[0] < 0 and gs.world_flags.get(Rivals.SURPASSED_FLAG, false):
				surpass[0] = clock.total_days
			if first_win[0] < 0 and int(gs.world_flags.get(Rivals.BOUTS_WON_FLAG, 0)) > 0:
				first_win[0] = month + 1
			var rv0 := Rivals.rival_of(gs.player, gs.npcs)
			var att0 := ""
			if rv0 != null:
				att0 = Rivals.attitude(gs.player, rv0, int(gs.npc_favor.get(rv0.id, 0)), gs.data)
			for id: String in C093:
				var n: int = int(gs.player.encounter_counts.get(id, 0))
				if n > int(seen.get(id, 0)):
					seen[id] = n
					c093_met[id].append(att0 if att0 != "" else "-")
			if (month + 1) % 6 == 0:
				var rv := rv0
				if att0 != "":
					att_total[att0] += 1
				atts.append(att0.substr(0, 1) if att0 != "" else "-")
				cells.append("%s/%s" % [_short(gs.player, gs.data), _short(rv, gs.data) if rv != null else "-"])
		var r: Dictionary = FirstHour.play(gs, clock, s, months, curious, hook)
		bus.message_posted.disconnect(on_msg)
		FirstHour.explore_observer = Callable()
		var won_n := int(gs.world_flags.get(Rivals.BOUTS_WON_FLAG, 0))
		var lost_n := int(gs.world_flags.get(Rivals.BOUTS_LOST_FLAG, 0))
		bouts_won_total += won_n
		bouts_lost_total += lost_n
		if first_win[0] >= 0:
			first_wins.append(first_win[0])
		print("           bouts won %d, lost %d, first win month %s" % [won_n, lost_n, str(first_win[0]) if first_win[0] >= 0 else "-"])
		bitter_days.append(bit[0])
		bitter_before.append(bit[1])
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
		print("           attitude  %s" % " ".join(atts))
		gs.end_session()
	meet_days.sort()
	surpass_days.sort()
	print("  summary: met %d/%d (median day %s), surpassed %d/%d (median day %s, under a year %d), news lines %d, rival encounters %d" % [meet_days.size(), sampled, _med(meet_days), surpass_days.size(), sampled, _med(surpass_days), under_year, news_total, enc_total])
	var cps: int = att_total["proud"] + att_total["friendly"] + att_total["bitter"]
	var parts: Array[String] = []
	var worst := 0.0
	for a: String in att_total:
		var share := 100.0 * float(att_total[a]) / float(maxi(1, cps))
		worst = maxf(worst, share)
		parts.append("%s %d (%d%%)" % [a, att_total[a], roundi(share)])
	print("  attitude at checkpoints (%d with a living rival): %s" % [cps, ", ".join(parts)])
	for id: String in C093:
		var tally := {}
		for a: String in c093_met[id]:
			tally[a] = int(tally.get(a, 0)) + 1
		print("  %s: met %d (%s)" % [id, c093_met[id].size(), ", ".join(tally.keys().map(func(k: String) -> String: return "%s %d" % [k, tally[k]])) if not tally.is_empty() else "never"])
	first_wins.sort()
	print("  bouts with the rival: won %d, lost %d; first win in %d/%d seeds (median month %s)" % [bouts_won_total, bouts_lost_total, first_wins.size(), sampled, _med(first_wins)])
	bitter_days.sort()
	bitter_before.sort()
	print("  bitter explore days in spoils regions per seed: median %s, max %s; before the encounter was met: median %s%s" % [_med(bitter_days), str(bitter_days.back()) if not bitter_days.is_empty() else "-", _med(bitter_before), " (under 5: the sim policy rarely meets the condition)" if int(_med(bitter_days)) < 5 else ""])
	if worst > 80.0:
		print("  FLAG: one attitude covers over 80% of checkpoints; C-093's encounters would barely show")
	if sampled > 0 and under_year * 2 > sampled:
		print("  FLAG: the rival is surpassed in under a year in most seeds; they never feel like a threat")


static func _med(v: Array) -> String:
	return "-" if v.is_empty() else str(v[v.size() / 2])
