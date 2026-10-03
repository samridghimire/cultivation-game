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
	assert_eq(Family.validate(d).size(), 4, "missing female rules, unknown partner gender, no ranks, no dual_cultivation")


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


# --- FAM-002b: dual cultivation ---------------------------------------------

func _couple() -> Array[CharacterData]:
	var he := _person("male", "player")
	var she := _person("female", "npc_a")
	he.spiritual_roots = {"fire": 60, "wood": 60, "earth": 60}
	she.spiritual_roots = {"fire": 60, "wood": 60, "earth": 60}
	he.realm_index = 1
	she.realm_index = 1
	he.stage = 0
	she.stage = 0
	he.qi = 0.0
	she.qi = 0.0
	return [he, she]


func test_dual_cultivation_needs_a_rooted_spouse() -> void:
	var pair := _couple()
	assert_true(Family.check_dual_cultivation(pair[0], pair[1], data()) != "", "not married")
	Family.marry(pair[0], pair[1], "wife")
	assert_eq(Family.check_dual_cultivation(pair[0], pair[1], data()), "")
	pair[1].spiritual_roots = {}
	assert_true(Family.check_dual_cultivation(pair[0], pair[1], data()) != "", "spouse without roots")
	pair[1].spiritual_roots = {"fire": 60}
	pair[1].alive = false
	assert_true(Family.check_dual_cultivation(pair[0], pair[1], data()) != "", "dead spouse")
	assert_false(Family.dual_cultivate(pair[0], pair[1], data(), 10)["ok"])


func test_dual_cultivation_bonus_scales_with_partner() -> void:
	var pair := _couple()
	var he := pair[0]
	var she := pair[1]
	var base := Family.dual_multiplier(he, she, data())
	assert_gt(base, 1.0, "cultivating together helps")
	she.realm_index = 2
	assert_gt(Family.dual_multiplier(he, she, data()), base, "a higher-realm partner helps more")
	assert_gt(base, Family.dual_multiplier(she, he, data()), "a lower-realm partner helps less")
	she.realm_index = 1
	she.spiritual_roots = {"fire": 90}
	assert_gt(Family.dual_multiplier(he, she, data()), base, "better roots help more")
	she.realm_index = 9
	var rules: Dictionary = data().family["dual_cultivation"]
	assert_almost_eq(Family.partner_factor(he, she, data()), float(rules["max_factor"]), 0.0001, "clamped")


func test_dual_cultivate_beats_solo_and_feeds_the_spouse() -> void:
	var pair := _couple()
	var solo := _couple()
	Family.marry(pair[0], pair[1], "wife")
	var result := Family.dual_cultivate(pair[0], pair[1], data(), 20)
	var alone := Cultivation.cultivate(solo[0], data(), 20)
	assert_true(result["ok"])
	assert_gt(float(result["qi_gained"]), float(alone["qi_gained"]))
	assert_gt(float(result["spouse_qi"]), 0.0)
	assert_eq(int(result["favor"]), int(data().family["dual_cultivation"]["favor_per_session"]))


func test_spouse_favor_grows_per_month_and_caps() -> void:
	var per_month := int(data().family["dual_cultivation"]["favor_per_month"])
	assert_eq(Family.spouse_favor_gain(data(), 0, 29), 0)
	assert_eq(Family.spouse_favor_gain(data(), 29, 31), per_month, "crossing a month boundary")
	assert_eq(Family.spouse_favor_gain(data(), 0, 90), 3 * per_month)
	var cap := int(data().family["dual_cultivation"]["max_favor"])
	assert_eq(Family.add_spouse_favor(data(), cap - 1, 10), cap)
	assert_eq(Family.add_spouse_favor(data(), cap + 5, 10), cap + 5, "never lowers favor")


func test_game_state_dual_cultivate() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Husband", gs.data, seeded_rng())
	c.gender = "male"
	c.spiritual_roots = {"fire": 60, "wood": 60}
	gs.start_session(c)
	var spouse: CharacterData = gs.npcs["xiao_ling"]
	spouse.spiritual_roots = {"water": 60}
	spouse.realm_index = 1
	spouse.stage = 0
	spouse.qi = 0.0
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.dual_cultivate("xiao_ling", 30)
	assert_eq(clock.total_days, days, "not married: refused")
	Family.marry(c, spouse, "wife")
	gs.npc_favor["xiao_ling"] = 60
	var qi_before: float = c.qi + 0.0
	var spouse_qi: float = spouse.qi + 0.0
	gs.current_region = Npcs.region_of(spouse, gs.data)
	gs.dual_cultivate("xiao_ling", 30)
	assert_gt(clock.total_days, days, "dual cultivation takes time")
	assert_true(c.qi != qi_before or c.stage > 0, "player gained qi")
	assert_true(spouse.qi != spouse_qi or spouse.stage > 0, "spouse gained qi")
	assert_gt(int(gs.npc_favor["xiao_ling"]), 60, "favor from the session and the month passing")
	gs.end_session()


func test_spouses_in_region_lists_living_local_spouses() -> void:
	var he := _person("male", "player")
	var here := _person("female", "gen_1")
	here.home_region = "village"
	var away := _person("female", "gen_2")
	away.home_region = "far_away"
	var gone := _person("female", "gen_3")
	gone.home_region = "village"
	gone.alive = false
	for s in [here, away, gone]:
		Family.marry(he, s, "concubine")
	var people := {here.id: here, away.id: away, gone.id: gone}
	var found := Family.spouses_in_region(he, people, data(), "village")
	assert_eq(found.size(), 1)
	assert_eq(found[0].id, "gen_1")


func test_meditation_spot_offers_dual_cultivation_with_local_spouse() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Husband", gs.data, seeded_rng())
	c.gender = "male"
	c.spiritual_roots = {"fire": 60}
	gs.start_session(c)
	var spot: Node = load("res://src/world/interactables/meditation_spot.gd").new()
	var spouse: CharacterData = gs.npcs["xiao_ling"]
	gs.current_region = Npcs.region_of(spouse, gs.data)
	var labels := func() -> Array: return spot.get_options().map(func(o): return o["label"])
	assert_false(str(labels.call()).contains("Dual cultivate"), "no spouse, no option")
	Family.marry(c, spouse, "wife")
	spouse.spiritual_roots = {"water": 60}
	var dual: Array = spot.get_options().filter(func(o): return String(o["label"]).begins_with("Dual cultivate"))
	assert_eq(dual.size(), 1)
	assert_true(String(dual[0]["label"]).contains("%"), dual[0]["label"])
	assert_false(dual[0]["disabled"])
	spouse.spiritual_roots = {}
	dual = spot.get_options().filter(func(o): return String(o["label"]).begins_with("Dual cultivate"))
	assert_true(dual[0]["disabled"], "rootless spouse: disabled with a reason")
	spot.free()
	gs.end_session()
