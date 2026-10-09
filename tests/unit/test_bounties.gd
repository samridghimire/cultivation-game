extends TestCase
## BOUNTY-001: bounties taken from a board, hunted while exploring, paid on a win.


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _qi(stage: int = 4) -> CharacterData:
	var c := new_character()
	c.realm_index = 1
	c.stage = stage
	return c


func _errors_after(mutate: Callable) -> Array:
	var d := GameData.load_from_dir()
	mutate.call(d)
	d.load_errors.clear()
	d._validate_bounties()
	return d.load_errors


func test_shipped_bounties_validate() -> void:
	assert_eq(data().bounties.size(), 11)
	var regions := {}
	for b: Dictionary in data().bounties.values():
		regions[b["region"]] = int(regions.get(b["region"], 0)) + 1
	assert_eq(regions.size(), data().regions.size(), "every region posts a bounty")
	assert_eq(_errors_after(func(_d: GameData) -> void: pass), [])


func test_validator_rejects_bad_bounties() -> void:
	var mutations := {
		"enemy": func(b: Dictionary) -> void: b["enemy"] = "no_such_enemy",
		"region": func(b: Dictionary) -> void: b["region"] = "no_such_region",
		"reward_stones": func(b: Dictionary) -> void: b["reward_stones"] = 0,
		"days": func(b: Dictionary) -> void: b["days"] = 6,
	}
	for key: String in mutations:
		var errors := _errors_after(func(d: GameData) -> void: mutations[key].call(d.bounties["iron_back_boar_bounty"]))
		assert_true(errors.any(func(m: String) -> bool: return m.contains(key)), key + ": " + str(errors))


func test_offers_follow_realm_and_cooldown() -> void:
	var c := _qi()
	var ids := Bounties.offers(c, data(), 0).map(func(b: Dictionary) -> String: return b["id"])
	assert_true(ids.has("iron_back_boar_bounty"), str(ids))
	c.bounty_cooldowns["iron_back_boar_bounty"] = 50
	var cooling := Bounties.offers(c, data(), 10).map(func(b: Dictionary) -> String: return b["id"])
	assert_false(cooling.has("iron_back_boar_bounty"), str(cooling))
	var again := Bounties.offers(c, data(), 50).map(func(b: Dictionary) -> String: return b["id"])
	assert_true(again.has("iron_back_boar_bounty"), str(again))
	c.realm_index = data().realm_index_of("core_formation")
	ids = Bounties.offers(c, data(), 500).map(func(b: Dictionary) -> String: return b["id"])
	assert_true(ids.has("black_iron_bear_king_bounty") and ids.has("thunderwing_roc_bounty"), str(ids))
	assert_false(ids.has("iron_back_boar_bounty"), "max_realm hides the Qi Refining and Foundation postings")


func test_take_active_and_expire() -> void:
	var c := _qi()
	assert_eq(Bounties.check_take(c, data(), "iron_back_boar_bounty", 0), "")
	Bounties.take(c, data(), "iron_back_boar_bounty", 10)
	assert_eq(Bounties.check_take(c, data(), "iron_back_boar_bounty", 10), "You are already on a hunt.")
	assert_eq(Bounties.active(c, data(), 20)["until_day"], 70)
	var held := Bounties.offers(c, data(), 20).map(func(b: Dictionary) -> String: return b["id"])
	assert_false(held.has("iron_back_boar_bounty"), "the taken posting leaves the board")
	assert_eq(Bounties.expire(c, data(), 70), "")
	assert_eq(Bounties.expire(c, data(), 71), "iron_back_boar_bounty")
	assert_true(c.bounty.is_empty())
	assert_eq(c.bounty_cooldowns["iron_back_boar_bounty"], 71 + 120)
	assert_true(Bounties.check_take(c, data(), "iron_back_boar_bounty", 72).begins_with("Posted again in"))
	assert_eq(Bounties.check_take(c, data(), "black_iron_bear_king_bounty", 72), "That bounty is not posted for you.")


func test_hunt_roll_only_in_the_region() -> void:
	var c := _qi()
	var rng := seeded_rng(5)
	assert_eq(Bounties.hunt_roll(c, data(), "misty_forest", 0, rng), "")
	Bounties.take(c, data(), "iron_back_boar_bounty", 0)
	var hits := 0
	for i in 50:
		assert_eq(Bounties.hunt_roll(c, data(), "azure_peak", 1, rng), "")
		if Bounties.hunt_roll(c, data(), "misty_forest", 1, rng) == "iron_back_boar":
			hits += 1
	assert_true(hits > 0 and hits < 50, str(hits))


func test_complete_pays_and_counts() -> void:
	var c := _qi()
	Bounties.take(c, data(), "iron_back_boar_bounty", 0)
	var before := c.item_count("spirit_stone")
	assert_eq(Bounties.complete(c, data(), 30), 40)
	assert_eq(c.item_count("spirit_stone"), before + 40)
	assert_eq(LifeStats.get_stat(c, "bounties_done"), 1)
	assert_eq(LifeStats.get_stat(c, "stones_earned"), 40, "bounty pay is income")
	assert_true(c.bounty.is_empty())
	assert_eq(c.bounty_cooldowns["iron_back_boar_bounty"], 150)
	Bounties.take(c, data(), "iron_back_boar_bounty", 200)
	Bounties.abandon(c, data(), 210)
	assert_true(c.bounty.is_empty())
	assert_eq(c.bounty_cooldowns["iron_back_boar_bounty"], 330)


func test_journal_line_while_hunting() -> void:
	var c := _qi()
	Bounties.take(c, data(), "iron_back_boar_bounty", 0)
	var rows := Guidance.journal(c, data(), {}, 5, "misty_forest")
	assert_true(rows.any(func(r: Dictionary) -> bool: return String(r.get("text", "")).begins_with("Bounty: Iron-Back Boar")), str(rows))


func test_old_saves_have_no_bounty() -> void:
	var d := new_character().to_dict()
	d.erase("bounty")
	d.erase("bounty_cooldowns")
	var c := CharacterData.from_dict(d)
	assert_true(c.bounty.is_empty() and c.bounty_cooldowns.is_empty())


func _start_hunt(gs: Node, enemy_id: String) -> CharacterData:
	var c := CharacterFactory.create("Hunter", gs.data, seeded_rng(9))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	gs.current_region = "misty_forest"
	gs.world_flags["discovered_misty_forest"] = true
	gs.data.bounties["t_bounty"] = {"id": "t_bounty", "enemy": enemy_id, "region": "misty_forest", "reward_stones": 25, "days": 30, "cooldown_days": 10, "text": "Test posting."}
	gs.data.bounty_config["hunt_chance"] = 1.0
	return c


func _finish(gs: Node) -> void:
	gs.data.bounties.erase("t_bounty")
	gs.data.bounty_config["hunt_chance"] = 0.3
	gs.data.enemies.erase("t_titan")
	gs.end_session()


func test_gamestate_win_claims_the_bounty() -> void:
	var gs := _gs()
	var c := _start_hunt(gs, "wild_boar")
	gs.take_bounty("t_bounty")
	assert_eq(String(c.bounty.get("id", "")), "t_bounty")
	var stones := c.item_count("spirit_stone")
	gs.explore()
	assert_true(c.bounty.is_empty(), "claimed")
	assert_eq(c.item_count("spirit_stone"), stones + 25)
	assert_eq(LifeStats.get_stat(c, "bounties_done"), 1)
	_finish(gs)


func test_gamestate_trail_on_the_last_day_still_pays() -> void:
	var gs := _gs()
	var c := _start_hunt(gs, "wild_boar")
	gs.take_bounty("t_bounty")
	var clock := (Engine.get_main_loop() as SceneTree).root.get_node("GameClock")
	clock.advance(int(c.bounty["until_day"]) - int(clock.total_days))
	assert_eq(String(c.bounty.get("id", "")), "t_bounty", "still open on its last day")
	var stones := c.item_count("spirit_stone")
	gs.explore()
	assert_eq(c.item_count("spirit_stone"), stones + 25, "claimed before the day ran out")
	assert_eq(LifeStats.get_stat(c, "bounties_done"), 1)
	_finish(gs)


func test_gamestate_deadly_foe_keeps_the_bounty() -> void:
	var gs := _gs()
	var foe: Dictionary = gs.data.enemies["mist_wolf"].duplicate(true)
	foe.merge({"id": "t_titan", "realm": "core_formation", "attack": 900, "hp": 9000, "lethal": true}, true)
	gs.data.enemies["t_titan"] = foe
	var c := _start_hunt(gs, "t_titan")
	assert_true(Exploration.should_evade(c, gs.data, "t_titan"))
	gs.take_bounty("t_bounty")
	var fights := LifeStats.get_stat(c, "fights_won") + LifeStats.get_stat(c, "fights_lost")
	gs.explore()
	assert_eq(String(c.bounty.get("id", "")), "t_bounty", "the bounty stays open")
	assert_eq(LifeStats.get_stat(c, "fights_won") + LifeStats.get_stat(c, "fights_lost"), fights, "no fight happened")
	_finish(gs)


func test_gamestate_bounty_lapses_and_abandons() -> void:
	var gs := _gs()
	var c := _start_hunt(gs, "wild_boar")
	gs.take_bounty("t_bounty")
	gs.take_bounty("t_bounty")
	gs.abandon_bounty()
	assert_true(c.bounty.is_empty())
	assert_true(c.bounty_cooldowns.has("t_bounty"))
	c.bounty_cooldowns.clear()
	gs.take_bounty("t_bounty")
	(Engine.get_main_loop() as SceneTree).root.get_node("GameClock").advance(31)
	assert_true(c.bounty.is_empty(), "lapsed")
	_finish(gs)


func _fixture(d: GameData) -> void:
	d.bounties.clear()
	d.bounty_config["offers"] = 3
	var rows := [["b_far1", "azure_peak"], ["b_far2", "azure_peak"], ["b_near", "misty_forest"], ["b_local1", "qingshi_village"], ["b_local2", "qingshi_village"]]
	for row: Array in rows:
		d.bounties[row[0]] = {"id": row[0], "enemy": "wild_boar", "region": row[1], "reward_stones": 10, "days": 30, "cooldown_days": 10, "text": "x"}


func _ids(list: Array[Dictionary]) -> Array:
	return list.map(func(b: Dictionary) -> String: return b["id"])


func test_offers_list_local_then_nearby_first() -> void:
	var d := GameData.load_from_dir()
	_fixture(d)
	var c := _qi()
	assert_eq(_ids(Bounties.offers(c, d, 0, "qingshi_village")), ["b_local1", "b_local2", "b_near"])
	assert_eq(_ids(Bounties.offers(c, d, 0)), ["b_far1", "b_far2", "b_near"], "no region keeps data order")
	c.bounty_cooldowns["b_local1"] = 50
	assert_eq(_ids(Bounties.offers(c, d, 10, "qingshi_village")), ["b_local2", "b_near", "b_far1"])
	d.bounties["b_local2"]["min_realm"] = "core_formation"
	assert_eq(_ids(Bounties.offers(c, d, 10, "qingshi_village")), ["b_near", "b_far1", "b_far2"], "realm gate hides it")


func test_board_lists_nearby_hunts_first() -> void:
	var gs := _gs()
	var c := _qi(3)
	gs.start_session(c)
	var board: Node = load("res://src/world/interactables/bounty_board.gd").new()
	var first: Dictionary = board.get_options()[0]
	var near := Bounties.offers(c, gs.data, GameClock.total_days, gs.current_region)
	assert_eq(String(first["label"]).contains(Exploration.region_name(gs.data, String(near[0]["region"]))), true, first["label"])
	gs.end_session()
