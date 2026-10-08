extends TestCase
## W-006: inheritance grounds (data/inheritances.json, Inheritances).

const Y := Calendar.DAYS_PER_YEAR


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _def() -> Dictionary:
	return {"id": "test_legacy", "name": "Test Legacy", "region": "misty_forest", "appears_years": 1, "deadline_years": 5,
		"stages": [
			{"name": "Gate", "days": 1, "test": "realm", "min_realm": "qi_refining"},
			{"name": "Insight", "days": 2, "test": "attribute", "attribute": "comprehension", "min": 12},
			{"name": "Heart", "days": 1, "test": "alignment", "min_alignment": 0},
			{"name": "Guard", "days": 1, "test": "fight", "enemy": "wild_boar"},
		],
		"reward": {"learn_technique": "iron_fist"}}


func _with_def(data: GameData) -> Dictionary:
	var def := _def()
	data.inheritances["test_legacy"] = def
	return def


func test_schedule_and_rival_claim() -> void:
	var data := data()
	var def := _with_def(data)
	var c := new_character()
	c.realm_index = 1
	var flags := {}
	assert_true(Inheritances.check_attempt(c, data, "test_legacy", "misty_forest", 0, flags).contains("found"), "not yet found")
	assert_eq(Inheritances.check_attempt(c, data, "test_legacy", "misty_forest", Y, flags), "")
	assert_true(Inheritances.check_attempt(c, data, "test_legacy", "azure_peak", Y, flags) != "", "wrong region")
	assert_true(Inheritances.check_attempt(c, data, "nope", "misty_forest", Y, flags) != "")
	assert_false(Inheritances.is_lost(def, 5 * Y - 1, flags))
	assert_true(Inheritances.is_lost(def, 5 * Y, flags))
	assert_true(Inheritances.lost_between(def, 5 * Y - 10, 5 * Y + 10, flags))
	assert_false(Inheritances.lost_between(def, 5 * Y + 10, 5 * Y + 20, flags), "news only once")
	assert_true(Inheritances.check_attempt(c, data, "test_legacy", "misty_forest", 5 * Y, flags).contains("Someone else"))
	assert_eq(Inheritances.status_text(c, data, "test_legacy", 5 * Y, flags), "Claimed by a rival")
	flags[Inheritances.claimed_flag("test_legacy")] = true
	assert_false(Inheritances.is_lost(def, 9 * Y, flags), "a claimed legacy is never lost")
	data.inheritances.erase("test_legacy")


func test_stage_tests_in_order_and_reward() -> void:
	var data := data()
	_with_def(data)
	var c := new_character()
	var flags := {}
	assert_true(Inheritances.check_attempt(c, data, "test_legacy", "misty_forest", Y, flags) != "", "a mortal cannot pass the gate")
	c.realm_index = 1
	assert_eq(Inheritances.pass_stage(c, data, "test_legacy", flags)["stage_name"], "Gate")
	c.attributes["comprehension"] = 11
	assert_true(Inheritances.check_attempt(c, data, "test_legacy", "misty_forest", Y, flags).contains("Comprehension"))
	c.attributes["comprehension"] = 12
	assert_eq(Inheritances.check_attempt(c, data, "test_legacy", "misty_forest", Y, flags), "")
	Inheritances.pass_stage(c, data, "test_legacy", flags)
	c.alignment = -10
	assert_true(Inheritances.check_attempt(c, data, "test_legacy", "misty_forest", Y, flags) != "", "heart rejected")
	c.alignment = 0
	var stage := Inheritances.pass_stage(c, data, "test_legacy", flags)
	assert_false(stage["last"])
	var enemy := Inheritances.stage_enemy(data, Inheritances.next_stage(c, data.inheritances["test_legacy"]))
	assert_eq(enemy["id"], "wild_boar")
	assert_false(enemy["lethal"], "trials never kill")
	var last := Inheritances.pass_stage(c, data, "test_legacy", flags)
	assert_true(last["last"])
	assert_true(Techniques.knows(c, "iron_fist"))
	assert_true(Inheritances.is_claimed("test_legacy", flags))
	assert_true(Inheritances.check_attempt(c, data, "test_legacy", "misty_forest", Y, flags).contains("already claimed"))
	var restored := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(Inheritances.stages_cleared(restored, "test_legacy"), 4, "progress is saved")
	data.inheritances.erase("test_legacy")


func test_data_is_valid_and_bad_data_rejected() -> void:
	var data := data()
	assert_gt(data.inheritances.size(), 0)
	assert_eq(Inheritances.validate(data).size(), 0, str(Inheritances.validate(data)))
	assert_eq(Inheritances.in_region(data, "misty_forest"), ["fist_saint_grave"])
	var bad := {"id": "bad", "name": "Bad", "region": "nowhere", "appears_years": 5, "deadline_years": 5,
		"stages": [{"name": "x", "test": "dance"}, {"name": "y", "test": "fight", "enemy": "nope"}, {"name": "z", "test": "attribute", "attribute": "luck"}],
		"reward": {"learn_technique": "nope"}}
	data.inheritances["bad"] = bad
	var errors := Inheritances.validate(data)
	data.inheritances.erase("bad")
	assert_eq(errors.size(), 6, str(errors))


# --- GameState integration ----------------------------------------------------

func test_game_state_claims_the_fist_saint_grave() -> void:
	var gs := _root().get_node("GameState")
	var clock := _root().get_node("GameClock")
	var c := CharacterFactory.create("Heir", gs.data, seeded_rng(4))
	gs.start_session(c)
	gs.current_region = "misty_forest"
	gs.attempt_inheritance("fist_saint_grave")
	assert_eq(Inheritances.stages_cleared(c, "fist_saint_grave"), 0, "a mortal is turned away")
	c.realm_index = 2  # Foundation Establishment: the stone ape is no match
	c.attributes["constitution"] = 15
	# Geared like a typical player: a bare one wins only ~70% since QA-007d, which made this test depend on the shared rng.
	c.equipment = {"weapon": "iron_sword", "armor": "iron_scale_armor"}
	c.techniques["iron_fist"] = {"level": 3, "xp": 0.0}
	for i in 3:
		gs.attempt_inheritance("fist_saint_grave")
	assert_eq(Inheritances.stages_cleared(c, "fist_saint_grave"), 3)
	assert_true(Inheritances.is_claimed("fist_saint_grave", gs.world_flags))
	assert_true(Techniques.knows(c, "immovable_mountain_stance"))
	assert_eq(LifeStats.get_stat(c, "inheritances_claimed"), 1, "MS-003: counted once")
	assert_true(clock.total_days > 0, "trials take time")


func test_game_state_rival_news_at_the_deadline() -> void:
	var gs := _root().get_node("GameState")
	var c := CharacterFactory.create("Late", gs.data, seeded_rng(4))
	gs.start_session(c)
	var news: Array[String] = []
	var listen := func(text: String, _category: String) -> void: news.append(text)
	EventBus.message_posted.connect(listen)
	gs.work_profession("doctor", 16 * Y)
	EventBus.message_posted.disconnect(listen)
	var def := Inheritances.inheritance(gs.data, "fist_saint_grave")
	assert_true(news.has(String(def["rival_news"])), "the world reports the rival's claim")
	gs.current_region = "misty_forest"
	c.realm_index = 2
	gs.attempt_inheritance("fist_saint_grave")
	assert_eq(Inheritances.stages_cleared(c, "fist_saint_grave"), 0, "too late")


## WU-016: character-sheet lines.
func test_progress_lines() -> void:
	var data := data()
	data.inheritances.clear()
	_with_def(data)
	var c := new_character()
	var flags := {}
	assert_eq(Inheritances.progress_lines(c, data, flags).size(), 0)
	c.trial_progress["test_legacy"] = 2
	assert_eq(Inheritances.progress_lines(c, data, flags), ["Test Legacy: 2/4 trials"] as Array[String])
	c.trial_progress["test_legacy"] = 4
	flags[Inheritances.claimed_flag("test_legacy")] = true
	assert_eq(Inheritances.progress_lines(c, data, flags), ["Test Legacy: claimed"] as Array[String])
