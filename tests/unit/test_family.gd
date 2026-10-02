extends TestCase
## FAM-002: courtship and marriage rules (data/family.json, Family).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _person(gender: String, id: String, age: int = 20) -> CharacterData:
	var c := new_character()
	c.id = id
	c.name = id
	c.gender = gender
	c.age_days = age * Calendar.DAYS_PER_YEAR
	return c


func test_partner_rules() -> void:
	var he := _person("male", "player")
	var she := _person("female", "npc_a")
	assert_eq(Family.check_partner(he, she, data()), "")
	assert_true(Family.check_partner(he, _person("male", "npc_b"), data()) != "", "partner_genders from data")
	assert_true(Family.check_partner(he, _person("female", "npc_c", 12), data()) != "", "too young")
	assert_true(Family.check_partner(_person("", "player"), she, data()) != "", "unknown gender")
	var taken := _person("female", "npc_d")
	taken.spouses.append("someone")
	assert_true(Family.check_partner(he, taken, data()) != "", "already married")


func test_courting_needs_favor_and_scales_with_charisma() -> void:
	var he := _person("male", "player")
	var she := _person("female", "npc_a")
	assert_false(Family.court(he, she, 0, data())["ok"])
	he.attributes["charisma"] = 10
	var base: int = Family.court(he, she, 20, data())["favor"]
	he.attributes["charisma"] = 14
	assert_eq(Family.court(he, she, 20, data())["favor"], base + 2)
	he.attributes["charisma"] = 0
	assert_gt(Family.court(he, she, 20, data())["favor"], 0, "always at least 1")


func test_proposal_refusals() -> void:
	var he := _person("male", "player")
	var she := _person("female", "npc_a")
	assert_true(Family.check_proposal(he, she, 30, "wife", data()) != "", "favor too low")
	assert_true(Family.check_proposal(he, she, 100, "dao_companion", data()) != "", "not a rank for men")
	she.realm_index = 3
	assert_true(Family.check_proposal(he, she, 100, "wife", data()) != "", "realm gap")
	she.realm_index = 0
	he.alignment = 700
	she.alignment = -700
	assert_true(Family.check_proposal(he, she, 100, "wife", data()) != "", "alignment clash")
	she.alignment = 600
	assert_eq(Family.check_proposal(he, she, 100, "wife", data()), "")
	she.realm_index = 1
	assert_true(Family.check_proposal(he, she, 100, "concubine", data()).contains("proud"), "a stronger cultivator refuses to be a concubine")


func test_wife_and_concubine_limits() -> void:
	var he := _person("male", "player")
	var a := _person("female", "npc_a")
	var b := _person("female", "npc_b")
	var c2 := _person("female", "npc_c")
	assert_true(Family.propose(he, a, 100, "wife", data())["ok"])
	assert_eq(he.spouse_ranks["npc_a"], "wife")
	assert_eq(a.spouses, ["player"] as Array[String])
	assert_eq(a.spouse_ranks["player"], "wife")
	assert_true(Family.check_proposal(he, b, 100, "wife", data()).contains("another"), "only one main wife")
	assert_eq(Family.rank_limit(he, data(), "concubine"), 1)
	assert_true(Family.propose(he, b, 100, "concubine", data())["ok"])
	assert_false(Family.propose(he, c2, 100, "concubine", data())["ok"], "concubine slots full for a mortal")
	he.realm_index = 1
	c2.realm_index = 1
	assert_eq(Family.rank_limit(he, data(), "concubine"), 2, "more slots with realm")
	assert_true(Family.propose(he, c2, 100, "concubine", data())["ok"])


func test_female_has_one_dao_companion() -> void:
	var she := _person("female", "player")
	assert_eq(Family.ranks(data(), "female"), ["dao_companion"] as Array[String])
	assert_true(Family.propose(she, _person("male", "npc_a"), 100, "dao_companion", data())["ok"])
	assert_false(Family.propose(she, _person("male", "npc_b"), 100, "dao_companion", data())["ok"])


func test_spouse_ranks_round_trip_in_saves() -> void:
	var he := _person("male", "player")
	Family.marry(he, _person("female", "npc_a"), "wife")
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(he.to_dict())))
	assert_eq(back.spouse_ranks, {"npc_a": "wife"})
	assert_true(CharacterData.from_dict({}).spouse_ranks.is_empty(), "old saves load")


func test_family_data_is_valid() -> void:
	assert_true(Family.validate(data()).is_empty())
	var d := GameData.new()
	d.names = data().names
	d.family = {"genders": {"male": {"partner_genders": ["dragon"], "ranks": {}}}}
	assert_eq(Family.validate(d).size(), 3, "missing female rules, unknown partner gender, no ranks")


func test_game_state_court_and_propose() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Suitor", gs.data, seeded_rng())
	c.gender = "male"
	gs.start_session(c)
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.court("xiao_ling")
	assert_eq(int(gs.npc_favor.get("xiao_ling", 0)), 0, "no favor yet: refused")
	assert_eq(clock.total_days, days)
	gs.npc_favor["xiao_ling"] = 20
	gs.court("xiao_ling")
	assert_gt(int(gs.npc_favor["xiao_ling"]), 20)
	assert_gt(clock.total_days, days, "courting takes time")
	gs.propose("xiao_ling", "wife")
	assert_true(c.spouses.is_empty(), "favor still too low")
	gs.npc_favor["xiao_ling"] = 80
	gs.propose("xiao_ling", "wife")
	assert_eq(c.spouse_ranks.get("xiao_ling", ""), "wife")
	assert_true(gs.npcs["xiao_ling"].spouses.has("player"))
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.player.spouse_ranks.get("xiao_ling", ""), "wife")
	assert_eq(gs.npcs["xiao_ling"].spouse_ranks.get("player", ""), "wife")
	gs.end_session()
