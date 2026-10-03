extends TestCase
## FAM-003b: adopting orphans and foundlings (data/family.json "adoption", Adoption).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _adult(gender: String = "female") -> CharacterData:
	var c := new_character()
	c.gender = gender
	c.surname = "Mei"
	c.age_days = 25 * Calendar.DAYS_PER_YEAR
	return c


func _orphan(npcs: Dictionary, age: int = 5) -> CharacterData:
	var child := Npcs.spawn(npcs, data(), seeded_rng(), {"age_years": age, "region": "qingshi_village"})
	child.birth_rank = "wife"
	return child


func test_only_orphans_young_enough_can_be_adopted() -> void:
	var npcs := {}
	var c := _adult()
	var child := _orphan(npcs)
	assert_eq(Adoption.check_adoption(c, child, npcs, data()), "", "no parents at all = orphan")
	var mother := Npcs.spawn(npcs, data(), seeded_rng(2), {"gender": "female"})
	child.parents = [mother.id]
	assert_true(Adoption.check_adoption(c, child, npcs, data()).contains("family"), "living parent")
	mother.alive = false
	assert_eq(Adoption.check_adoption(c, child, npcs, data()), "", "late parents")
	child.age_days = (int(Adoption.rules(data())["max_age"]) + 1) * Calendar.DAYS_PER_YEAR
	assert_true(Adoption.check_adoption(c, child, npcs, data()).contains("too old"))
	child.age_days = 0
	c.age_days = 10 * Calendar.DAYS_PER_YEAR
	assert_true(Adoption.check_adoption(c, child, npcs, data()).contains("too young"), "child adopter")
	assert_true(Adoption.check_adoption(c, null, npcs, data()) != "")


func test_adoption_links_family_and_shifts_alignment() -> void:
	var npcs := {}
	var c := _adult()
	var dead_father := Npcs.spawn(npcs, data(), seeded_rng(2), {"gender": "male"})
	dead_father.alive = false
	var child := _orphan(npcs)
	child.parents = [dead_father.id]
	var before := c.alignment
	var result := Adoption.adopt(c, child, npcs, data())
	assert_true(result["ok"], result["reason"])
	var r := Adoption.rules(data())
	assert_eq(result["days"], int(r["days"]))
	assert_eq(result["favor"], int(r["favor"]))
	assert_eq(c.alignment, before + int(r["alignment"]))
	assert_true(c.children.has(child.id))
	assert_eq(child.parents, [dead_father.id, c.id] as Array[String], "birth parent kept, adopter added")
	assert_true(Adoption.is_adopted(child))
	assert_eq(child.surname, "Mei", "takes the adopter's surname")
	assert_eq(child.name, Names.full_name("Mei", child.given_name))
	assert_eq(Adoption.adopted_count(c, npcs), 1)
	assert_true(Adoption.check_adoption(c, child, npcs, data()).contains("already"), "no double adoption")
	assert_false(Adoption.adopt(c, child, npcs, data())["ok"])


func test_adoption_limit() -> void:
	var npcs := {}
	var c := _adult()
	for i in int(Adoption.rules(data())["max_adopted"]):
		assert_true(Adoption.adopt(c, _orphan(npcs), npcs, data())["ok"])
	assert_true(Adoption.check_adoption(c, _orphan(npcs), npcs, data()).contains("more"))


func test_foundling_costs_a_donation() -> void:
	var npcs := {}
	var c := _adult("male")
	c.inventory.erase("spirit_stone")
	var donation := Adoption.foundling_donation(data())
	assert_gt(donation, 0)
	var refused := Adoption.adopt_foundling(c, npcs, data(), seeded_rng(), "qingshi_village")
	assert_false(refused["ok"])
	assert_true(npcs.is_empty(), "no child spawned when refused")
	c.add_item("spirit_stone", donation + 5)
	var result := Adoption.adopt_foundling(c, npcs, data(), seeded_rng(), "qingshi_village")
	assert_true(result["ok"], result["reason"])
	assert_eq(c.item_count("spirit_stone"), 5)
	var child: CharacterData = result["child"]
	assert_true(npcs.has(child.id))
	assert_eq(child.home_region, "qingshi_village")
	assert_true(child.age_years() <= int(Adoption.rules(data())["foundling_age_max"]))
	assert_eq(child.parents, [c.id] as Array[String])
	assert_true(c.children.has(child.id) and Adoption.is_adopted(child))


func test_validation_flags_bad_rules() -> void:
	var d := GameData.load_from_dir()
	assert_true(Adoption.validate(d).is_empty(), str(Adoption.validate(d)))
	d.family["adoption"] = {"days": 0, "max_adopted": 0, "max_age": 30, "foundling_age_min": 5, "foundling_age_max": 2}
	assert_eq(Adoption.validate(d).size(), 4)


func test_game_state_adopt_and_foundling() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Su Yan", gs.data, seeded_rng(), "female")
	gs.start_session(c)
	var clock: Node = _root().get_node("GameClock")
	var orphan := Npcs.spawn(gs.npcs, gs.data, seeded_rng(4), {"age_years": 4, "region": "qingshi_village"})
	gs.current_region = "misty_forest"
	var days: int = clock.total_days
	gs.adopt(orphan.id)
	assert_true(c.children.is_empty(), "the child is elsewhere")
	gs.current_region = "qingshi_village"
	gs.adopt(orphan.id)
	assert_true(c.children.has(orphan.id))
	assert_eq(clock.total_days, days + int(Adoption.rules(gs.data)["days"]))
	assert_eq(int(gs.npc_favor[orphan.id]), int(Adoption.rules(gs.data)["favor"]))
	c.add_item("spirit_stone", Adoption.foundling_donation(gs.data))
	gs.adopt_foundling()
	assert_eq(c.children.size(), 2)
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.player.children.size(), 2)
	var foundling: CharacterData = gs.npcs[gs.player.children[1]]
	assert_true(Adoption.is_adopted(foundling), "adopted status survives a save")
	assert_true(foundling.parents.has(gs.player.id))
	gs.end_session()
