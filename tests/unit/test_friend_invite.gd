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
