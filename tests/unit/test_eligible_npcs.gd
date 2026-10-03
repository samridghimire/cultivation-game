extends TestCase
## FAM-002c: eligible generated NPCs per region (Npcs.ensure_eligible) and the proud flag.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_every_region_gets_candidates_of_each_gender() -> void:
	var npcs := {}
	var spawned := Npcs.ensure_eligible(npcs, data(), seeded_rng())
	var rules: Dictionary = data().family["eligible_npcs"]
	var per_gender := int(rules["per_gender"])
	assert_eq(spawned.size(), data().regions.size() * Names.genders(data()).size() * per_gender)
	for region_id in data().regions:
		for gender in Names.genders(data()):
			var count := 0
			for c: CharacterData in npcs.values():
				if Npcs.region_of(c, data()) == region_id and c.gender == gender:
					count += 1
					assert_true(Npcs.is_eligible(c, data()), "adult and unmarried")
					assert_true(c.age_years() >= int(rules["age_min"]) and c.age_years() <= int(rules["age_max"]), "age range")
			assert_eq(count, per_gender, "%s %s" % [region_id, gender])


func test_realms_follow_region_danger() -> void:
	var npcs := {}
	Npcs.ensure_eligible(npcs, data(), seeded_rng(7))
	var by_danger: Array = data().family["eligible_npcs"]["realms_by_danger"]
	for c: CharacterData in npcs.values():
		var danger := clampi(int(data().regions[c.home_region].get("danger", 0)), 0, by_danger.size() - 1)
		assert_true((by_danger[danger] as Array).has(data().realms[c.realm_index].id), "%s realm from danger %d" % [c.id, danger])


func test_top_up_replaces_married_and_dead_candidates_only() -> void:
	var npcs := {}
	var rng := seeded_rng()
	Npcs.ensure_eligible(npcs, data(), rng)
	var total := npcs.size()
	assert_eq(Npcs.ensure_eligible(npcs, data(), rng).size(), 0, "already full")
	var first: CharacterData = npcs.values()[0]
	first.spouses.append("player")
	var second: CharacterData = npcs.values()[1]
	second.alive = false
	assert_eq(Npcs.ensure_eligible(npcs, data(), rng).size(), 2)
	assert_eq(npcs.size(), total + 2)


func test_proud_npcs_refuse_concubinage_and_save() -> void:
	var npcs := {}
	var rng := seeded_rng()
	var she := Npcs.spawn(npcs, data(), rng, {"gender": "female", "age_years": 20, "realm": "qi_refining", "proud": true})
	var he := new_character()
	he.gender = "male"
	he.age_days = 20 * Calendar.DAYS_PER_YEAR
	he.realm_index = she.realm_index
	he.alignment = she.alignment
	assert_true(Npcs.is_proud(she, data()))
	assert_true(Family.check_proposal(he, she, 100, "concubine", data()).contains("proud"))
	assert_eq(Family.check_proposal(he, she, 100, "wife", data()), "")
	assert_true(CharacterData.from_dict(JSON.parse_string(JSON.stringify(she.to_dict()))).proud, "saved")
	assert_false(CharacterData.from_dict({}).proud, "old saves default to not proud")


func test_family_validates_eligible_npcs() -> void:
	var d := GameData.new()
	d.names = data().names
	d.realms = data().realms
	d.family = data().family.duplicate(true)
	assert_eq(Family.validate(d).size(), 0)
	d.family["eligible_npcs"]["realms_by_danger"] = [["no_such_realm"]]
	d.family["eligible_npcs"]["age_min"] = 5
	assert_eq(Family.validate(d).size(), 2)


func test_session_start_and_load_spawn_candidates() -> void:
	var gs: Node = _root().get_node("GameState")
	gs.start_session(CharacterFactory.create("Seeker", gs.data, seeded_rng()))
	var generated := 0
	for npc_id: String in gs.npcs:
		if npc_id.begins_with(Npcs.SPAWN_PREFIX):
			generated += 1
	assert_gt(generated, 0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	var after := 0
	for npc_id: String in gs.npcs:
		if npc_id.begins_with(Npcs.SPAWN_PREFIX):
			after += 1
	assert_eq(after, generated, "loading keeps the same candidates")
	gs.end_session()
