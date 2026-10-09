extends TestCase
## QA-040: pointers and spar audit (cooldowns across save/load, dead or young
## NPCs, spar losses, favor cap, a year of spars, mastered techniques).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _gs() -> Node:
	return _root().get_node("GameState")


func _setup(npc_realm: int, favor: int) -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Audit", gs.data, seeded_rng(4242))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	c.realm_index = 3
	c.techniques = {"iron_fist": {"level": 1, "xp": 0.0}}
	c.inventory = {"spirit_stone": 50}
	var npc := CharacterFactory.create("Audit Friend", gs.data, seeded_rng(9))
	npc.id = "friend"
	npc.age_days = 40 * Calendar.DAYS_PER_YEAR
	npc.realm_index = npc_realm
	gs.npcs["friend"] = npc
	gs.npc_favor["friend"] = favor
	return c


func _reload(gs: Node) -> void:
	gs.load_save_dict(JSON.parse_string(JSON.stringify(gs.to_save_dict())))


func test_cooldowns_survive_save_and_load() -> void:
	var c := _setup(4, 50)
	var gs := _gs()
	gs.ask_pointers("friend")
	gs.spar_with("friend")
	_reload(gs)
	assert_true(gs.check_pointers("friend").contains("recently"), gs.check_pointers("friend"))
	assert_true(gs.check_spar("friend").contains("recently"), gs.check_spar("friend"))
	assert_true(gs.player.npc_action_days.has("spar:friend"))
	assert_true(c != null)
	gs.end_session()


func test_dead_npc_gives_nothing() -> void:
	_setup(4, 50)
	var gs := _gs()
	gs.npcs["friend"].alive = false
	var day: int = _root().get_node("GameClock").total_days
	gs.ask_pointers("friend")
	gs.spar_with("friend")
	assert_eq(_root().get_node("GameClock").total_days, day, "no time passes")
	assert_false(gs.player.npc_action_days.has("spar:friend"))
	assert_false(gs.player.npc_action_days.has("pointers:friend"))
	gs.end_session()


func test_child_npc_refused() -> void:
	_setup(4, 50)
	var gs := _gs()
	gs.npcs["friend"].age_days = 10 * Calendar.DAYS_PER_YEAR
	assert_true(gs.check_pointers("friend").contains("too young"))
	assert_true(gs.check_spar("friend").contains("too young"))
	gs.end_session()


func test_dead_player_cannot_spar_or_ask() -> void:
	var c := _setup(4, 50)
	var gs := _gs()
	c.alive = false
	gs.ask_pointers("friend")
	gs.spar_with("friend")
	assert_false(c.npc_action_days.has("spar:friend"))
	assert_false(c.npc_action_days.has("pointers:friend"))
	gs.end_session()


func test_spar_losses_cost_nothing_across_seeds() -> void:
	var gs := _gs()
	for seed_value in 12:
		var c := _setup(4, 50)
		gs.rng.seed = seed_value + 1
		c.realm_index = 1  # outmatched by a 2nd-realm elder, so many bouts are losses
		gs.npcs["friend"].realm_index = 2
		gs.npcs["friend"].stage = 8
		var lost := LifeStats.get_stat(c, "fights_lost")
		var won := LifeStats.get_stat(c, "fights_won")
		gs.spar_with("friend")
		assert_eq(c.item_count("spirit_stone"), 50, "seed %d stones" % seed_value)
		assert_true(c.injuries.is_empty(), "seed %d injury" % seed_value)
		assert_eq(LifeStats.get_stat(c, "fights_lost"), lost)
		assert_eq(LifeStats.get_stat(c, "fights_won"), won)
		assert_true(c.alive, "seed %d alive" % seed_value)
		assert_true(gs.devour_target.is_empty(), "a spar partner can't be devoured")
		gs.end_session()


func test_spar_favor_never_passes_100() -> void:
	var gs := _gs()
	var c := _setup(3, 99)
	c.realm_index = 3
	c.stage = 9
	gs.npcs["friend"].realm_index = 3
	gs.npcs["friend"].stage = 0
	for i in 20:
		c.npc_action_days.erase("spar:friend")
		gs.spar_with("friend")
	assert_true(int(gs.npc_favor["friend"]) <= 100, str(gs.npc_favor["friend"]))
	gs.end_session()


func test_a_year_of_spars_is_bounded() -> void:
	var gs := _gs()
	var c := _setup(3, 10)
	c.stage = 9
	gs.npcs["friend"].stage = 0
	var rules: Dictionary = gs.data.family["mentorship"]["spar"]
	var start_favor := 10
	var clock := _root().get_node("GameClock")
	var end_day: int = clock.total_days + 365
	var bouts := 0
	while clock.total_days < end_day and c.alive and bouts < 400:
		gs.spar_with("friend")
		bouts += 1
		if gs.check_spar("friend") != "":
			gs.cultivate(1)
	var gained := int(gs.npc_favor["friend"]) - start_favor
	var cap := (365 / int(rules["cooldown_days"]) + 2) * int(rules["win_favor"])
	assert_true(gained <= cap, "gained %d favor in a year (cap %d)" % [gained, cap])
	gs.end_session()


func test_pointers_cannot_level_a_mastered_technique() -> void:
	var c := _setup(4, 50)
	var gs := _gs()
	var def: TechniqueDef = gs.data.techniques["iron_fist"]
	c.techniques["iron_fist"]["level"] = def.max_level
	var before := c.techniques.duplicate(true)
	gs.ask_pointers("friend")
	assert_eq(c.techniques, before)
	assert_false(c.npc_action_days.has("pointers:friend"))
	gs.end_session()


## RV-014: an evil weapon does not drink lifespan in a friendly spar, but does in a real fight.
func test_spar_does_not_drain_lifespan() -> void:
	var c := _setup(4, 50)
	var gs := _gs()
	c.inventory["blood_drinker_saber"] = 1
	Equipment.equip(c, gs.data, "blood_drinker_saber")
	var years := Cultivation.years_left(c, gs.data)
	gs.spar_with("friend")
	assert_eq(Cultivation.years_left(c, gs.data), years)
	gs.fight_enemy({"name": "Wolf", "hp": 5, "attack": 1, "defense": 0, "speed": 1})
	assert_true(Cultivation.years_left(c, gs.data) < years)
	gs.end_session()
