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


# --- Clashes (LW-002b) -------------------------------------------------------

func _clash_data(chance: float, casualties: int = 1) -> GameData:
	var d := GameData.load_from_dir()
	d.sect_factions["clash"] = {"monthly_chance": chance, "casualties": casualties}
	return d


func test_hostile_pairs_are_righteous_against_demonic() -> void:
	assert_eq(SectFactions.hostile_pairs(data()), [["azure_cloud_sect", "blood_lotus_sect"]], "neutral sects never clash")


func test_clash_kills_casualties_of_the_loser_only() -> void:
	var d := _clash_data(1.0, 2)
	var npcs := {}
	var azure: Array[CharacterData] = []
	var blood: Array[CharacterData] = []
	for i in 3:
		var a := _rogue(npcs, 100)
		Sects.npc_join(a, d, "azure_cloud_sect")
		azure.append(a)
		var b := _rogue(npcs, -600)
		Sects.npc_join(b, d, "blood_lotus_sect")
		blood.append(b)
	var events := SectFactions.clash(d, npcs, seeded_rng(3))
	assert_eq(events.size(), 1)
	var event: Dictionary = events[0]
	assert_eq(event["dead_ids"].size(), 2)
	var losers: Array[CharacterData] = azure if event["loser"] == "azure_cloud_sect" else blood
	var winners: Array[CharacterData] = blood if event["loser"] == "azure_cloud_sect" else azure
	assert_eq(losers.filter(func(c: CharacterData) -> bool: return not c.alive).size(), 2)
	assert_eq(winners.filter(func(c: CharacterData) -> bool: return not c.alive).size(), 0)
	assert_true(String(event["text"]).contains("lost 2 disciples"), event["text"])
	assert_true(losers.filter(func(c: CharacterData) -> bool: return not c.alive)[0].cause_of_death.begins_with("fell in battle against the"))


func test_clash_sect_without_members_always_loses() -> void:
	var d := _clash_data(1.0)
	var npcs := {}
	var demon := _rogue(npcs, -600)
	Sects.npc_join(demon, d, "blood_lotus_sect")
	for seed_value in 10:
		var events := SectFactions.clash(d, npcs, seeded_rng(seed_value))
		assert_eq(events.size(), 1)
		assert_eq(events[0]["winner"], "blood_lotus_sect")
		assert_eq(events[0]["dead_ids"].size(), 0, "nobody left to lose")
	assert_eq(SectFactions.clash(d, {}, seeded_rng()).size(), 0, "no clash when both are empty")


func test_clash_needs_chance() -> void:
	var d := _clash_data(0.0)
	var npcs := {}
	Sects.npc_join(_rogue(npcs, -600), d, "blood_lotus_sect")
	Sects.npc_join(_rogue(npcs, 100), d, "azure_cloud_sect")
	assert_eq(SectFactions.clash(d, npcs, seeded_rng()).size(), 0)


func test_clash_validation() -> void:
	var d := _clash_data(1.5, 0)
	assert_eq(SectFactions.validate(d).size(), 2, ", ".join(SectFactions.validate(d)))


func test_clear_flag_effect() -> void:
	var flags := {"a": true, "b": true}
	Effects.apply(new_character(), data(), {"clear_flag": "a"}, flags)
	assert_false(flags.has("a"))
	assert_true(flags.has("b"))


func test_flagged_missions_wait_for_their_flag() -> void:
	var c := new_character()
	c.realm_index = 1
	c.stage = 8
	Sects.join(c, data(), "azure_cloud_sect")
	assert_false(Sects.available_missions(c, data()).has("answer_azure_call"))
	assert_eq(Sects.check_mission(c, data(), "answer_azure_call"), "Your sect has no need of this now.")
	var flags := {"sect_call_azure_cloud_sect": true}
	assert_true(Sects.available_missions(c, data(), flags).has("answer_azure_call"))
	assert_eq(Sects.check_mission(c, data(), "answer_azure_call", flags), "")
	var blood := new_character()
	blood.realm_index = 1
	Sects.join(blood, data(), "blood_lotus_sect")
	assert_eq(Sects.check_mission(blood, data(), "answer_azure_call", flags), "Your sect does not offer that mission.")
	var result := Sects.complete_mission(c, data(), "answer_azure_call", flags)
	assert_true(result["ok"], str(result))
	assert_false(flags.has("sect_call_azure_cloud_sect"), "the call is answered")


func test_player_sect_clash_posts_a_call_in_a_session() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	c.realm_index = 1
	c.stage = 8
	gs.start_session(c)
	var old_rule: Dictionary = gs.data.sect_factions.get("clash", {})
	gs.data.sect_factions["clash"] = {"monthly_chance": 1.0, "casualties": 1}
	Sects.join(c, gs.data, "azure_cloud_sect")
	for sect_id in ["azure_cloud_sect", "blood_lotus_sect"]:
		var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"realm": "qi_refining", "alignment": 100 if sect_id == "azure_cloud_sect" else -600, "age_years": 20})
		Sects.npc_join(npc, gs.data, sect_id)
	gs._sect_factions_month()
	gs.data.sect_factions["clash"] = old_rule
	assert_true(gs.world_flags.get("sect_call_azure_cloud_sect", false))
	assert_true(Sects.available_missions(c, gs.data, gs.world_flags).has("answer_azure_call"))
	var result := Sects.complete_mission(c, gs.data, "answer_azure_call", gs.world_flags)
	assert_true(result["ok"], str(result))
	assert_false(gs.world_flags.has("sect_call_azure_cloud_sect"))
	gs.end_session()


func _call_session(stage: int) -> CharacterData:
	var gs := _root().get_node("GameState")
	var c := new_character()
	c.realm_index = 1
	c.stage = stage
	gs.start_session(c)
	Sects.join(c, gs.data, "azure_cloud_sect")
	var old_rule: Dictionary = gs.data.sect_factions.get("clash", {})
	gs.data.sect_factions["clash"] = {"monthly_chance": 1.0, "casualties": 1}
	for sect_id in ["azure_cloud_sect", "blood_lotus_sect"]:
		var npc := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"realm": "qi_refining", "alignment": 100 if sect_id == "azure_cloud_sect" else -600, "age_years": 20})
		Sects.npc_join(npc, gs.data, sect_id)
	gs._sect_factions_month()
	gs.data.sect_factions["clash"] = old_rule
	return c


func test_sect_call_expires_after_call_days() -> void:
	var gs := _root().get_node("GameState")
	var c := _call_session(8)
	var clock := gs.get_node("/root/GameClock")
	var start: int = int(gs.world_flags["sect_call_day_azure_cloud_sect"])
	assert_true(Sects.available_missions(c, gs.data, gs.world_flags).has("answer_azure_call"))
	clock.total_days = start + SectFactions.CALL_DAYS - 1
	gs._expire_world_events()
	assert_true(gs.world_flags.get("sect_call_azure_cloud_sect", false), "kept before the deadline")
	var rows := Guidance.journal(c, gs.data, gs.world_flags, clock.total_days, c.home_region)
	assert_true(rows.any(func(r: Dictionary) -> bool: return r["text"] == "The sect's call: 1 days left" and r["tone"] == "warning"))
	clock.total_days = start + SectFactions.CALL_DAYS + 1
	gs._expire_world_events()
	assert_false(gs.world_flags.has("sect_call_azure_cloud_sect"))
	assert_false(gs.world_flags.has("sect_call_day_azure_cloud_sect"))
	gs.end_session()


func test_sect_call_for_a_junior_disciple_names_the_seniors() -> void:
	var gs := _root().get_node("GameState")
	var c := _call_session(0)
	assert_true(gs.world_flags.get("sect_call_azure_cloud_sect", false))
	assert_true(Sects.check_mission(c, gs.data, "answer_azure_call", gs.world_flags) != "")
	gs.end_session()


func test_sect_call_without_day_key_starts_counting() -> void:
	var gs := _root().get_node("GameState")
	var c := new_character()
	gs.start_session(c)
	gs.world_flags["sect_call_azure_cloud_sect"] = true
	gs._expire_world_events()
	assert_true(gs.world_flags.has("sect_call_day_azure_cloud_sect"))
	gs.world_flags.erase("sect_call_azure_cloud_sect")
	gs._expire_world_events()
	assert_false(gs.world_flags.has("sect_call_day_azure_cloud_sect"))
	gs.end_session()
