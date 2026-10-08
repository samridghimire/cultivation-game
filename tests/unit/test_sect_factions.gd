extends TestCase
## LW-002: NPC sects as living factions (SectFactions): strength, monthly
## recruitment of rogue NPCs, standings, rumors and the GameState hook.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _rogue(npcs: Dictionary, alignment: int, realm: String = "qi_refining", age: int = 20) -> CharacterData:
	return Npcs.spawn(npcs, data(), seeded_rng(npcs.size() + 1), {"realm": realm, "alignment": alignment, "age_years": age})


func test_real_data_is_valid() -> void:
	assert_eq(SectFactions.validate(data()).size(), 0, ", ".join(SectFactions.validate(data())))
	assert_false(data().sect_factions.is_empty())


func test_validation_catches_bad_rules() -> void:
	var d := GameData.load_from_dir()
	d.sect_factions = {"strength_base": 0, "recruit": {"monthly_chance": 1.5, "min_age_years": 50, "max_age_years": 20}}
	assert_eq(SectFactions.validate(d).size(), 3, ", ".join(SectFactions.validate(d)))


func test_strength_sums_living_member_realms() -> void:
	var d := data()
	var npcs := {}
	assert_eq(SectFactions.strength(d, npcs, "azure_cloud_sect"), 0)
	var a := _rogue(npcs, 100)
	var b := _rogue(npcs, 100, "foundation_establishment")
	var dead := _rogue(npcs, 100)
	_rogue(npcs, 100)  # stays rogue
	for c in [a, b, dead]:
		Sects.npc_join(c, d, "azure_cloud_sect")
	dead.alive = false
	var base := int(d.sect_factions["strength_base"])
	assert_eq(SectFactions.realm_weight(d, 0), 1)
	assert_eq(SectFactions.realm_weight(d, 2), base * base)
	assert_eq(SectFactions.members(npcs, "azure_cloud_sect").size(), 2, "the dead and rogues do not count")
	assert_eq(SectFactions.strength(d, npcs, "azure_cloud_sect"), base + base * base)
	b.realm_index += 1
	assert_eq(SectFactions.strength(d, npcs, "azure_cloud_sect"), base + base * base * base, "strength grows with breakthroughs")


func test_standings_rank_strongest_first() -> void:
	var d := data()
	var npcs := {}
	var demon := _rogue(npcs, -600, "foundation_establishment")
	Sects.npc_join(demon, d, "blood_lotus_sect")
	var righteous := _rogue(npcs, 100)
	Sects.npc_join(righteous, d, "azure_cloud_sect")
	var ranked := SectFactions.standings(d, npcs)
	assert_eq(ranked.size(), d.sects.size())
	assert_eq(ranked[0]["id"], "blood_lotus_sect")
	assert_eq(ranked[1]["id"], "azure_cloud_sect")
	assert_eq(ranked[2]["strength"], 0)
	var lines := SectFactions.rumors(d, npcs)
	assert_true(lines[0].contains("Blood Lotus Sect is the mightiest"), str(lines))
	assert_true(lines[1].contains("Myriad Treasure Pavilion has fallen far behind"), str(lines))
	assert_eq(SectFactions.rumors(d, {}).size(), 0, "no gossip without members")


func test_recruit_takes_only_eligible_rogues_the_sect_accepts() -> void:
	var d := GameData.load_from_dir()
	d.sect_factions = {"strength_base": 3, "recruit": {"monthly_chance": 1.0, "min_age_years": 16, "max_age_years": 40}}
	var npcs := {}
	var demon := _rogue(npcs, -600)
	var too_old := _rogue(npcs, 100, "qi_refining", 60)
	var reserved_one := _rogue(npcs, 100)
	var idle := _rogue(npcs, 100)
	idle.cultivates = false
	var named := Npcs.create({"id": "elder_test", "realm": "qi_refining", "alignment": 100, "age_years": 20, "cultivates": true}, d, seeded_rng())
	npcs[named.id] = named
	var events := SectFactions.recruit(d, npcs, seeded_rng(), {reserved_one.id: true})
	assert_eq(events.size(), 1, str(events))
	assert_eq(events[0]["npc_id"], demon.id)
	assert_eq(events[0]["sect_id"], "blood_lotus_sect", "only the demonic sect accepts a demonic rogue")
	assert_eq(String(demon.sect["id"]), "blood_lotus_sect")
	assert_true(String(events[0]["text"]).contains("has joined the Blood Lotus Sect as a Blood Servant"), events[0]["text"])
	for c in [too_old, reserved_one, idle, named]:
		assert_true(c.is_rogue(), c.id)
	assert_eq(SectFactions.recruit(d, npcs, seeded_rng(), {reserved_one.id: true}).size(), 0, "members are not recruited twice")
	d.sect_factions["recruit"]["monthly_chance"] = 0.0
	var fresh := _rogue(npcs, -600)
	assert_eq(SectFactions.recruit(d, npcs, seeded_rng(), {}).size(), 0)
	assert_true(fresh.is_rogue())


func test_sects_grow_over_years_in_a_session() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	var child := Npcs.spawn(gs.npcs, gs.data, seeded_rng(7), {"realm": "qi_refining", "alignment": 100, "age_years": 20})
	c.children.append(child.id)
	var before := 0
	for row: Dictionary in gs.sect_standings():
		before += int(row["members"])
	for i in 24:
		gs.cultivate(Calendar.DAYS_PER_MONTH)
	var after := 0
	for row: Dictionary in gs.sect_standings():
		after += int(row["members"])
	assert_gt(after, before, "sects recruited rogue NPCs over two years")
	assert_true(child.is_rogue(), "the player's own children are never recruited")
	var bus := _root().get_node("EventBus")
	var posted: Array = []
	var cb := func(text: String, _category: String) -> void: posted.append(text)
	bus.message_posted.connect(cb)
	gs.hear_rumors()
	bus.message_posted.disconnect(cb)
	assert_true(posted.any(func(t: String) -> bool: return t.contains("mightiest sect")), str(posted))
	gs.end_session()
