extends TestCase
## FOLK-055: bring a friend into your sect.


func _root() -> Node:
	return Engine.get_main_loop().root


## A rank-1 member of the Pavilion (neutral, qi_refining) with Xiao Ling at favor 60 and Qi Refining.
func _start() -> Node:
	var gs := _root().get_node("GameState")
	var p := new_character()
	p.realm_index = 1
	p.sect = {"id": "myriad_treasure_pavilion", "rank": 1, "contribution": 300}
	gs.start_session(p)
	gs.current_region = "qingshi_village"
	gs.npc_favor["xiao_ling"] = 60
	gs.npcs["xiao_ling"].realm_index = 1
	gs.npcs["xiao_ling"].alignment = 0
	return gs


func test_accept_moves_friend_to_sect_home() -> void:
	var gs := _start()
	assert_true(gs.can_invite_friend("xiao_ling"))
	gs.invite_friend_to_sect("xiao_ling")
	var npc: CharacterData = gs.npcs["xiao_ling"]
	assert_eq(String(npc.sect.get("id", "")), "myriad_treasure_pavilion")
	assert_eq(int(npc.sect.get("rank", -1)), 0)
	assert_eq(Npcs.region_of(npc, gs.data), Sects.home_region(gs.data, "myriad_treasure_pavilion"))
	assert_eq(int(gs.npc_favor["xiao_ling"]), 65)
	assert_true(not gs.can_invite_friend("xiao_ling"), "once only")
	var spot: Dictionary = gs.npc_spot("xiao_ling")
	assert_true((spot["pos"] as Vector2).x > 0.0)


func test_decline_for_realm_says_why_and_stays() -> void:
	var gs := _start()
	gs.npcs["xiao_ling"].realm_index = 0
	var r := FriendInvite.invite(gs.player, gs.data, gs.world_flags, gs.npcs["xiao_ling"], 60)
	assert_true(not r["ok"])
	assert_true(String(r["reason"]).contains("cultivation"))
	assert_true(gs.npcs["xiao_ling"].is_rogue())
	assert_eq(Npcs.region_of(gs.npcs["xiao_ling"], gs.data), "qingshi_village")


func test_decline_for_alignment() -> void:
	var gs := _start()
	gs.npcs["xiao_ling"].alignment = -900
	var r := FriendInvite.invite(gs.player, gs.data, gs.world_flags, gs.npcs["xiao_ling"], 60)
	assert_true(not r["ok"] and String(r["reason"]).contains("past"))


func test_needs_favor_rank_and_rogue_friend() -> void:
	var gs := _start()
	gs.npc_favor["xiao_ling"] = 59
	assert_true(not gs.can_invite_friend("xiao_ling"))
	gs.npc_favor["xiao_ling"] = 60
	gs.player.sect["rank"] = 0
	assert_true(not gs.can_invite_friend("xiao_ling"))
	gs.player.sect["rank"] = 1
	gs.npcs["xiao_ling"].sect = {"id": "azure_cloud_sect", "rank": 0, "contribution": 0}
	assert_true(not gs.can_invite_friend("xiao_ling"))
	gs.player.sect = {}
	gs.npcs["xiao_ling"].sect = {}
	assert_true(not gs.can_invite_friend("xiao_ling"), "rogue players cannot invite")


func test_save_round_trip_keeps_membership() -> void:
	var gs := _start()
	gs.invite_friend_to_sect("xiao_ling")
	var back := CharacterData.from_dict(gs.npcs["xiao_ling"].to_dict())
	assert_eq(String(back.sect.get("id", "")), "myriad_treasure_pavilion")
	assert_eq(back.home_region, Sects.home_region(gs.data, "myriad_treasure_pavilion"))
	var flags: Dictionary = JSON.parse_string(JSON.stringify(gs.world_flags))
	assert_true(bool(flags.get("friend_invited_xiao_ling", false)))


func test_sect_mates_lists_joined_friend() -> void:
	var gs := _start()
	assert_eq(FriendInvite.sect_mates(gs.player, gs.npcs, gs.data, gs.world_flags).size(), 0)
	assert_eq(FriendInvite.sect_mates_line([]), "")
	gs.invite_friend_to_sect("xiao_ling")
	var mates := FriendInvite.sect_mates(gs.player, gs.npcs, gs.data, gs.world_flags)
	assert_eq(mates.size(), 1)
	assert_eq(String(mates[0]["id"]), "xiao_ling")
	assert_true(FriendInvite.sect_mates_line(mates).begins_with("Sect-mates you know: "))
	assert_true(FriendInvite.sect_mates_line(mates).contains("Xiao Ling"))
	assert_eq(Npcs.region_of(gs.npcs["xiao_ling"], gs.data), Sects.home_region(gs.data, "myriad_treasure_pavilion"))


## SECT-054: the first living sect-mate (by id) attends the lecture.
func test_lecture_mate_picks_first_living_mate() -> void:
	var gs := _start()
	assert_eq(Sects.lecture_mate(gs.player, gs.data, gs.npcs, gs.world_flags), "", "no mate")
	gs.invite_friend_to_sect("xiao_ling")
	assert_eq(Sects.lecture_mate(gs.player, gs.data, gs.npcs, gs.world_flags), "xiao_ling")
	var other := ""
	for id: String in gs.data.npcs:
		if id < "xiao_ling":
			other = id
			break
	assert_true(other != "")
	gs.npcs[other].sect = gs.player.sect.duplicate()
	gs.world_flags[FriendInvite.flag_key(other)] = true
	assert_eq(Sects.lecture_mate(gs.player, gs.data, gs.npcs, gs.world_flags), other, "two mates: first by id")
	gs.npcs[other].alive = false
	assert_eq(Sects.lecture_mate(gs.player, gs.data, gs.npcs, gs.world_flags), "xiao_ling", "dead mate skipped")


func test_attend_lecture_raises_mate_favor_once() -> void:
	var gs := _start()
	gs.invite_friend_to_sect("xiao_ling")
	var before := int(gs.npc_favor["xiao_ling"])
	gs.attend_lecture()
	assert_eq(int(gs.npc_favor["xiao_ling"]), before + int(gs.data.lecture_mate["favor"]))
	gs.attend_lecture()  # same month: refused
	assert_eq(int(gs.npc_favor["xiao_ling"]), before + int(gs.data.lecture_mate["favor"]))
	gs.end_session()


func test_attend_lecture_without_mate_changes_no_favor() -> void:
	var gs := _start()
	var before := int(gs.npc_favor["xiao_ling"])
	gs.attend_lecture()
	assert_eq(int(gs.npc_favor["xiao_ling"]), before)
	gs.end_session()


## C-432: a friend with lecture_mate_lines speaks in their own voice; one without falls back to the generic line.
func test_lecture_mate_uses_own_line() -> void:
	var gs := _start()
	gs.invite_friend_to_sect("xiao_ling")
	var seen: Array = []
	var cb := func(text: String, _cat: String = "") -> void: seen.append(text)
	EventBus.message_posted.connect(cb)
	gs.attend_lecture()
	EventBus.message_posted.disconnect(cb)
	var elder := String(Sects.lecture_def(gs.player, gs.data).get("elder", "the elder"))
	var own: Array = []
	for l in gs.data.npcs["xiao_ling"]["lecture_mate_lines"]:
		own.append(String(l).replace("{elder}", elder))
	var hit := false
	for t in seen:
		if own.has(t):
			hit = true
	assert_true(hit, "one of Xiao Ling's own lines was posted: %s" % str(seen))
	gs.end_session()


func test_lecture_mate_lines_validation() -> void:
	var d := data()
	var ling: Array = d.npcs["xiao_ling"]["lecture_mate_lines"]
	var ma: Array = d.npcs["hunter_ma"]["lecture_mate_lines"]
	d.npcs["xiao_ling"]["lecture_mate_lines"] = ["a", "b", "c"]
	d.npcs["hunter_ma"]["lecture_mate_lines"] = ["x".repeat(161)]
	d.load_errors.clear()
	d._validate()
	var text := "\n".join(d.load_errors)
	d.npcs["xiao_ling"]["lecture_mate_lines"] = ling
	d.npcs["hunter_ma"]["lecture_mate_lines"] = ma
	d.load_errors.clear()
	assert_true(text.contains("'xiao_ling' lecture_mate_lines needs 1-2"), text)
	assert_true(text.contains("'hunter_ma' lecture_mate_lines entries"), text)


## C-430: a sect-mate friend greets in their sect voice; others keep village lines; validation.
func test_sect_mate_greeting_and_validation() -> void:
	var gs := _start()
	var ling: CharacterData = gs.npcs["xiao_ling"]
	assert_eq(FriendInvite.sect_mate_greeting(gs.player, gs.data, gs.world_flags, ling, 5), "", "not yet a mate")
	gs.invite_friend_to_sect("xiao_ling")
	var line := FriendInvite.sect_mate_greeting(gs.player, gs.data, gs.world_flags, ling, 5)
	assert_true(line != "" and not line.contains("{sect}"), line)
	assert_eq(line, FriendInvite.sect_mate_greeting(gs.player, gs.data, gs.world_flags, ling, 5), "stable")
	assert_true(line in gs.data.npcs["xiao_ling"]["sect_mate_lines"] or line.contains("Myriad"), line)
	assert_eq(gs.greeting_for("xiao_ling").length() > 0, true)
	assert_eq(FriendInvite.sect_mate_greeting(gs.player, gs.data, gs.world_flags, gs.npcs["elder_mo"], 5), "")
	var d: GameData = gs.data
	var old: Array = d.npcs["xiao_ling"]["sect_mate_lines"]
	d.npcs["xiao_ling"]["sect_mate_lines"] = ["x".repeat(141), "ok"]
	d.load_errors.clear()
	d._validate()
	var text := "\n".join(d.load_errors)
	d.npcs["xiao_ling"]["sect_mate_lines"] = old
	d.load_errors.clear()
	assert_true(text.contains("'xiao_ling' sect_mate_lines entries"), text)


## C-434: every cultivating named friend has a lecture voice of their own.
func test_every_cultivating_friend_has_lecture_mate_lines() -> void:
	var d := data()
	for id: String in ["blood_lotus_xue", "broker_shen", "patriarch_lin", "old_monster_gui", "alchemist_ye", "lord_xuan", "saint_lan", "sage_wen"]:
		assert_eq((d.npcs[id].get("lecture_mate_lines", []) as Array).size(), 2, id)


## FOLK-060: a sect-mate friend at the hall asks for an item.
func test_sect_mate_asks_a_favor_at_the_hall() -> void:
	var gs := _start()
	gs.invite_friend_to_sect("xiao_ling")
	var rules: Dictionary = gs.data.family["folk_requests"]
	rules["monthly_chance"] = 1.0
	rules["sect_mate_chance"] = 1.0
	var e := Folk.monthly_request(gs.player, gs.npcs, gs.data, seeded_rng(), "qingshi_village", gs.npc_favor, 100, gs.world_flags)
	assert_eq(String(e["source"]), "sect_mate")
	assert_eq(String(e["npc_id"]), "xiao_ling")
	assert_false(String(e["text"]).contains("{"))
	var listed := false
	for a: Dictionary in rules["sect_mate_asks"]:
		listed = listed or a["item"] == e["item"]
	assert_true(listed, "drawn from sect_mate_asks")
	assert_true(Letters.request_lines(gs.player, gs.data, gs.npcs, 100)[0].contains("Xiao Ling"))


func test_sect_mate_chance_zero_and_no_mate_keep_villager_rule() -> void:
	var gs := _start()
	var rules: Dictionary = gs.data.family["folk_requests"]
	rules["monthly_chance"] = 1.0
	rules["sect_mate_chance"] = 1.0
	assert_true(Folk.sect_mate_askers(gs.player, gs.npcs, gs.data, gs.world_flags, gs.npc_favor, 100, 0).is_empty(), "no mate yet")
	gs.invite_friend_to_sect("xiao_ling")
	rules["sect_mate_chance"] = 0.0
	var e := Folk.monthly_request(gs.player, gs.npcs, gs.data, seeded_rng(), "qingshi_village", gs.npc_favor, 100, gs.world_flags)
	assert_true(e.is_empty() or String(e["source"]) == "folk", "villager rule unchanged")
	# max_open counts sect-mate asks, and a mate away from the hall asks nothing
	gs.player.letter_requests.clear()
	rules["sect_mate_chance"] = 1.0
	rules["max_open"] = 1
	assert_false(Folk.monthly_request(gs.player, gs.npcs, gs.data, seeded_rng(), "qingshi_village", gs.npc_favor, 100, gs.world_flags).is_empty())
	assert_true(Folk.monthly_request(gs.player, gs.npcs, gs.data, seeded_rng(), "qingshi_village", gs.npc_favor, 100, gs.world_flags).is_empty(), "max_open respected")
	gs.player.letter_requests.clear()
	gs.npcs["xiao_ling"].home_region = "qingshi_village"
	assert_true(Folk.sect_mate_askers(gs.player, gs.npcs, gs.data, gs.world_flags, gs.npc_favor, 100, 0).is_empty(), "away from the hall")


func test_giving_a_sect_mate_the_item_adds_favor() -> void:
	var gs := _start()
	gs.invite_friend_to_sect("xiao_ling")
	gs.player.letter_requests.append({"npc_id": "xiao_ling", "item": "spirit_herb", "count": 2, "until": GameClock.total_days + 20, "favor": 6, "effects": {}, "source": "sect_mate", "text": "x"})
	gs.current_region = Npcs.region_of(gs.npcs["xiao_ling"], gs.data)
	gs.player.add_item("spirit_herb", 2)
	var before := int(gs.npc_favor["xiao_ling"])
	gs.answer_letter_request("xiao_ling")
	assert_eq(gs.player.item_count("spirit_herb"), 0)
	assert_eq(int(gs.npc_favor["xiao_ling"]), before + 6)
