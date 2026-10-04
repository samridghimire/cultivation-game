extends TestCase
## FAM-009c: NPCs in sects (clan youths at founding, the player's children),
## NPC sect ranks, the sect cultivation bonus and the Look text.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_npc_rank_follows_realm() -> void:
	var foundation := data().realm_index_of("foundation_establishment")
	assert_eq(Sects.npc_rank(data(), "azure_cloud_sect", 0), 0)
	assert_eq(Sects.npc_rank(data(), "azure_cloud_sect", 1), 0, "ranks without a realm minimum need contribution")
	assert_eq(Sects.npc_rank(data(), "azure_cloud_sect", foundation), 2)
	assert_eq(Sects.npc_rank(data(), "azure_cloud_sect", data().realm_index_of("core_formation")), 3)
	assert_eq(Sects.npc_rank(data(), "nope", foundation), 0)
	var npc := new_character(3)
	npc.realm_index = 1
	npc.alignment = 100
	Sects.npc_join(npc, data(), "azure_cloud_sect")
	assert_eq(Sects.member_text(npc, data()), "an Outer Disciple of the Azure Cloud Sect")
	assert_true(Npcs.describe(npc, data()).contains(", an Outer Disciple of the Azure Cloud Sect"), Npcs.describe(npc, data()))
	assert_false(Sects.npc_promote(npc, data()))
	npc.realm_index = foundation
	assert_true(Sects.npc_promote(npc, data()))
	assert_eq(Sects.member_text(npc, data()), "a Core Disciple of the Azure Cloud Sect")
	assert_eq(Sects.member_text(new_character(), data()), "")


func test_accepting_sects_follow_alignment() -> void:
	var npc := new_character(4)
	npc.realm_index = 1
	npc.alignment = 300
	assert_eq(Sects.accepting_sects(npc, data()), ["azure_cloud_sect", "myriad_treasure_pavilion"] as Array[String])
	npc.alignment = -600
	assert_eq(Sects.accepting_sects(npc, data()), ["blood_lotus_sect"] as Array[String])


func test_sect_members_cultivate_faster() -> void:
	var rogue := new_character(5)
	rogue.age_days = 20 * Calendar.DAYS_PER_YEAR
	rogue.realm_index = 1
	rogue.alignment = 100
	rogue.cultivates = true
	rogue.diligence = 0.5
	var member := CharacterData.from_dict(rogue.to_dict())
	Sects.npc_join(member, data(), "azure_cloud_sect")
	var events: Array[Dictionary] = []
	Npcs._live(rogue, data(), 30, seeded_rng(), events)
	Npcs._live(member, data(), 30, seeded_rng(), events)
	assert_gt(member.qi, rogue.qi, "the sect's cultivation bonus applies to NPCs")


func test_clan_youths_join_sects_at_founding() -> void:
	var joined := 0
	for seed_value in 6:
		var npcs := {}
		var clans := {}
		NpcClans.ensure(clans, npcs, data(), seeded_rng(seed_value))
		for clan: ClanData in clans.values():
			var head: CharacterData = npcs[clan.head]
			assert_true(head.is_rogue(), "heads stay with their clan")
			for child_id in head.children:
				var child: CharacterData = npcs[child_id]
				if not child.is_rogue():
					joined += 1
					assert_true(Sects.check_join(_rogue_copy(child), data(), String(child.sect["id"]))["ok"], "only sects that accept them")
					assert_true(NpcClans.membership_text(clans, npcs, data(), child_id) != "", "still a clan member")
	assert_gt(joined, 0, "some clan youths are sent to sects")


func _rogue_copy(c: CharacterData) -> CharacterData:
	var copy := CharacterData.from_dict(c.to_dict())
	copy.sect = {}
	return copy


func test_send_child_rules() -> void:
	var me := new_character()
	var child := new_character(8)
	child.id = "kid"
	child.name = "Lin Bao"
	child.realm_index = 1
	child.alignment = 100
	child.age_days = 10 * Calendar.DAYS_PER_YEAR
	assert_true(Sects.check_send_child(me, child, data(), "azure_cloud_sect").begins_with("Only your own"))
	me.children.append(child.id)
	assert_true(Sects.check_send_child(me, child, data(), "azure_cloud_sect").contains("too young"))
	child.age_days = 14 * Calendar.DAYS_PER_YEAR
	assert_true(Sects.check_send_child(me, child, data(), "blood_lotus_sect").begins_with("Lin Bao: "), "the sect's own refusal")
	var result := Sects.send_child(me, child, data(), "azure_cloud_sect")
	assert_true(result["ok"], result["reason"])
	assert_eq(int(result["days"]), int(data().family["sect_entry"]["days"]))
	assert_eq(String(child.sect["id"]), "azure_cloud_sect")
	assert_true(Sects.check_send_child(me, child, data(), "myriad_treasure_pavilion").contains("already belongs"))
	var restored := CharacterData.from_dict(JSON.parse_string(JSON.stringify(child.to_dict())))
	assert_eq(String(restored.sect["id"]), "azure_cloud_sect", "NPC sects survive a save")


func test_game_state_send_and_recall_child() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var kid := Npcs.spawn(gs.npcs, gs.data, seeded_rng(5), {"age_years": 14, "region": gs.current_region, "realm": "qi_refining", "alignment": 100})
	c.children.append(kid.id)
	var clock: Node = _root().get_node("GameClock")
	var day: int = clock.total_days

	var screen := FamilyScreen.new()
	_root().add_child(screen)
	screen.open()
	screen._select(kid.id)
	var send := screen._sect_actions.get_node("Send_azure_cloud_sect") as Button
	assert_false(send.disabled, send.tooltip_text)
	assert_true((screen._sect_actions.get_node("Send_blood_lotus_sect") as Button).disabled)
	send.pressed.emit()
	assert_eq(String(kid.sect.get("id", "")), "azure_cloud_sect")
	assert_eq(clock.total_days, day + int(gs.data.family["sect_entry"]["days"]))
	assert_true(screen._info.text.contains("An Outer Disciple of the Azure Cloud Sect"), screen._info.text)
	var recall := screen._sect_actions.get_node("Recall") as Button
	recall.pressed.emit()
	assert_true(kid.is_rogue())
	assert_true(screen._sect_actions.get_node_or_null("Send_azure_cloud_sect") != null)
	screen.close()
	screen.free()

	gs.send_child_to_sect(kid.id, "blood_lotus_sect")
	assert_true(kid.is_rogue(), "refused by a demonic sect")
	gs.end_session()
