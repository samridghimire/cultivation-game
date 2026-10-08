extends TestCase
## QA-016: guards for the newcomer path (sim: tests/sim/simulate_first_hour.gd; C-009 tests are in test_first_hour.gd).

const FirstHour := preload("res://tests/sim/first_hour.gd")
const SEEDS := 5
## Known offenders, tracked by FH-021 (content fix). Empty this list when it lands:
## the test fails if a listed foe is no longer an offender, so it cannot go stale.
## Observed max over seeds 1-5 is 0 lost fights (+2).
const MAX_FIGHTS_LOST := 2
## Observed max over seeds 1-5 is 2 quiet lines in a year of meditation (+50%).
const MAX_QUIET_LINES := 3
const KNOWN_OFFENDERS: Array[String] = []


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_chores_and_pills_reach_qi_refining_within_30_days() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var reached := 0
	for s in range(1, SEEDS + 1):
		var r: Dictionary = FirstHour.play(gs, clock, s, 1)
		if r["layer_day"].has(1) and int(r["layer_day"][1]) <= 30:
			reached += 1
		gs.end_session()
	assert_true(reached >= 4, "only %d of %d newcomers reached Qi Refining 1st Layer within 30 days" % [reached, SEEDS])


## A fight the newcomer cannot slip away from (not a lethal foe, or an encounter
## choice) must be winnable in Qingshi Village for Qi Refining layers 1-3.
func test_qingshi_forced_fights_are_winnable_for_newcomers() -> void:
	var tags: Array = data().regions["qingshi_village"]["encounter_tags"]
	var offenders: Array[String] = []
	var offending_foes := {}
	for enc_id: String in data().encounters:
		var enc: Dictionary = data().encounters[enc_id]
		var shares := false
		for t: String in enc.get("tags", []):
			shares = shares or tags.has(t)
		if not shares:
			continue
		var foes: Array[String] = []
		if enc.has("enemy") and not data().enemies.get(String(enc["enemy"]), {}).get("lethal", false):
			foes.append(String(enc["enemy"]))
		for choice: Dictionary in enc.get("choices", []):
			if choice.has("enemy"):
				foes.append(String(choice["enemy"]))
		var min_realm := maxi(0, data().realm_index_of(String(enc.get("min_realm", "mortal"))))
		var max_realm := data().realm_index_of(String(enc["max_realm"])) if enc.has("max_realm") else 99
		for foe_id in foes:
			for realm in [0, 1]:
				if realm < min_realm or realm > max_realm:
					continue
				for stage in ([0] if realm == 0 else [0, 1, 2]):
					var c := new_character(31)
					c.realm_index = realm
					c.stage = stage
					c.techniques["basic_breathing"] = {"level": 1, "xp": 0.0}
					var chance := Combat.win_chance(c, data(), data().enemies[foe_id], 60)
					if chance < 0.15:
						offending_foes[foe_id] = true
						offenders.append("%s (%s) vs realm %d stage %d: %d%%" % [foe_id, enc_id, realm, stage, roundi(chance * 100)])
	var found: Array = offending_foes.keys()
	found.sort()
	var known: Array = KNOWN_OFFENDERS.duplicate()
	known.sort()
	assert_eq(found, known, "forced Qingshi fights below 15%% (new offenders, or fixed ones to drop from KNOWN_OFFENDERS, FH-021): %s" % "; ".join(offenders))


## Lines of the player's own doing: world news (topic "world") and cultivation
## progress are not counted, so a quiet year stays quiet however busy the world is.
func _quiet_lines(seed_value: int) -> int:
	var gs := _root().get_node("GameState")
	var bus := _root().get_node("EventBus")
	var c := CharacterFactory.create("Calm", gs.data, seeded_rng(seed_value))
	gs.start_session(c)
	gs.pending_event = ""
	bus.clear_history()
	for i in 12:
		gs.cultivate(Calendar.DAYS_PER_MONTH, 1.0)
		if not c.alive:
			break
	var lines := 0
	for entry: Dictionary in bus.history:
		if not entry["topic"] in ["cultivation", "world"]:
			lines += 1
	gs.end_session()
	return lines


func test_meditating_a_year_posts_little_news() -> void:
	var worst := 0
	for s in range(1, SEEDS + 1):
		worst = maxi(worst, _quiet_lines(s))
	assert_true(worst <= MAX_QUIET_LINES, "%d non-cultivation, non-world log lines in 12 months of meditation (limit %d)" % [worst, MAX_QUIET_LINES])


## QA-022: a newcomer's first year is not a gauntlet.
func test_first_year_loses_few_fights() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var worst := 0
	for s in range(1, SEEDS + 1):
		var r: Dictionary = FirstHour.play(gs, clock, s, 12)
		worst = maxi(worst, int(r["fights_lost"]))
		gs.end_session()
	assert_true(worst <= MAX_FIGHTS_LOST, "a newcomer lost %d fights in 12 months (limit %d)" % [worst, MAX_FIGHTS_LOST])


## QA-029: the curious player (weekly exploring, deeds, missions, a chat) is never
## killed, always has something in the log, and reaches QR3 within a year.
## Measured over seeds 1-10: QR3 by day 62-348, 3-4 fights lost, 0 empty months.
func test_curious_player_first_year() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var reached := 0
	for s in range(1, SEEDS + 1):
		var r: Dictionary = FirstHour.play(gs, clock, s, 12, true)
		assert_true(r["player"].alive, "seed %d: the curious player died" % s)
		for m in range(1, r["month_lines"].size()):
			assert_false(r["month_lines"][m].is_empty(), "seed %d: month %d logged nothing" % [s, m + 1])
		if r["layer_day"].has(3) and int(r["layer_day"][3]) <= 360:
			reached += 1
		gs.end_session()
	assert_true(reached >= 4, "only %d of %d curious players reached QR3 within a year" % [reached, SEEDS])
