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
