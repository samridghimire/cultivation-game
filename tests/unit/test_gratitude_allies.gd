extends TestCase
## RIV-001f: encounters name NPCs who owe you, and deeply grateful NPCs in the
## current region join your fights with an opening strike.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _npc(people: Dictionary, id: String, region: String, age: int = 30) -> CharacterData:
	var n := new_character(id.hash())
	n.id = id
	n.name = id.capitalize()
	n.home_region = region
	n.realm_index = 1
	n.age_days = age * Calendar.DAYS_PER_YEAR
	people[id] = n
	return n


func test_strike_ally_rules() -> void:
	var people := {}
	var me := new_character()
	var rules: Dictionary = data().karma["gratitude"]["ally_strike"]
	var min_gratitude := int(rules["min_gratitude"])
	_npc(people, "here", "qingshi_village")
	_npc(people, "deeper", "qingshi_village")
	_npc(people, "away", "misty_forest")
	_npc(people, "kid", "qingshi_village", 8)
	for id in ["here", "away", "kid"]:
		Karma.add_gratitude(me, data(), id, min_gratitude)
	Karma.add_gratitude(me, data(), "deeper", min_gratitude - 1)
	assert_eq(Karma.strike_ally(me, people, data(), "qingshi_village"), "here", "only adults here who owe enough")
	assert_eq(Karma.strike_ally(me, people, data(), "qingshi_village", "here"), "", "not against themselves")
	Karma.add_gratitude(me, data(), "deeper", 10)
	assert_eq(Karma.strike_ally(me, people, data(), "qingshi_village"), "deeper", "the most grateful comes")
	var strike := Karma.ally_strike(me, people, data(), "deeper")
	assert_eq(strike["name"], "Deeper")
	assert_eq(int(strike["damage"]), int(Combat.stats(people["deeper"], data())["attack"]) * int(rules["blows"]))
	assert_eq(Karma.gratitude(me, "deeper"), min_gratitude + 9 - int(rules["cost"]), "the strike spends gratitude")


func test_allies_strike_first_in_combat() -> void:
	var c := new_character()
	var enemy: Dictionary = data().enemies["mountain_bandit"]
	var with_ally := Combat.resolve(c, data(), enemy, seeded_rng(4), [{"name": "Lin Mei", "damage": 5}])
	assert_true(Array(with_ally["log"]).any(func(l: String) -> bool: return l.begins_with("Lin Mei, who owes you a debt, strikes")), str(with_ally["log"]))
	var huge := Combat.resolve(c, data(), enemy, seeded_rng(4), [{"name": "Lin Mei", "damage": 1000000}])
	assert_true(huge["victory"])
	assert_eq(int(huge["rounds"]), 0, "the ally ends it before the first round")


func test_game_state_ally_joins_fights_but_not_spars() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var ally := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"region": gs.current_region, "age_years": 30, "realm": "qi_refining"})
	Karma.add_gratitude(c, gs.data, ally.id, 100)
	var seen: Array = []
	var cb := func(_foe: String, _won: bool, log: PackedStringArray): seen.append(log)
	EventBus.combat_finished.connect(cb)
	gs.fight_enemy(Sects.trial_opponent(gs.data, "mountain_bandit"))
	assert_eq(Karma.gratitude(c, ally.id), 100, "allies stay out of sparring matches")
	gs.fight("mountain_bandit")
	EventBus.combat_finished.disconnect(cb)
	var cost := int(gs.data.karma["gratitude"]["ally_strike"]["cost"])
	assert_eq(Karma.gratitude(c, ally.id), 100 - cost)
	assert_true(Array(seen[-1]).any(func(l: String) -> bool: return l.contains("who owes you a debt")), str(seen[-1]))
	gs.end_session()


func test_encounter_choice_creates_a_grateful_npc() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var before: int = gs.npcs.size()
	gs.pending_encounter = "village_drowning_child"
	gs.choose_encounter(0)
	assert_eq(gs.npcs.size(), before + 1)
	var saved_id := ""
	for id: String in c.gratitude:
		saved_id = id
	var father: CharacterData = gs.npcs[saved_id]
	assert_eq(Karma.gratitude(c, saved_id), 60)
	assert_eq(father.gender, "male")
	assert_eq(Npcs.region_of(father, gs.data), gs.current_region)
	assert_eq(int(gs.npc_favor[saved_id]), 15)
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).begins_with(father.name + " will not forget")))
	gs.end_session()


func test_lost_fight_saves_no_one() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	c.attributes["constitution"] = 1  # hopeless against the thug
	for slot in c.equipment.keys():
		c.equipment.erase(slot)
	var thug: Dictionary = gs.data.enemies["mountain_bandit"].duplicate(true)
	gs.data.enemies["mountain_bandit"]["stage"] = 0
	gs.data.enemies["mountain_bandit"]["realm"] = "core_formation"
	gs.pending_encounter = "city_cornered_merchant"
	gs.choose_encounter(1)
	gs.data.enemies["mountain_bandit"] = thug
	assert_true(c.gratitude.is_empty(), "the merchant is not saved")
	gs.end_session()


func test_grateful_npc_validation() -> void:
	var where := "Encounter 'x' choice 'y'"
	assert_eq(Exploration._validate_grateful(data(), {"amount": 10}, where).size(), 0)
	assert_eq(Exploration._validate_grateful(data(), {"amount": 0, "realm": "nope", "age_years": [5, 1], "gender": "dragon"}, where).size(), 4)
