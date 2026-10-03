extends TestCase
## FAM-003d: NPC marriages and children off-screen (data/family.json "npc_families", NpcFamilies).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _single(npcs: Dictionary, gender: String, seed_value: int, region: String = "qingshi_village") -> CharacterData:
	return Npcs.spawn(npcs, data(), seeded_rng(seed_value), {"gender": gender, "age_years": 22, "region": region, "realm": "qi_refining"})


## Fresh data with npc_families overridden.
func _data_with(npc_rules: Dictionary) -> GameData:
	var d := GameData.load_from_dir()
	var r: Dictionary = d.family["npc_families"].duplicate()
	r.merge(npc_rules, true)
	d.family["npc_families"] = r
	return d


func test_data_is_valid() -> void:
	assert_true(NpcFamilies.validate(data()).is_empty(), str(NpcFamilies.validate(data())))
	var d := _data_with({"marriage_chance_per_year": 2.0, "attempt_chance_per_month": -1.0, "max_children": -1})
	assert_eq(NpcFamilies.validate(d).size(), 3)


func test_matching_rules() -> void:
	var npcs := {}
	var he := _single(npcs, "male", 1)
	var she := _single(npcs, "female", 2)
	var other_man := _single(npcs, "male", 3)
	assert_true(NpcFamilies.can_match(he, she, data(), {}))
	assert_false(NpcFamilies.can_match(he, other_man, data(), {}), "partner genders")
	assert_false(NpcFamilies.can_match(he, she, data(), {she.id: 10}), "reserved by the player")
	she.parents = ["gen_99"]
	he.parents = ["gen_99"]
	assert_false(NpcFamilies.can_match(he, she, data(), {}), "siblings")
	he.parents = []
	she.parents = [he.id]
	assert_false(NpcFamilies.can_match(he, she, data(), {}), "parent and child")
	she.parents = []
	she.age_days = 10 * Calendar.DAYS_PER_YEAR
	assert_false(NpcFamilies.can_match(he, she, data(), {}), "too young")
	assert_eq(NpcFamilies.marriage_rank(he, she, data()), "wife")
	assert_eq(NpcFamilies.marriage_rank(she, he, data()), "wife", "order does not matter")


func test_npcs_marry_within_their_region() -> void:
	var d := _data_with({"marriage_chance_per_year": 1.0, "attempt_chance_per_month": 0.0})
	var npcs := {}
	var he := _single(npcs, "male", 1)
	var she := _single(npcs, "female", 2)
	var far := _single(npcs, "female", 3, "azure_peak")
	var known := _single(npcs, "female", 4)
	var events := NpcFamilies.simulate(npcs, d, Calendar.DAYS_PER_YEAR, seeded_rng(), {known.id: 5})
	assert_true(Family.is_married_to(he, she), "the only match in the region")
	assert_eq(String(he.spouse_ranks[she.id]), "wife")
	assert_true(far.spouses.is_empty() and known.spouses.is_empty())
	assert_eq(events.filter(func(e): return e["kind"] == "marriage").size(), 1)


func test_couples_have_children_until_the_cap() -> void:
	var d := _data_with({"marriage_chance_per_year": 0.0, "attempt_chance_per_month": 1.0, "max_children": 2})
	var npcs := {}
	var he := _single(npcs, "male", 1)
	var she := _single(npcs, "female", 2)
	Family.marry(he, she, "wife")
	var events := NpcFamilies.simulate(npcs, d, Calendar.DAYS_PER_YEAR * 6, seeded_rng())
	assert_eq(she.children.size(), 2, "max_children per mother")
	var child: CharacterData = npcs[she.children[0]]
	assert_eq(child.parents, [she.id, he.id] as Array[String])
	assert_eq(child.surname, he.surname)
	assert_eq(child.home_region, "qingshi_village")
	assert_gt(child.age_days, 0, "born during the span, so already some days old")
	assert_eq(events.filter(func(e): return e["kind"] == "birth").size(), 2)
	var capped := _data_with({"marriage_chance_per_year": 0.0, "attempt_chance_per_month": 1.0, "population_cap": 2})
	var npcs2 := {}
	var a := _single(npcs2, "male", 1)
	var b := _single(npcs2, "female", 2)
	Family.marry(a, b, "wife")
	NpcFamilies.simulate(npcs2, capped, Calendar.DAYS_PER_YEAR * 3, seeded_rng())
	assert_true(b.children.is_empty() and not Children.is_pregnant(b), "population cap blocks conception")


func test_player_marriages_are_left_alone() -> void:
	var d := _data_with({"attempt_chance_per_month": 1.0})
	var npcs := {}
	var player := new_character()
	player.gender = "male"
	var wife := _single(npcs, "female", 2)
	Family.marry(player, wife, "wife")
	wife.pregnancy = {"partner": "player", "days_left": 10}
	NpcFamilies.simulate(npcs, d, Calendar.DAYS_PER_YEAR, seeded_rng())
	assert_eq(int(wife.pregnancy["days_left"]), 10, "GameState advances the player's pregnancies")
	assert_true(wife.children.is_empty())


func test_game_state_npcs_marry_and_candidates_refill() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var clock: Node = _root().get_node("GameClock")
	var favored: CharacterData = null
	for npc: CharacterData in gs.npcs.values():
		if Npcs.is_eligible(npc, gs.data) and npc.gender == "female":
			favored = npc
			break
	gs.npc_favor[favored.id] = 10
	clock.advance(Calendar.DAYS_PER_YEAR * 10)
	var married := 0
	for npc: CharacterData in gs.npcs.values():
		if npc.id.begins_with(Npcs.SPAWN_PREFIX) and not npc.spouses.is_empty():
			married += 1
	assert_gt(married, 0, "generated NPCs marry each other over a decade")
	assert_true(favored.spouses.is_empty(), "the player's acquaintances are not married off")
	var per_gender := int(gs.data.family["eligible_npcs"]["per_gender"])
	for region_id in gs.data.regions:
		var singles := 0
		for npc: CharacterData in Npcs.in_region(gs.npcs, gs.data, region_id):
			if Npcs.is_eligible(npc, gs.data) and npc.gender == "male":
				singles += 1
		assert_true(singles >= per_gender, "courtship candidates are topped up in %s" % region_id)
	gs.end_session()
