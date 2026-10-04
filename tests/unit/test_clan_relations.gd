extends TestCase
## FAM-009b: NPC clan relations (toward the player and each other), deeds
## against members, feuds, favor scaling and marriage alliances.


func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


func _clans(npcs: Dictionary) -> Dictionary:
	var clans := {}
	NpcClans.ensure(clans, npcs, data(), seeded_rng())
	return clans


## A living non-head member of `clan`.
func _child_of(clan: ClanData) -> String:
	for member_id: String in clan.members:
		if member_id != clan.head and String(clan.members[member_id]) != "":
			return member_id
	return ""


func test_relations_data_is_valid() -> void:
	assert_eq(NpcClans._validate_relations(data()).size(), 0, str(NpcClans._validate_relations(data())))


func test_start_relations_and_standings() -> void:
	var clans := _clans({})
	assert_eq(NpcClans.relation(clans, data(), "zhao_clan", "mo_clan"), -30)
	assert_eq(NpcClans.relation(clans, data(), "mo_clan", "zhao_clan"), -30, "both ways")
	assert_eq(NpcClans.relation(clans, data(), "zhao_clan", NpcClans.PLAYER), 0)
	assert_eq(NpcClans.standing_name(data(), 0), "Neutral")
	assert_eq(NpcClans.standing_name(data(), -45), "Hostile")
	assert_eq(NpcClans.standing_name(data(), -100), "Blood feud")
	assert_eq(NpcClans.standing_name(data(), 60), "Honored")
	assert_eq(NpcClans.change_relation(clans, data(), "zhao_clan", NpcClans.PLAYER, 500), 100, "clamped to max")
	assert_eq(NpcClans.change_relation(clans, data(), "zhao_clan", NpcClans.PLAYER, -500), -100, "clamped to min")
	assert_true(NpcClans.rivalry_lines(clans, data()).has("The Mo Clan and the Yun Clan are Hostile."), str(NpcClans.rivalry_lines(clans, data())))


func test_deeds_shift_relations_and_killing_starts_a_feud() -> void:
	var npcs := {}
	var clans := _clans(npcs)
	var me := new_character()
	var zhao: ClanData = clans["zhao_clan"]
	var victim_id := _child_of(zhao)
	assert_eq(NpcClans.on_deed(clans, npcs, data(), me, "stranger", "kill"), {}, "non-members do not count")
	var gift := NpcClans.on_deed(clans, npcs, data(), me, victim_id, "gift")
	assert_eq(int(gift["change"]), 2)
	assert_false(gift["standing_changed"])
	(npcs[victim_id] as CharacterData).alive = false
	var kill := NpcClans.on_deed(clans, npcs, data(), me, victim_id, "kill")
	assert_eq(int(kill["value"]), -58)
	assert_eq(NpcClans.standing_name(data(), int(kill["value"])), "Hostile")
	assert_eq(int(kill["feud"]), 0)
	var rob := NpcClans.on_deed(clans, npcs, data(), me, zhao.head, "rob")
	assert_eq(NpcClans.standing_name(data(), int(rob["value"])), "Blood feud")
	assert_eq(int(rob["feud"]), zhao.members.size() - 1, "every living member swears the feud")
	assert_eq(Karma.grudge(me, victim_id), 0, "the dead hold no grudge")
	for member_id: String in zhao.members:
		if member_id != victim_id:
			assert_true(Karma.grudge(me, member_id) >= 30, "%s holds a grudge" % member_id)


func test_favor_scales_with_standing() -> void:
	var npcs := {}
	var clans := _clans(npcs)
	var member_id := (clans["zhao_clan"] as ClanData).head
	assert_eq(NpcClans.scaled_favor(clans, data(), member_id, 10, 50), 10, "Neutral")
	assert_eq(NpcClans.scaled_favor(clans, data(), "stranger", 10, 50), 10)
	NpcClans.change_relation(clans, data(), "zhao_clan", NpcClans.PLAYER, -45)
	assert_eq(NpcClans.scaled_favor(clans, data(), member_id, 10, 50), 5, "Hostile halves favor")
	NpcClans.change_relation(clans, data(), "zhao_clan", NpcClans.PLAYER, 105)
	assert_eq(NpcClans.scaled_favor(clans, data(), member_id, 10, 50), 15, "Honored")
	assert_eq(NpcClans.scaled_favor(clans, data(), member_id, 10, 12), 12, "never past the cap")
	assert_eq(NpcClans.scaled_favor(clans, data(), member_id, 10, 4), 10, "the base gain is kept")


func test_marriage_alliances() -> void:
	var npcs := {}
	var clans := _clans(npcs)
	var me := new_character()
	me.gender = "male"
	var zhao: ClanData = clans["zhao_clan"]
	var mo: ClanData = clans["mo_clan"]
	assert_eq(NpcClans.sync_alliances(clans, npcs, data(), me, null).size(), 0, "no marriages yet")
	var bride: CharacterData = npcs[_child_of(zhao)]
	Family.marry(me, bride, "wife")
	var events := NpcClans.sync_alliances(clans, npcs, data(), me, null)
	assert_eq(events.size(), 1)
	assert_true(String(events[0]["text"]).contains("binds the Zhao Clan to your family"), events[0]["text"])
	assert_true(zhao.allies.has(NpcClans.PLAYER))
	assert_eq(NpcClans.relation(clans, data(), "zhao_clan", NpcClans.PLAYER), 30)
	assert_eq(NpcClans.standing_text(clans, data(), "zhao_clan"), "Friendly toward you, allied by marriage")
	assert_eq(NpcClans.sync_alliances(clans, npcs, data(), me, null).size(), 0, "an alliance forms once")

	var mo_child: CharacterData = npcs[_child_of(mo)]
	var zhao_head: CharacterData = npcs[zhao.head]
	zhao_head.spouses.append(mo_child.id)
	mo_child.spouses.append(zhao_head.id)
	events = NpcClans.sync_alliances(clans, npcs, data(), me, null)
	assert_eq(events.size(), 1, "one alliance, reported once")
	assert_true(zhao.allies.has("mo_clan") and mo.allies.has("zhao_clan"))
	assert_eq(NpcClans.relation(clans, data(), "zhao_clan", "mo_clan"), 0)
	assert_eq(NpcClans.relation(clans, data(), "mo_clan", "zhao_clan"), 0)
	assert_true(NpcClans.rivalry_lines(clans, data()).has("The Mo Clan and the Zhao Clan are Neutral, allied by marriage."), str(NpcClans.rivalry_lines(clans, data())))


func test_player_clan_marriages_bind_clans() -> void:
	var npcs := {}
	var clans := _clans(npcs)
	var player_clan := ClanData.new()
	var yun: ClanData = clans["yun_clan"]
	var yun_member: CharacterData = npcs[_child_of(yun)]
	var my_son := Npcs.spawn(npcs, data(), seeded_rng(9), {"age_years": 25})
	player_clan.members[my_son.id] = "core"
	my_son.spouses.append(yun_member.id)
	yun_member.spouses.append(my_son.id)
	var events := NpcClans.sync_alliances(clans, npcs, data(), new_character(), player_clan)
	assert_eq(events.size(), 1)
	assert_true(yun.allies.has(NpcClans.PLAYER))


func test_relations_save_round_trip() -> void:
	var clans := _clans({})
	NpcClans.change_relation(clans, data(), "zhao_clan", NpcClans.PLAYER, -20)
	(clans["zhao_clan"] as ClanData).allies.append("yun_clan")
	var copy := NpcClans.from_dict(JSON.parse_string(JSON.stringify(NpcClans.to_dict(clans))))
	assert_eq(NpcClans.relation(copy, data(), "zhao_clan", NpcClans.PLAYER), -20)
	assert_eq(NpcClans.relation(copy, data(), "zhao_clan", "mo_clan"), -30, "unsaved keys keep their start value")
	assert_eq((copy["zhao_clan"] as ClanData).allies, ["yun_clan"] as Array[String])
	var old := ClanData.from_dict({"name": "Old Clan", "head": "x"})
	assert_eq(old.relations, {})
	assert_eq(old.allies.size(), 0)


func test_game_state_clan_deeds_and_alliances() -> void:
	var gs: Node = _root().get_node("GameState")
	var c := CharacterFactory.create("Lin Feng", gs.data, seeded_rng(), "male")
	gs.start_session(c)
	var zhao: ClanData = gs.npc_clans["zhao_clan"]
	var member_id := _child_of(zhao)
	c.add_item("qi_gathering_pill", 1)
	gs.give_gift(member_id, "qi_gathering_pill")
	assert_eq(NpcClans.relation(gs.npc_clans, gs.data, "zhao_clan", NpcClans.PLAYER), 2, "gifts warm the clan")

	NpcClans.change_relation(gs.npc_clans, gs.data, "zhao_clan", NpcClans.PLAYER, -47)  # Hostile
	var favor := int(gs.npc_favor.get(member_id, 0))
	gs.chat(member_id)
	assert_eq(int(gs.npc_favor[member_id]) - favor, roundi(Family.chat_gain(c, gs.data) * 0.5), "a hostile clan's members warm slowly")

	c.realm_index = 3  # far stronger, so the fight is certain
	var victim_id := _child_of(zhao)
	gs.hostile_act(victim_id, "kill")
	assert_false((gs.npcs[victim_id] as CharacterData).alive)
	assert_eq(NpcClans.standing_name(gs.data, NpcClans.relation(gs.npc_clans, gs.data, "zhao_clan", NpcClans.PLAYER)), "Blood feud")
	assert_true(Karma.grudge(c, zhao.head) >= 30, "the patriarch joins the feud")
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("swears a blood feud")))

	var yun: ClanData = gs.npc_clans["yun_clan"]
	var bride: CharacterData = gs.npcs[_child_of(yun)]
	Family.marry(c, bride, "wife")
	_root().get_node("GameClock").advance(1)
	assert_true(yun.allies.has(NpcClans.PLAYER), "the alliance forms as time passes")
	assert_true(EventBus.history.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("binds the Yun Clan to your family")))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.load_save_dict(saved)
	assert_true((gs.npc_clans["yun_clan"] as ClanData).allies.has(NpcClans.PLAYER), "alliances survive a save")
	gs.end_session()
