extends TestCase
## QA-016: guards for the newcomer path (sim: tests/sim/simulate_first_hour.gd; C-009 tests are in test_first_hour.gd).

const FirstHour := preload("res://tests/sim/first_hour.gd")
const SEEDS := 5
## Known offenders, tracked by FH-021 (content fix). Empty this list when it lands:
## the test fails if a listed foe is no longer an offender, so it cannot go stale.
const KNOWN_OFFENDERS: Array[String] = ["mountain_bandit", "iron_back_boar"]


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


func test_meditating_a_year_posts_little_news() -> void:
	var gs := _root().get_node("GameState")
	var bus := _root().get_node("EventBus")
	var c := CharacterFactory.create("Calm", gs.data, seeded_rng(5))
	gs.start_session(c)
	gs.pending_event = ""
	bus.clear_history()
	for i in 12:
		gs.cultivate(Calendar.DAYS_PER_MONTH, 1.0)
		if not c.alive:
			break
	var world_lines := 0
	for entry: Dictionary in bus.history:
		if entry["topic"] != "cultivation":
			world_lines += 1
	gs.end_session()
	assert_true(world_lines <= 24, "%d non-cultivation log lines in 12 months of meditation" % world_lines)
