extends TestCase
## FAM-009: NPC clans from data/clans.json (founding families, succession, saves).


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func test_data_is_valid() -> void:
	assert_eq(NpcClans.validate(data()).size(), 0, str(NpcClans.validate(data())))
	assert_gt(NpcClans.clan_ids(data()).size(), 1)


func test_founding_spawns_a_family() -> void:
	var npcs := {}
	var clans := {}
	var founded := NpcClans.ensure(clans, npcs, data(), seeded_rng())
	assert_eq(founded, NpcClans.clan_ids(data()))
	var zhao: ClanData = clans["zhao_clan"]
	var def: Dictionary = data().npc_clans["zhao_clan"]
	assert_eq(zhao.name, "Zhao Clan")
	var head: CharacterData = npcs[zhao.head]
	assert_eq(head.surname, "Zhao")
	assert_eq(head.gender, "male")
	assert_eq(head.realm_index, data().realm_index_of("qi_refining"))
	assert_eq(zhao.members[head.id], Clans.head_rank(data()))
	assert_eq(head.spouses.size(), 1)
	assert_true(zhao.members.has(head.spouses[0]), "the spouse is a member")
	var count: Array = def["children"]["count"]
	assert_true(head.children.size() >= int(count[0]) and head.children.size() <= int(count[1]))
	for child_id in head.children:
		var child: CharacterData = npcs[child_id]
		assert_eq(child.surname, "Zhao")
		assert_eq(child.birth_rank, "wife")
		assert_true(child.parents.has(head.id))
		assert_true(zhao.members.has(child_id))
		assert_eq(Npcs.region_of(child, data()), "qingshi_village")
		assert_eq(NpcClans.clan_of(clans, child_id), "zhao_clan")
	assert_eq(NpcClans.ensure(clans, npcs, data(), seeded_rng()).size(), 0, "founded only once")
	var mo_head: CharacterData = npcs[(clans["mo_clan"] as ClanData).head]
	assert_eq(mo_head.gender, "female")
	assert_eq(mo_head.spouse_ranks.values(), ["dao_companion"], "a Matriarch has a Dao companion")


func test_succession_and_extinction() -> void:
	var npcs := {}
	var clans := {}
	NpcClans.ensure(clans, npcs, data(), seeded_rng(3))
	var clan: ClanData = clans["yun_clan"]
	var old_head: CharacterData = npcs[clan.head]
	assert_eq(NpcClans.simulate(clans, npcs, data()).size(), 0, "nothing happens while the head lives")
	var heir_id := Clans.heir(clan, old_head, npcs, data())
	assert_true(heir_id != "")
	old_head.alive = false
	var events := NpcClans.simulate(clans, npcs, data())
	assert_eq(events.size(), 1)
	assert_true(String(events[0]["text"]).contains("mourns"))
	assert_eq(clan.head, heir_id)
	assert_false(clan.members.has(old_head.id))
	for member_id in clan.members:
		(npcs[member_id] as CharacterData).alive = false
	events = NpcClans.simulate(clans, npcs, data())
	assert_true(String(events[0]["text"]).contains("ended"))
	assert_true(NpcClans.is_extinct(clan))
	assert_eq(NpcClans.simulate(clans, npcs, data()).size(), 0, "extinct clans stay quiet")


func test_new_descendants_join() -> void:
	var npcs := {}
	var clans := {}
	NpcClans.ensure(clans, npcs, data(), seeded_rng())
	var clan: ClanData = clans["zhao_clan"]
	var son: CharacterData = npcs[(npcs[clan.head] as CharacterData).children[0]]
	var grandchild := Npcs.spawn(npcs, data(), seeded_rng(9), {"age_years": 1})
	son.children.append(grandchild.id)
	NpcClans.simulate(clans, npcs, data())
	assert_true(clan.members.has(grandchild.id))


func test_save_round_trip() -> void:
	var npcs := {}
	var clans := {}
	NpcClans.ensure(clans, npcs, data(), seeded_rng())
	var copy := NpcClans.from_dict(JSON.parse_string(JSON.stringify(NpcClans.to_dict(clans))))
	assert_eq(copy.keys().size(), clans.keys().size())
	assert_eq((copy["mo_clan"] as ClanData).members, (clans["mo_clan"] as ClanData).members)


func test_game_state_npc_clans() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	assert_eq(gs.npc_clans.size(), NpcClans.clan_ids(gs.data).size())
	var zhao: ClanData = gs.npc_clans["zhao_clan"]
	assert_true(gs.npcs.has(zhao.head))
	var saved: Dictionary = gs.to_save_dict()
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq((gs.npc_clans["zhao_clan"] as ClanData).head, zhao.head, "clans survive a save")
	saved.erase("npc_clans")
	gs.load_save_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(gs.npc_clans.size(), NpcClans.clan_ids(gs.data).size(), "older saves gain the clans")
	var head: CharacterData = gs.npcs[(gs.npc_clans["yun_clan"] as ClanData).head]
	head.alive = false
	_root().get_node("GameClock").advance(1)
	assert_true((gs.npc_clans["yun_clan"] as ClanData).head != head.id, "succession runs as time passes")
	gs.end_session()
	assert_eq(gs.npc_clans.size(), 0)
