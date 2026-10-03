extends TestCase
## FAM-003: pregnancy, birth and inheritance (data/family.json "children", Children).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _person(gender: String, id: String, age: int = 20) -> CharacterData:
	var c := new_character()
	c.id = id
	c.name = id
	c.gender = gender
	c.age_days = age * Calendar.DAYS_PER_YEAR
	return c


func _couple() -> Array[CharacterData]:
	var he := _person("male", "player")
	he.surname = "Lin"
	var she := _person("female", "npc_a")
	Family.marry(he, she, "wife")
	return [he, she]


func test_conception_needs_a_married_fertile_couple() -> void:
	var he := _person("male", "player")
	var she := _person("female", "npc_a")
	assert_true(Children.check_conception(he, she, data()) != "", "not married")
	Family.marry(he, she, "wife")
	assert_eq(Children.check_conception(he, she, data()), "")
	assert_eq(Children.carrier_of(he, she, data()), she)
	assert_eq(Children.carrier_of(she, he, data()), she, "order does not matter")
	she.pregnancy = {"partner": "player", "days_left": 10}
	assert_true(Children.check_conception(he, she, data()).contains("already"), "already pregnant")
	she.pregnancy = {}
	she.age_days = 60 * Calendar.DAYS_PER_YEAR
	assert_true(Children.check_conception(he, she, data()) != "", "old mortal carrier")
	she.realm_index = 1
	assert_eq(Children.check_conception(he, she, data()), "", "cultivators stay fertile")
	var other := _person("male", "npc_b")
	Family.marry(he, other, "wife")
	assert_eq(Children.carrier_of(he, other, data()), null)
	assert_true(Children.check_conception(he, other, data()).contains("adopt"))


func test_conception_starts_the_carriers_pregnancy() -> void:
	var pair := _couple()
	var rng := seeded_rng(7)
	var conceived := false
	for i in 50:
		var result := Children.try_conceive(pair[0], pair[1], data(), rng)
		assert_true(result["ok"])
		assert_eq(result["days"], int(Children.rules(data())["conception_days"]))
		if result["conceived"]:
			conceived = true
			break
	assert_true(conceived, "35% chance should succeed within 50 tries")
	assert_false(Children.is_pregnant(pair[0]))
	assert_eq(pair[1].pregnancy["partner"], "player")
	assert_eq(pair[1].pregnancy["days_left"], int(Children.rules(data())["pregnancy_days"]))


func test_pregnancy_counts_down_to_birth() -> void:
	var she := _person("female", "npc_a")
	assert_false(Children.advance_pregnancy(she, 30), "not pregnant")
	she.pregnancy = {"partner": "player", "days_left": 60}
	assert_false(Children.advance_pregnancy(she, 30))
	assert_true(Children.advance_pregnancy(she, 30))


func test_birth_links_the_family_and_records_rank() -> void:
	var pair := _couple()
	var npcs := {"npc_a": pair[1]}
	pair[1].pregnancy = {"partner": "player", "days_left": 0}
	var child := Children.give_birth(pair[1], pair[0], npcs, data(), seeded_rng(), "qingshi_village")
	assert_true(npcs.has(child.id))
	assert_eq(child.age_days, 0)
	assert_eq(child.surname, "Lin", "father's surname")
	assert_eq(child.parents, ["npc_a", "player"] as Array[String])
	assert_true(pair[0].children.has(child.id) and pair[1].children.has(child.id))
	assert_eq(child.birth_rank, "wife")
	assert_eq(child.home_region, "qingshi_village")
	assert_false(Children.is_pregnant(pair[1]))
	assert_false(Children.can_cultivate_yet(child, data()), "too young to cultivate")
	child.age_days = Children.cultivation_start_age(data()) * Calendar.DAYS_PER_YEAR
	assert_true(Children.can_cultivate_yet(child, data()))


func test_roots_mostly_follow_the_parents() -> void:
	var pair := _couple()
	pair[0].spiritual_roots = {"fire": 80, "wood": 70}
	pair[1].spiritual_roots = {"water": 60, "fire": 40}
	var rng := seeded_rng(99)
	var inherited := 0
	var lives := 400
	for i in lives:
		var roots := Children.inherit_roots(pair[1], pair[0], data(), rng)
		assert_true(roots.size() <= 5)
		for element in roots:
			assert_true(int(roots[element]) >= data().root_purity_min and int(roots[element]) <= data().root_purity_max)
		if roots.size() == 2 and roots.keys().all(func(e): return ["fire", "wood", "water"].has(e)):
			inherited += 1
	assert_gt(inherited, lives / 2, "most children carry two of their parents' elements")


func test_rootless_parents_rarely_have_a_genius() -> void:
	var pair := _couple()
	pair[0].spiritual_roots = {}
	pair[1].spiritual_roots = {}
	var rng := seeded_rng(3)
	var rooted := 0
	var geniuses := 0
	for i in 2000:
		var roots := Children.inherit_roots(pair[1], pair[0], data(), rng)
		if not roots.is_empty():
			rooted += 1
		if roots.size() == 1 and int(roots.values()[0]) >= int(Children.rules(data())["genius_purity_min"]):
			geniuses += 1
	assert_gt(geniuses, 0, "a genius can still be born")
	assert_true(rooted < 400, "but most children of rootless parents are rootless (%d/2000 rooted)" % rooted)


func test_attributes_average_the_parents() -> void:
	var pair := _couple()
	for attr in data().attributes:
		pair[0].attributes[attr["id"]] = 14
		pair[1].attributes[attr["id"]] = 10
	var variance := int(Children.rules(data())["attribute_variance"])
	var attrs := Children.inherit_attributes(pair[1], pair[0], data(), seeded_rng())
	for attr_id in attrs:
		assert_true(absi(int(attrs[attr_id]) - 12) <= variance, "%s near the parents' average" % attr_id)


func test_pregnancy_and_birth_rank_round_trip_in_saves() -> void:
	var she := _person("female", "npc_a")
	she.pregnancy = {"partner": "player", "days_left": 42}
	she.birth_rank = "concubine"
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(she.to_dict())))
	assert_eq(back.pregnancy["days_left"], 42)
	assert_eq(back.pregnancy["partner"], "player")
	assert_eq(back.birth_rank, "concubine")
	var old := CharacterData.from_dict({"id": "x"})
	assert_false(Children.is_pregnant(old), "old saves have no pregnancy")


func test_young_children_do_not_cultivate() -> void:
	var npcs := {}
	var child := Npcs.spawn(npcs, data(), seeded_rng(), {"age_years": 0, "roots": {"fire": 90}, "diligence": 1.0})
	child.age_days = 0
	Npcs.simulate(npcs, data(), Calendar.DAYS_PER_YEAR, seeded_rng())
	assert_eq(child.qi, 0.0)
	assert_eq(child.age_years(), 1)


func test_game_state_try_for_child_and_birth() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var wife: CharacterData = gs.npcs["xiao_ling"]
	var clock: Node = _root().get_node("GameClock")
	var days: int = clock.total_days
	gs.try_for_child("xiao_ling")
	assert_eq(clock.total_days, days, "not married: refused")
	Family.marry(c, wife, "wife")
	gs.current_region = Npcs.region_of(wife, gs.data)
	for i in 60:
		if Children.is_pregnant(wife):
			break
		gs.try_for_child("xiao_ling")
	assert_true(Children.is_pregnant(wife), "conceived within 60 tries")
	assert_gt(clock.total_days, days, "trying takes time")
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	wife = gs.npcs["xiao_ling"]
	assert_true(Children.is_pregnant(wife), "pregnancy survives a save")
	gs.try_for_child("xiao_ling")
	assert_true(gs.player.children.is_empty(), "can't conceive again while pregnant")
	clock.advance(int(Children.rules(gs.data)["pregnancy_days"]))
	assert_eq(gs.player.children.size(), 1, "born when the pregnancy is due")
	var child: CharacterData = gs.npcs[gs.player.children[0]]
	assert_eq(child.surname, "Lin")
	assert_eq(child.birth_rank, "wife")
	assert_true(wife.children.has(child.id))
	assert_false(Children.is_pregnant(wife))
	gs.end_session()
