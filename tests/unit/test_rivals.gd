extends TestCase
## RIV-002: the named rival and rival encounters.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_real_rules_are_valid() -> void:
	assert_eq(Rivals.validate(data()).size(), 0, ", ".join(Rivals.validate(data())))


func test_validation_catches_bad_rival_encounters() -> void:
	var d := GameData.load_from_dir()
	d.encounters["bad_rival"] = {"id": "bad_rival", "tags": ["city"], "text": "{rival} waves.", "fight_rival": true, "enemy": "wild_boar"}
	d.encounters["bad_rival2"] = {"id": "bad_rival2", "tags": ["city"], "rival": "taller", "text": "Hi."}
	var errors := Rivals.validate(d)
	assert_eq(errors.size(), 3, ", ".join(errors))


func test_spawn_matches_the_player_and_climbs_faster() -> void:
	var d := data()
	var c := new_character()
	c.age_days = 16 * Calendar.DAYS_PER_YEAR
	var people := {}
	var rival := Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	assert_eq(c.rival, rival.id)
	assert_eq(rival.age_years(), 16)
	assert_eq(rival.realm_index, c.realm_index)
	assert_eq(rival.spiritual_roots.size(), 1, "one strong root")
	var purity: Array = Rivals.rules(d)["root_purity"]
	assert_true(int(rival.spiritual_roots.values()[0]) >= int(purity[0]))
	assert_gt(rival.diligence, Npcs.SPAWN_DILIGENCE_MAX, "more diligent than any ordinary NPC")
	assert_true(Rivals.rival_of(c, people) == rival)
	rival.alive = false
	assert_true(Rivals.rival_of(c, people) == null, "a dead rival is gone")


func test_relation_gates_encounters() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = 1
	var people := {}
	var rival := Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	var ids := func() -> Array:
		return Exploration.eligible_encounters(c, d, ["city", "wild"], {}, rival).map(func(e: Dictionary) -> String: return e["encounter"]["id"])
	assert_eq(Rivals.relation(c, rival), "equal")
	assert_true(ids.call().has("rival_contest"))
	assert_false(ids.call().has("rival_sneers"))
	rival.realm_index = 2
	assert_true(ids.call().has("rival_sneers"))
	assert_false(ids.call().has("rival_contest"))
	rival.realm_index = 0
	assert_true(ids.call().has("rival_ambush"))
	assert_false(Exploration.eligible_encounters(c, d, ["city", "wild"], {}).any(func(e: Dictionary) -> bool: return e["encounter"].has("rival")), "no rival, no rival encounters")
	rival.realm_index = 2
	var text := Rivals.fill("{rival} has reached {rival_realm}.", rival, d)
	assert_eq(text, "%s has reached %s." % [rival.name, Cultivation.realm_label(rival, d)])


func test_game_state_spawns_and_resolves_rival_encounters() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	var rival: CharacterData = Rivals.rival_of(c, gs.npcs)
	assert_true(rival != null, "a new game spawns a rival")
	assert_eq(Npcs.region_of(rival, gs.data), gs.data.start_region)
	assert_true(Npcs.is_newsworthy(rival.id, c, gs.npc_favor), "the rival's breakthroughs make the news")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	assert_eq(gs.player.rival, rival.id, "the same rival after loading")
	saved["player"].erase("rival")
	gs.load_save_dict(saved)
	assert_true(Rivals.rival_of(gs.player, gs.npcs) != null, "old saves gain a rival")
	c = gs.player
	rival = Rivals.rival_of(c, gs.npcs)
	c.realm_index = 1
	rival.realm_index = 1
	gs.pending_encounter = "rival_contest"
	gs.choose_encounter(1)
	assert_eq(int(gs.npc_favor.get(rival.id, 0)), 10, "a meditation contest earns respect")
	gs.pending_encounter = "rival_contest"
	gs.choose_encounter(2)
	assert_eq(Karma.grudge(c, rival.id), 5, "declining earns a grudge")
	var window := EncounterWindow.new()
	_root().add_child(window)
	gs.pending_encounter = "rival_contest"
	window.open()
	assert_true(window.encounter_text().begins_with(rival.name), window.encounter_text())
	assert_false(window.encounter_text().contains("{rival}"))
	window.free()
	gs.pending_encounter = ""
	gs.end_session()


func test_first_meeting_due_window() -> void:
	var d := data()
	var c := new_character()
	var people := {}
	Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	var flags := {}
	assert_false(Rivals.first_meeting_due(c, people, d, flags, 9), "not before day 10")
	assert_true(Rivals.first_meeting_due(c, people, d, flags, 10))
	assert_false(Rivals.first_meeting_due(c, people, d, flags, 376), "never after the first year")
	flags[Rivals.FIRST_MEETING_FLAG] = true
	assert_false(Rivals.first_meeting_due(c, people, d, flags, 10), "only once")
	flags.clear()
	people[c.rival].alive = false
	assert_false(Rivals.first_meeting_due(c, people, d, flags, 10), "a dead rival does not meet you")


func test_first_meeting_validation() -> void:
	var d := data()
	d.karma["rival"]["first_meeting_day"] = -1
	assert_gt(Rivals.validate(d).size(), 0)


func test_first_meeting_dialogue_is_valid_and_formats_the_rival() -> void:
	var d := data()
	assert_true(d.dialogues.has(Rivals.FIRST_MEETING_EVENT))
	assert_eq(Dialogue.validate(d.dialogues[Rivals.FIRST_MEETING_EVENT], d).size(), 0)
	var c := new_character()
	var people := {}
	var rival := Rivals.spawn(c, people, d, seeded_rng(), "qingshi_village")
	var ctx := {"player": c, "npc": null, "data": d, "flags": {}, "favor": 0, "rival": rival}
	assert_eq(Dialogue.format("{rival} is {rival_realm}", ctx), "%s is %s" % [rival.name, Cultivation.realm_label(rival, d)])
	var view := Dialogue.view(d.dialogues[Rivals.FIRST_MEETING_EVENT], "meet", ctx)
	assert_eq(String(view["speaker"]), rival.name)
	ctx["rival"] = null
	assert_eq(Dialogue.format("{rival}{rival_realm}", ctx), "")


func test_relation_text_cases() -> void:
	var c := new_character()
	var r := new_character(7)
	c.realm_index = 1
	c.stage = 3
	r.realm_index = 2
	r.stage = 0
	assert_eq(Rivals.relation_text(c, r), "far ahead of you")
	r.realm_index = 1
	r.stage = 5
	assert_eq(Rivals.relation_text(c, r), "a few steps ahead")
	r.stage = 3
	assert_eq(Rivals.relation_text(c, r), "level with you")
	r.stage = 1
	assert_eq(Rivals.relation_text(c, r), "behind you")
	r.realm_index = 0
	r.stage = 9
	assert_eq(Rivals.relation_text(c, r), "behind you")


## C-086: three first-year rival encounters, gated on the first meeting.
func test_first_year_rival_encounters() -> void:
	var d := data()
	for id in ["rival_herb_seller_pill", "rival_wounded_hunt", "rival_sect_lecture"]:
		assert_true(d.encounters.has(id), id + " exists")
		var e: Dictionary = d.encounters[id]
		assert_true(e.has("rival"), id + " needs a rival")
		assert_eq(e.get("requires_flag", ""), "rival_met", id + " waits for the first meeting")
		assert_true(e.has("blocked_by_flag"), id + " is once-only")


## C-087: three Foundation-stage rival encounters, once-only and gated on the first meeting.
func test_foundation_rival_encounters() -> void:
	var d := data()
	var want := {"rival_foundation_herb_bid": "stronger", "rival_cornered_by_beast": "weaker", "rival_sect_challenge": "equal"}
	for id in want:
		assert_true(d.encounters.has(id), id + " exists")
		var e: Dictionary = d.encounters[id]
		assert_eq(e.get("rival", ""), want[id], id + " rival kind")
		assert_eq(e.get("requires_flag", ""), "rival_met", id + " waits for the first meeting")
		assert_true(e.has("blocked_by_flag"), id + " is once-only")
		assert_eq(e.get("min_realm", ""), "foundation_establishment", id + " min realm")
		assert_eq(e.get("max_realm", ""), "foundation_establishment", id + " max realm")


## RIVAL-005: news of a rival's breakthrough.
func test_news_only_for_a_higher_realm() -> void:
	var d := data()
	var c := CharacterData.new()
	var r := CharacterData.new()
	r.name = "Lin Wei"
	r.realm_index = 1
	assert_eq(Rivals.news(c, r, 1, d), "")
	assert_true(Rivals.news(c, r, 0, d).contains("Lin Wei"))
	assert_true(Rivals.news(c, r, 0, d).contains(d.realms[1].name))
	r.realm_index = 2
	assert_eq(Rivals.news(c, r, 0, d).count("\n"), 0, "one line for a double jump")
	r.alive = false
	assert_eq(Rivals.news(c, r, 0, d), "")
	assert_eq(Rivals.news(c, null, 0, d), "")


## RIVAL-011: word of the rival's death by cause.
func test_death_news_by_cause() -> void:
	var c := CharacterData.new()
	var r := CharacterData.new()
	r.name = "Lin Wei"
	assert_eq(Rivals.death_news(c, r), "", "alive")
	assert_eq(Rivals.death_news(c, null), "")
	r.alive = false
	r.cause_of_death = "slain by Wu"
	assert_eq(Rivals.death_news(c, r), "", "the player's own kill")
	r.cause_of_death = "old age"
	assert_eq(Rivals.death_news(c, r), "Word reaches you: your rival Lin Wei has died of old age.")
	r.cause_of_death = "heavenly tribulation"
	assert_eq(Rivals.death_news(c, r), "Word reaches you: your rival Lin Wei perished under the Heavenly Tribulation.")
	r.cause_of_death = "fell in battle at Red Gate"
	assert_eq(Rivals.death_news(c, r), "Word reaches you: your rival Lin Wei fell in battle at Red Gate.")
	r.cause_of_death = "a fall"
	assert_eq(Rivals.death_news(c, r), "Word reaches you: your rival Lin Wei is dead.")


func test_surpassed_needs_a_higher_realm() -> void:
	var c := CharacterFactory.create("Me", data(), seeded_rng(1))
	var r := CharacterFactory.create("Rival", data(), seeded_rng(2))
	c.realm_index = 2
	r.realm_index = 1
	assert_true(Rivals.surpassed(c, r))
	r.realm_index = 2
	c.stage = 5
	r.stage = 0
	assert_false(Rivals.surpassed(c, r), "same realm, higher stage")
	r.realm_index = 1
	r.alive = false
	assert_false(Rivals.surpassed(c, r), "dead rival")
	assert_false(Rivals.surpassed(c, null))
	r.alive = true
	r.realm_index = 0
	assert_false(Rivals.surpassed(c, r), "a mortal rival has not started climbing yet (QA-078)")


## C-088: the sect lecture rewards a sharper mind.
func test_lecture_sharper_answer_needs_comprehension() -> void:
	var d := data()
	var e: Dictionary = d.encounters["rival_sect_lecture"]
	var choice: Dictionary = {}
	for ch in e["choices"]:
		if String(ch["label"]).begins_with("Answer better"):
			choice = ch
	assert_false(choice.is_empty(), "sharper answer exists")
	assert_true(e["choices"].size() >= 3, "plain choices remain")
	var c := CharacterData.new()
	c.attributes["comprehension"] = 10
	assert_true(Exploration.check_choice(c, d, choice, {}) != "", "blocked at 10")
	c.attributes["comprehension"] = 12
	assert_eq(Exploration.check_choice(c, d, choice, {}), "", "allowed at 12")


## C-091: first-year attribute checks, one per attribute.
func test_first_year_attribute_checks() -> void:
	var d := data()
	var picks := {
		"forest_dying_gatherer": "spirit",
		"village_runaway_mule": "fortune",
		"village_field_quarrel": "charisma",
		"road_lost_child": "constitution",
	}
	var covered: Dictionary = {}
	for id in picks:
		var attr: String = picks[id]
		var found := false
		for ch in d.encounters[id]["choices"]:
			var need: Dictionary = ch.get("requires", {}).get("min_attributes", {})
			if not need.has(attr):
				continue
			found = true
			covered[attr] = true
			var c := CharacterData.new()
			c.attributes[attr] = 11
			assert_true(Exploration.check_choice(c, d, ch, {}) != "", "%s blocked at 11" % id)
			c.attributes[attr] = 12
			assert_eq(Exploration.check_choice(c, d, ch, {}), "", "%s allowed at 12" % id)
		assert_true(found, "%s has a %s choice" % [id, attr])
	assert_eq(covered.size(), 4, "four attributes covered")


## C-092: accepting the terrace challenge is worth it.
func test_terrace_challenge_accept_rewards() -> void:
	var accept: Dictionary = data().encounters["rival_sect_challenge"]["choices"][0]
	assert_true(accept.get("fight_rival", false), "accept fights the rival")
	assert_eq(int(accept.get("rival_favor", 0)), 5, "accept gives favor")
	assert_eq(int(accept["effects"].get("qi", 0)), 40, "accept gives qi")


func test_spur_raises_diligence_and_caps() -> void:
	var data := data()
	var rival := CharacterData.new()
	rival.diligence = 0.5
	assert_almost_eq(Rivals.spur(rival, data), 0.6, 0.001)
	rival.diligence = 0.9
	assert_almost_eq(Rivals.spur(rival, data), Rivals.SPUR_CAP, 0.001)
	assert_almost_eq(Rivals.spur(rival, data), Rivals.SPUR_CAP, 0.001)


func test_attitude() -> void:
	var d := data()
	var c := new_character()
	var rival := new_character(77)
	rival.id = "gen_rival"
	assert_eq(Rivals.attitude(c, rival, 0, d), "proud")
	assert_eq(Rivals.attitude(c, rival, 19, d), "proud")
	assert_eq(Rivals.attitude(c, rival, 20, d), "friendly")
	c.grudges["gen_rival"] = 10
	assert_eq(Rivals.attitude(c, rival, 50, d), "bitter")
	assert_eq(Rivals.attitude_text("proud"), "")
	assert_eq(Rivals.attitude_text("friendly"), "a friendly rivalry")
	assert_eq(Rivals.attitude_text("bitter"), "they hold a grudge")


func test_attitude_validation() -> void:
	var d := GameData.load_from_dir()
	d.karma["rival"]["friendly_favor"] = 0
	d.karma["rival"]["bitter_grudge"] = "x"
	assert_eq(Rivals.validate(d).size(), 2, ", ".join(Rivals.validate(d)))


func test_attitude_gates_encounters() -> void:
	var d := GameData.load_from_dir()
	d.encounters["att_test"] = {"id": "att_test", "tags": ["att_tag"], "weight": 1, "kind": "neutral", "days": 0, "rival": "any", "rival_attitude": "friendly", "text": "{rival} nods."}
	var c := new_character()
	var rival := new_character(77)
	rival.id = "gen_rival"
	var ids := func(favor: int) -> Array:
		return Exploration.eligible_encounters(c, d, ["att_tag"], {}, rival, 1.0, "", "", favor).map(func(e: Dictionary) -> String: return e["encounter"]["id"])
	assert_false(ids.call(0).has("att_test"))
	assert_true(ids.call(20).has("att_test"))
	assert_false(Exploration.eligible_encounters(c, d, ["att_tag"], {}, null, 1.0, "", "", 20).any(func(e: Dictionary) -> bool: return e["encounter"]["id"] == "att_test"), "no rival")
	c.grudges["gen_rival"] = 10
	assert_false(ids.call(20).has("att_test"), "bitter wins")
	assert_eq(Rivals.validate(d).size(), 0, ", ".join(Rivals.validate(d)))


func test_attitude_encounter_validation() -> void:
	var d := GameData.load_from_dir()
	d.encounters["bad_att"] = {"id": "bad_att", "tags": ["city"], "rival": "any", "rival_attitude": "angry", "text": "Hi."}
	d.encounters["bad_att2"] = {"id": "bad_att2", "tags": ["city"], "rival_attitude": "bitter", "text": "Hi."}
	assert_eq(Rivals.validate(d).size(), 2, ", ".join(Rivals.validate(d)))
