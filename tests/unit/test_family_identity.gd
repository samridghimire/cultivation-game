extends TestCase
## FAM-001: character identity, family links, names and generated NPCs.


func test_names_data_loaded() -> void:
	var genders := Names.genders(data())
	assert_true(genders.has("male") and genders.has("female"))
	assert_false(Names.is_gender(data(), "dragon"))
	var rng := seeded_rng()
	for g in genders:
		assert_true(Names.roll_given_name(data(), g, rng) != "")
	assert_true((data().names["surnames"] as Array).has(Names.roll_surname(data(), rng)))


func test_factory_splits_surname_and_keeps_gender() -> void:
	var c := CharacterFactory.create("Murong Xue", data(), seeded_rng(), "female")
	assert_eq(c.surname, "Murong")
	assert_eq(c.given_name, "Xue")
	assert_eq(c.name, "Murong Xue")
	assert_eq(c.gender, "female")
	var solo := CharacterFactory.create("Nameless", data(), seeded_rng(), "nonsense")
	assert_eq(solo.surname, "")
	assert_eq(solo.name, "Nameless")
	assert_true(Names.is_gender(data(), solo.gender), "an invalid gender is rolled instead")


func test_identity_round_trips_and_old_saves_default() -> void:
	var c := new_character()
	c.gender = "male"
	Names.apply(c, "Han", "Li")
	c.parents.append("gen_1")
	c.children.append("gen_2")
	c.spouses.append("xiao_ling")
	c.home_region = "qingshi_village"
	c.cultivates = true
	c.diligence = 0.5
	var back := CharacterData.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.surname, "Han")
	assert_eq(back.given_name, "Li")
	assert_eq(back.gender, "male")
	assert_eq(back.parents, c.parents)
	assert_eq(back.children, c.children)
	assert_eq(back.spouses, c.spouses)
	assert_eq(back.home_region, "qingshi_village")
	assert_true(back.cultivates)
	assert_almost_eq(back.diligence, 0.5)
	var old := CharacterData.from_dict({"id": "player", "name": "Old Save"})
	assert_eq(old.gender, "")
	assert_eq(old.spouses.size(), 0)
	assert_almost_eq(old.diligence, -1.0)


func test_named_npcs_copy_def_behavior() -> void:
	var npcs := {}
	Npcs.ensure_all(npcs, data(), seeded_rng())
	var ling: CharacterData = npcs["xiao_ling"]
	assert_eq(ling.gender, "female")
	assert_eq(ling.home_region, "qingshi_village")
	assert_true(ling.cultivates)
	assert_almost_eq(ling.diligence, 0.6)


func test_old_npc_saves_fall_back_to_def() -> void:
	# An NPC saved before FAM-001 has no behavior fields.
	var npcs := {"xiao_ling": CharacterData.from_dict({"id": "xiao_ling", "name": "Xiao Ling", "age_days": 16 * Calendar.DAYS_PER_YEAR, "spiritual_roots": {"fire": 81}})}
	var ling: CharacterData = npcs["xiao_ling"]
	assert_eq(Npcs.region_of(ling, data()), "qingshi_village")
	assert_true(Npcs.cultivates(ling, data()))
	assert_almost_eq(Npcs.diligence_of(ling, data()), 0.6)
	assert_true(Npcs.in_region(npcs, data(), "qingshi_village").has(ling))


func test_spawn_generates_unique_named_npcs() -> void:
	var npcs := {}
	Npcs.ensure_all(npcs, data(), seeded_rng())
	var rng := seeded_rng(7)
	var a := Npcs.spawn(npcs, data(), rng, {"region": "misty_forest", "gender": "female", "age_years": 20})
	var b := Npcs.spawn(npcs, data(), rng, {"surname": "Lin"})
	assert_true(a.id != b.id)
	assert_true(npcs.has(a.id) and npcs.has(b.id))
	assert_false(data().npcs.has(a.id))
	assert_eq(a.gender, "female")
	assert_eq(a.age_years(), 20)
	assert_eq(a.name, Names.full_name(a.surname, a.given_name))
	assert_true(a.given_name != "")
	assert_eq(b.surname, "Lin")
	assert_true(Names.is_gender(data(), b.gender))
	assert_eq(a.attributes.size(), data().attributes.size())
	assert_true(a.diligence >= Npcs.SPAWN_DILIGENCE_MIN and a.diligence <= Npcs.SPAWN_DILIGENCE_MAX)
	assert_true(Npcs.in_region(npcs, data(), "misty_forest").has(a))


func test_spawn_is_deterministic() -> void:
	var first := Npcs.spawn({}, data(), seeded_rng(99))
	var second := Npcs.spawn({}, data(), seeded_rng(99))
	assert_eq(first.to_dict(), second.to_dict())


func test_generated_npcs_live_without_def() -> void:
	var npcs := {}
	var npc := Npcs.spawn(npcs, data(), seeded_rng(), {"region": "qingshi_village", "roots": {"fire": 90}, "diligence": 0.6, "age_years": 16})
	Npcs.simulate(npcs, data(), Calendar.DAYS_PER_YEAR * 2, seeded_rng())
	assert_eq(npc.age_years(), 18)
	assert_gt(npc.realm_index, 0, "a diligent fire-root youth should reach Qi Refining in two years")
	var idle := Npcs.spawn(npcs, data(), seeded_rng(), {"cultivates": false, "roots": {"fire": 90}})
	Npcs.simulate(npcs, data(), Calendar.DAYS_PER_YEAR, seeded_rng())
	assert_almost_eq(idle.qi, 0.0)


func test_generated_npcs_survive_save_and_load() -> void:
	var gs: Node = (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
	var c := CharacterFactory.create("Bai Yue", gs.data, seeded_rng(), "female")
	gs.start_session(c)
	var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(), {"region": "qingshi_village"})
	c.spouses.append(npc.id)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	assert_eq(gs.player.surname, "Bai")
	assert_eq(gs.player.gender, "female")
	assert_eq(gs.player.spouses, [npc.id] as Array[String])
	var loaded: CharacterData = gs.npcs[npc.id]
	assert_eq(loaded.name, npc.name)
	assert_eq(loaded.home_region, "qingshi_village")
	assert_eq(Npcs.next_id(gs.npcs) == npc.id, false)
	gs.end_session()


func _person(id: String, gender: String, surname: String, given: String) -> CharacterData:
	var c := new_character()
	c.id = id
	c.gender = gender
	Names.apply(c, surname, given)
	return c


func test_describe_links_names_spouses_children_and_parents() -> void:
	var me := _person("player", "male", "Han", "Li")
	var wife := _person("gen_1", "female", "Lin", "Xue")
	var concubine := _person("gen_2", "female", "Su", "Mei")
	concubine.alive = false
	var son := _person("gen_3", "male", "Han", "Feng")
	var father := _person("gen_4", "male", "Han", "Tian")
	Family.marry(me, wife, "wife")
	Family.marry(me, concubine, "concubine")
	me.children.append(son.id)
	me.children.append("gen_99")
	me.parents.append(father.id)
	var people := {wife.id: wife, concubine.id: concubine, son.id: son, father.id: father}
	var lines := Family.describe_links(me, people, data())
	assert_eq(lines.size(), 5)
	assert_true(lines[0].begins_with("Wife: Lin Xue ("), lines[0])
	assert_true(lines[0].contains("age %d" % wife.age_years()), lines[0])
	assert_eq(lines[1], "Concubine: Su Mei (deceased)")
	assert_true(lines[2].begins_with("Son: Han Feng"), lines[2])
	assert_eq(lines[3], "Child: Unknown")
	assert_true(lines[4].begins_with("Father: Han Tian"), lines[4])
	assert_true(Family.describe_links(new_character(), {}, data()).is_empty())


func test_choose_gender_only_when_unknown() -> void:
	var c := new_character()
	c.gender = ""
	assert_eq(Names.check_choose_gender(c, data(), "female"), "")
	assert_true(Names.check_choose_gender(c, data(), "dragon") != "")
	c.gender = "male"
	assert_true(Names.check_choose_gender(c, data(), "female") != "")
