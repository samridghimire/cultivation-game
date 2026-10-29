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


func test_encounter_spar_sets_the_spar_cooldown() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	var rival: CharacterData = Rivals.rival_of(gs.player, gs.npcs)
	gs.player.realm_index = 1
	rival.realm_index = 1
	gs.npc_favor[rival.id] = 30
	assert_eq(gs.check_spar(rival.id), "", "the NPC menu spar is open before the encounter")
	gs.pending_encounter = "rival_spar_friendly"
	gs.choose_encounter(0)
	assert_true(gs.check_spar(rival.id).contains("sparred with"), "the encounter spar leaves the cooldown: " + gs.check_spar(rival.id))
	gs.pending_encounter = ""
	gs.end_session()


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


## C-100: three Core Formation rival encounters, once-only and gated on the first meeting.
func test_core_formation_rival_encounters() -> void:
	var d := data()
	var want := {"rival_core_boast": "stronger", "rival_secret_realm_gate": "equal", "rival_tribulation_question": "weaker"}
	for id in want:
		assert_true(d.encounters.has(id), id + " exists")
		var e: Dictionary = d.encounters[id]
		assert_eq(e.get("rival", ""), want[id], id + " rival kind")
		assert_eq(e.get("requires_flag", ""), "rival_met", id + " waits for the first meeting")
		assert_true(e.has("blocked_by_flag"), id + " is once-only")
		assert_eq(e.get("min_realm", ""), "core_formation", id + " min realm")


## C-112: three Nascent Soul rival encounters, one per attitude, once-only, with a duel and a peaceful choice.
func test_nascent_soul_rival_encounters() -> void:
	var d := data()
	var want := {"rival_nascent_tea": "friendly", "rival_nascent_proud_summons": "proud", "rival_nascent_bitter_ruin": "bitter"}
	for id in want:
		assert_true(d.encounters.has(id), id + " exists")
		var e: Dictionary = d.encounters[id]
		assert_eq(e.get("rival_attitude", ""), want[id], id + " attitude")
		assert_eq(e.get("rival", ""), "any", id + " rival kind")
		assert_eq(e.get("requires_flag", ""), "rival_met", id + " waits for the first meeting")
		assert_true(e.has("blocked_by_flag"), id + " is once-only")
		assert_eq(e.get("min_realm", ""), "nascent_soul", id + " min realm")
		var duel := false
		for choice: Dictionary in e["choices"]:
			if bool(choice.get("fight_rival", false)):
				duel = true
				assert_true(int(choice.get("rival_grudge", 0)) <= 5, id + " duel grudge at most 5")
		assert_true(duel, id + " has a fight_rival choice")
		assert_true(e["choices"].size() >= 2, id + " has a peaceful choice")


## A rival duel's effects apply before the fight, so they must not pay a prize a loss would also get.
func test_rival_duel_choices_pay_no_items() -> void:
	for e: Dictionary in data().encounters.values():
		for choice: Dictionary in e.get("choices", []):
			if not bool(choice.get("fight_rival", false)):
				continue
			var items: Dictionary = choice.get("effects", {}).get("items", {})
			for item_id: String in items:
				assert_true(int(items[item_id]) <= 0, "%s: '%s' pays %s before the duel" % [e["id"], choice["label"], item_id])


## C-109: one duel must not turn the rival bitter; two hard duels do. (Cruel non-duel choices may.)
func test_one_duel_does_not_make_the_rival_bitter() -> void:
	var bitter := int(data().karma["rival"]["bitter_grudge"])
	for e: Dictionary in data().encounters.values():
		for choice: Dictionary in e.get("choices", []):
			if bool(choice.get("fight_rival", false)):
				assert_true(int(choice.get("rival_grudge", 0)) < bitter, "%s: '%s' makes the rival bitter in one duel" % [e["id"], choice["label"]])


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


func test_caught_up_when_a_stronger_rival_becomes_equal() -> void:
	var c := CharacterFactory.create("Me", data(), seeded_rng(1))
	var r := CharacterFactory.create("Rival", data(), seeded_rng(2))
	r.realm_index = 2
	c.realm_index = 2
	assert_true(Rivals.caught_up(c, r, 1))
	assert_false(Rivals.caught_up(c, r, 2), "they were already equal")
	c.realm_index = 3
	assert_false(Rivals.caught_up(c, r, 2), "now past them")
	c.realm_index = 2
	r.alive = false
	assert_false(Rivals.caught_up(c, r, 1), "dead rival")
	assert_false(Rivals.caught_up(c, null, 1))
	r.alive = true
	assert_true(Rivals.caught_up_line(r).begins_with("You have caught up with Rival."))


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
			if ch.has("check") and str(ch["check"].get("attribute", "")) == attr:
				# C-206: a chance check instead of a hard gate; always selectable, has a cost on failure.
				found = true
				covered[attr] = true
				assert_true(ch.has("on_fail"), "%s check has an on_fail" % id)
				var c0 := CharacterData.new()
				c0.attributes[attr] = 1
				assert_eq(Exploration.check_choice(c0, d, ch, {}), "", "%s selectable at any level" % id)
				continue
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


func test_c093_attitude_encounters_data() -> void:
	var d := GameData.load_from_dir()
	var want := {"rival_shares_insight": "friendly", "rival_spoils_gathering": "bitter", "rival_public_challenge": "proud"}
	for id: String in want:
		assert_true(d.encounters.has(id), id)
		var e: Dictionary = d.encounters[id]
		assert_eq(String(e["rival_attitude"]), want[id], id)
		assert_eq(String(e["min_realm"]), "qi_refining", id)
		assert_true(String(e["blocked_by_flag"]) != "", id + " is once-only")
	assert_eq(Rivals.validate(d).size(), 0, ", ".join(Rivals.validate(d)))


## RIVAL-013: every attitude move has a line; no move, or an unknown side, has none.
func test_attitude_change_line() -> void:
	assert_eq(Rivals.attitude_change_line("Lan", "proud", "bitter"), "Lan now holds a grudge against you.")
	assert_eq(Rivals.attitude_change_line("Lan", "friendly", "bitter"), "Lan now holds a grudge against you.")
	assert_eq(Rivals.attitude_change_line("Lan", "proud", "friendly"), "Lan warms to you. Your rivalry turns friendly.")
	assert_eq(Rivals.attitude_change_line("Lan", "bitter", "proud"), "Lan lets the old grudge go, but still means to beat you.")
	assert_eq(Rivals.attitude_change_line("Lan", "friendly", "proud"), "Lan cools toward you and is your proud rival again.")
	assert_eq(Rivals.attitude_change_line("Lan", "proud", "proud"), "")
	assert_eq(Rivals.attitude_change_line("Lan", "", "bitter"), "")
	assert_eq(Rivals.attitude_change_line("Lan", "proud", ""), "")


func test_bout_record_text() -> void:
	var c := new_character()
	assert_eq(Rivals.bout_record_text({}), "")
	LifeStats.add(c, "rival_bouts_won", 2)
	assert_eq(Rivals.bout_record_text({}), "", "lifetime totals are not this rival's record")
	assert_eq(Rivals.bout_record_text({Rivals.BOUTS_WON_FLAG: 2, Rivals.BOUTS_LOST_FLAG: 1}), "bouts 2 won, 1 lost")


func test_successor_due_and_line() -> void:
	assert_false(Rivals.successor_due({}, 1000))
	var flags := {Rivals.SUCCESSOR_DAY_FLAG: 500}
	assert_false(Rivals.successor_due(flags, 499))
	assert_true(Rivals.successor_due(flags, 500))
	assert_true(Rivals.successor_due(flags, 900))
	assert_eq(Rivals.successor_delay(data()), 180)
	var heir := new_character()
	heir.name = "Lin"
	assert_eq(Rivals.successor_line(heir, "Wu"), "Word spreads of Lin, a young cultivator who means to take Wu's place as your rival.")


func test_first_meeting_honours_meeting_from_flag() -> void:
	var c := new_character()
	var people := {}
	Rivals.spawn(c, people, data(), seeded_rng(), data().start_region)
	assert_true(Rivals.first_meeting_due(c, people, data(), {}, 10))
	var flags := {Rivals.MEETING_FROM_FLAG: 2000}
	assert_false(Rivals.first_meeting_due(c, people, data(), flags, 10))
	assert_false(Rivals.first_meeting_due(c, people, data(), flags, 1999))
	assert_true(Rivals.first_meeting_due(c, people, data(), flags, 2000))


func test_validation_rejects_bad_successor_delay() -> void:
	for bad in [-1, "x"]:
		var d := GameData.load_from_dir()
		d.karma["rival"]["successor_delay_days"] = bad
		assert_eq(Rivals.validate(d).size(), 1, str(bad))


## QA-088: each attitude encounter can roll for a Qi Refining player whose met rival has that attitude.
func test_attitude_encounters_are_eligible_in_their_regions() -> void:
	var d := data()
	var c := new_character()
	c.realm_index = d.realm_index_of("qi_refining")
	var rival := new_character(77)
	rival.id = "gen_rival"
	rival.realm_index = c.realm_index
	var flags := {Rivals.FIRST_MEETING_FLAG: true}
	var cases := [
		["rival_spoils_gathering", "bitter", ["forest", "wild"]],
		["rival_spoils_gathering", "bitter", ["marsh", "wild"]],
		["rival_spoils_gathering", "bitter", ["mountain", "wild", "azure_cliffs"]],
		["rival_shares_insight", "friendly", ["village"]],
		["rival_public_challenge", "proud", ["city"]],
	]
	for case: Array in cases:
		c.grudges.clear()
		var favor := 0
		if case[1] == "bitter":
			c.grudges["gen_rival"] = int(Rivals.rules(d).get("bitter_grudge", 10))
		elif case[1] == "friendly":
			favor = int(Rivals.rules(d).get("friendly_favor", 20))
		var ids: Array = Exploration.eligible_encounters(c, d, case[2], flags, rival, 1.0, "", "", favor).map(func(e: Dictionary) -> String: return e["encounter"]["id"])
		assert_true(ids.has(case[0]), "%s eligible with tags %s" % [case[0], case[2]])


## C-115: three Soul Formation rival encounters, one per attitude, once-only, with a duel and a peaceful choice.
func test_soul_formation_rival_encounters() -> void:
	var d := data()
	var want := {"rival_soul_stargazing": "friendly", "rival_soul_proud_decree": "proud", "rival_soul_bitter_cairn": "bitter"}
	for id in want:
		assert_true(d.encounters.has(id), id + " exists")
		var e: Dictionary = d.encounters[id]
		assert_eq(e.get("rival_attitude", ""), want[id], id + " attitude")
		assert_eq(e.get("rival", ""), "any", id + " rival kind")
		assert_eq(e.get("requires_flag", ""), "rival_met", id + " waits for the first meeting")
		assert_true(e.has("blocked_by_flag"), id + " is once-only")
		assert_eq(e.get("min_realm", ""), "soul_formation", id + " min realm")
		var duel := false
		for choice: Dictionary in e["choices"]:
			if bool(choice.get("fight_rival", false)):
				duel = true
				assert_true(int(choice.get("rival_grudge", 0)) <= 5, id + " duel grudge at most 5")
		assert_true(duel, id + " has a fight_rival choice")
		assert_true(e["choices"].size() >= 2, id + " has a peaceful choice")


## GUIDE-037: one rule for "where is your rival".
func test_where_text_cases() -> void:
	var d := data()
	var r := new_character(77)
	r.home_region = "misty_forest"
	var named := ", in %s" % Exploration.region_name(d, "misty_forest")
	assert_eq(Rivals.where_text(r, d, "qingshi_village"), named, "elsewhere is named")
	assert_eq(Rivals.where_text(r, d, "misty_forest"), "", "same region is silent")
	assert_eq(Rivals.where_text(r, d, ""), named, "unknown current region names it")


## C-124: three Void Refinement rival encounters, one per attitude, once-only, with a duel and a peaceful choice.
func test_void_refinement_rival_encounters() -> void:
	var d := data()
	var want := {"rival_void_open_door": "friendly", "rival_void_proud_challenge": "proud", "rival_void_bitter_vault": "bitter"}
	for id in want:
		assert_true(d.encounters.has(id), id + " exists")
		var e: Dictionary = d.encounters[id]
		assert_eq(e.get("rival_attitude", ""), want[id], id + " attitude")
		assert_eq(e.get("rival", ""), "any", id + " rival kind")
		assert_eq(e.get("requires_flag", ""), "rival_met", id + " waits for the first meeting")
		assert_true(e.has("blocked_by_flag"), id + " is once-only")
		assert_eq(e.get("min_realm", ""), "void_refinement", id + " min realm")
		assert_true(str(e["text"]).contains("{rival}"), id + " names the rival")
		var duel := false
		for choice: Dictionary in e["choices"]:
			if bool(choice.get("fight_rival", false)):
				duel = true
				assert_true(int(choice.get("rival_grudge", 0)) <= 5, id + " duel grudge at most 5")
		assert_true(duel, id + " has a fight_rival choice")
		assert_true(e["choices"].size() >= 2, id + " has a peaceful choice")


func test_year_line_says_where_the_rival_stands() -> void:
	var c := CharacterFactory.create("Me", data(), seeded_rng(1))
	var r := CharacterFactory.create("Rival", data(), seeded_rng(2))
	var flags := {}
	assert_eq(Rivals.year_line(c, r, flags), "", "before the first meeting")
	flags[Rivals.FIRST_MEETING_FLAG] = true
	assert_eq(Rivals.year_line(c, r, flags), "Rival is level with you.")
	r.stage = c.stage + 1
	assert_eq(Rivals.year_line(c, r, flags), "Rival is a few steps ahead.")
	r.realm_index = c.realm_index + 1
	assert_eq(Rivals.year_line(c, r, flags), "Rival is far ahead of you.")
	r.realm_index = c.realm_index
	r.stage = c.stage
	c.stage += 1
	assert_eq(Rivals.year_line(c, r, flags), "Rival is behind you.")
	flags[Rivals.BOUTS_WON_FLAG] = 2
	flags[Rivals.BOUTS_LOST_FLAG] = 1
	assert_eq(Rivals.year_line(c, r, flags), "Rival is behind you. Bouts: 2 won, 1 lost.")
	r.alive = false
	assert_eq(Rivals.year_line(c, r, flags), "", "dead rival")
	assert_eq(Rivals.year_line(c, null, flags), "")


func test_encounter_cooldown() -> void:
	var d := data()
	var flags := {}
	assert_true(Rivals.encounter_ready(d, flags, 0), "ready with empty flags")
	Rivals.note_encounter(d, flags, 100)
	assert_false(Rivals.encounter_ready(d, flags, 159))
	assert_true(Rivals.encounter_ready(d, flags, 160))
	# data() is cached per test file, so restore the cooldown for the tests that follow.
	var rules: Dictionary = d.karma["rival"]
	var had := rules.has("encounter_cooldown_days")
	var old: Variant = rules.get("encounter_cooldown_days")
	rules["encounter_cooldown_days"] = 0
	var f2 := {}
	Rivals.note_encounter(d, f2, 100)
	assert_true(f2.is_empty(), "cooldown 0 sets nothing")
	assert_true(Rivals.encounter_ready(d, f2, 100))
	if had:
		rules["encounter_cooldown_days"] = old
	else:
		rules.erase("encounter_cooldown_days")


func test_game_state_rival_for_roll_respects_cooldown() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	assert_true(gs._rival_for_roll() != null, "rival available at first")
	Rivals.note_encounter(gs.data, gs.world_flags, GameClock.total_days)
	assert_true(gs._rival_for_roll() == null, "rival quiet during the cooldown")
	GameClock.total_days += Rivals.encounter_cooldown(gs.data)
	assert_true(gs._rival_for_roll() != null, "rival back after the cooldown")
	gs.end_session()


func test_friendly_rival_gets_spar_not_contest() -> void:
	var d := GameData.load_from_dir()
	var c := new_character()
	var rival := new_character(77)
	rival.id = "gen_rival"
	c.realm_index = 1
	rival.realm_index = 1
	# Only the two real encounters under test, on a private tag, so the fight-share trimming has nothing else to trim.
	for id: String in d.encounters.keys():
		if id != "rival_contest" and id != "rival_spar_friendly" and not id.begins_with("wild_"):
			continue
		d.encounters[id] = d.encounters[id].duplicate()
		d.encounters[id]["tags"] = ["spar_tag"]
	var ids := func(favor: int) -> Array:
		return Exploration.eligible_encounters(c, d, ["spar_tag"], {}, rival, 1.0, "", "", favor).map(func(e: Dictionary) -> String: return e["encounter"]["id"])
	var friendly: Array = ids.call(20)
	assert_true(friendly.has("rival_spar_friendly"), "friendly rival invites a spar")
	assert_false(friendly.has("rival_contest"), "friendly rival never ambushes")
	var proud: Array = ids.call(0)
	assert_true(proud.has("rival_contest"), "proud rival duels")
	assert_false(proud.has("rival_spar_friendly"), "proud rival never offers the friendly spar")
	c.grudges["gen_rival"] = 10
	var bitter: Array = ids.call(20)
	assert_true(bitter.has("rival_contest") and not bitter.has("rival_spar_friendly"), "bitter rival duels")


func test_attitude_array_validation() -> void:
	var d := GameData.load_from_dir()
	d.encounters["ok_att"] = {"id": "ok_att", "tags": ["city"], "rival": "any", "rival_attitude": ["proud", "bitter"], "text": "Hi."}
	assert_eq(Rivals.validate(d).size(), 0, ", ".join(Rivals.validate(d)))
	d.encounters["bad_att3"] = {"id": "bad_att3", "tags": ["city"], "rival": "any", "rival_attitude": ["proud", "angry"], "text": "Hi."}
	assert_eq(Rivals.validate(d).size(), 1, ", ".join(Rivals.validate(d)))
