extends TestCase
## FAM-005: founding and running the player's clan (data/family.json "clan", Clans).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _founder() -> CharacterData:
	var c := new_character()
	c.gender = "male"
	c.surname = "Lin"
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.inventory = {"spirit_stone": 1000}
	return c


func _npc(people: Dictionary, id: String, age: int = 20) -> CharacterData:
	var n := new_character(id.hash())
	n.id = id
	n.name = id
	n.age_days = age * Calendar.DAYS_PER_YEAR
	people[id] = n
	return n


func test_data_has_valid_clan_rules() -> void:
	assert_eq(Clans.validate(data()).size(), 0)
	assert_eq(Clans.head_rank(data()), "patriarch")
	assert_eq(Clans.rank_name(data(), "patriarch", "female"), "Matriarch")
	assert_eq(Clans.rank_name(data(), "patriarch", "male"), "Patriarch")


func test_founding_needs_realm_and_stones() -> void:
	var c := _founder()
	assert_eq(Clans.check_found(c, null, data()), "")
	c.realm_index = 1
	assert_true(Clans.check_found(c, null, data()).contains("realm"))
	c.realm_index = data().realm_index_of("foundation_establishment")
	c.inventory = {}
	assert_true(Clans.check_found(c, null, data()).contains("spirit stones"))
	assert_true(Clans.check_found(c, ClanData.new(), data()).contains("already"))


func test_founding_brings_in_the_living_family() -> void:
	var c := _founder()
	var people := {}
	var wife := _npc(people, "gen_wife")
	Family.marry(c, wife, "wife")
	var son := _npc(people, "gen_son", 3)
	var grandchild := _npc(people, "gen_grandchild", 1)
	var dead_daughter := _npc(people, "gen_daughter", 10)
	dead_daughter.alive = false
	c.children.append_array([son.id, dead_daughter.id])
	son.children.append(grandchild.id)
	var result := Clans.found(c, null, people, data(), 42)
	assert_true(result["ok"], str(result["reason"]))
	var clan: ClanData = result["clan"]
	assert_eq(clan.name, "Lin Clan")
	assert_eq(clan.founded_day, 42)
	assert_eq(clan.members[c.id], "patriarch")
	assert_eq(clan.members[wife.id], "core")
	assert_eq(clan.members[grandchild.id], "core", "descendants of descendants join")
	assert_false(clan.members.has(dead_daughter.id))
	assert_eq(c.item_count("spirit_stone"), 1000 - int(Clans.rules(data())["found_cost"]))
	var newborn := _npc(people, "gen_newborn", 0)
	c.children.append(newborn.id)
	son.alive = false
	assert_eq(Clans.sync_family(c, clan, people, data()), ["gen_newborn"] as Array[String])
	assert_false(clan.members.has(son.id), "dead members leave the roll")


func test_recruiting_and_ranks() -> void:
	var c := _founder()
	var people := {}
	var clan: ClanData = Clans.found(c, null, people, data(), 0)["clan"]
	var stranger := _npc(people, "gen_stranger")
	assert_true(Clans.check_recruit(c, clan, stranger, 0, data()).contains("trust"))
	var favor := int(Clans.rules(data())["recruit_min_favor"])
	assert_true(Clans.check_recruit(c, clan, _npc(people, "gen_kid", 8), favor, data()).contains("young"))
	assert_true(Clans.recruit(c, clan, stranger, favor, data())["ok"])
	assert_eq(clan.members[stranger.id], "outer")
	assert_true(Clans.check_recruit(c, clan, stranger, favor, data()).contains("already"))
	assert_true(Clans.check_promote(clan, stranger, "elder", data()).contains("reached"), "elders need Foundation")
	assert_true(Clans.promote(clan, stranger, "core", data())["ok"])
	assert_true(Clans.check_promote(clan, stranger, "patriarch", data()) != "", "nobody else becomes head")
	var dummy := CharacterData.new()
	dummy.id = c.id
	assert_true(Clans.check_promote(clan, dummy, "outer", data()).contains("head"))
	for i in 3:
		var elder := _npc(people, "gen_elder_%d" % i)
		elder.realm_index = data().realm_index_of("foundation_establishment")
		clan.members[elder.id] = "outer"
		assert_true(Clans.promote(clan, elder, "elder", data())["ok"])
	stranger.realm_index = data().realm_index_of("foundation_establishment")
	assert_true(Clans.check_promote(clan, stranger, "elder", data()).contains("already has 3"))


func test_deposit_and_save_round_trip() -> void:
	var c := _founder()
	var clan: ClanData = Clans.found(c, null, {}, data(), 7)["clan"]
	assert_false(Clans.deposit(c, clan, 0)["ok"])
	assert_false(Clans.deposit(c, clan, 100000)["ok"])
	assert_true(Clans.deposit(c, clan, 200)["ok"])
	assert_eq(clan.treasury, 200)
	var copy := ClanData.from_dict(JSON.parse_string(JSON.stringify(clan.to_dict())))
	assert_eq(copy.name, clan.name)
	assert_eq(copy.members, clan.members)
	assert_eq(copy.treasury, 200)
	assert_eq(copy.founded_day, 7)


func test_game_state_clan_actions() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	gs.found_clan()
	assert_eq(gs.clan, null, "a mortal cannot found a clan")
	c.realm_index = gs.data.realm_index_of("foundation_establishment")
	c.inventory["spirit_stone"] = 2000
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.found_clan()
	assert_true(gs.clan != null)
	assert_gt(clock.total_days, days, "founding takes time")
	var retainer := Npcs.spawn(gs.npcs, gs.data, seeded_rng(4), {"age_years": 25, "region": gs.current_region})
	gs.recruit_to_clan(retainer.id)
	assert_false(gs.clan.members.has(retainer.id), "no favor yet")
	gs.npc_favor[retainer.id] = 100
	gs.recruit_to_clan(retainer.id)
	assert_eq(gs.clan.members[retainer.id], "outer")
	gs.set_clan_rank(retainer.id, "core")
	assert_eq(gs.clan.members[retainer.id], "core")
	gs.deposit_to_clan(300)
	assert_eq(gs.clan.treasury, 300)
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.clan.treasury, 300, "clan survives a save")
	assert_eq(gs.clan.members[retainer.id], "core")
	saved.erase("clan")
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.clan, null, "old saves have no clan")
	gs.end_session()
	assert_eq(gs.clan, null)
