extends TestCase
## FOLK-043: a Sworn friend tends your injuries once per 90 days.


func _root() -> Node:
	return Engine.get_main_loop().root


func test_sworn_friend_halves_injury_and_sets_flag() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.player.injuries["internal_injury"] = 21
	var res: Dictionary = Folk.tend_injury(gs.player, gs.npcs["hunter_ma"], gs.data, gs.world_flags, 200, 85)
	assert_false(res.is_empty())
	assert_eq(int(gs.player.injuries["internal_injury"]), 10)
	assert_eq(int(gs.world_flags["tended_hunter_ma"]), 200)
	assert_true(String(res["line"]) != "")
	gs.end_session()


func test_close_friend_cooldown_and_uninjured_do_nothing() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	var ma: CharacterData = gs.npcs["hunter_ma"]
	assert_true(Folk.tend_injury(gs.player, ma, gs.data, gs.world_flags, 200, 85).is_empty(), "not injured")
	assert_false(gs.world_flags.has("tended_hunter_ma"), "no flag when not injured")
	gs.player.injuries["internal_injury"] = 20
	assert_true(Folk.tend_injury(gs.player, ma, gs.data, gs.world_flags, 200, 84).is_empty(), "Close friend")
	assert_false(Folk.tend_injury(gs.player, ma, gs.data, gs.world_flags, 200, 90).is_empty())
	assert_true(Folk.tend_injury(gs.player, ma, gs.data, gs.world_flags, 250, 90).is_empty(), "within 90 days")
	assert_false(Folk.tend_injury(gs.player, ma, gs.data, gs.world_flags, 290, 90).is_empty(), "cooldown over")
	gs.player.injuries["internal_injury"] = 1
	gs.world_flags.erase("tended_hunter_ma")
	Folk.tend_injury(gs.player, ma, gs.data, gs.world_flags, 400, 90)
	assert_false(gs.player.injuries.has("internal_injury"), "1 day halves to 0 and heals")
	gs.end_session()


func test_line_is_stable_and_skips_rng() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.player.injuries["internal_injury"] = 20
	var a: Dictionary = Folk.tend_injury(gs.player, gs.npcs["hunter_ma"], gs.data, {}, 300, 90)
	gs.player.injuries["internal_injury"] = 20
	var b: Dictionary = Folk.tend_injury(gs.player, gs.npcs["hunter_ma"], gs.data, {}, 300, 90)
	assert_eq(a["line"], b["line"])
	gs.end_session()


func test_arrival_hook_tends_once() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	gs.current_region = "qingshi_village"
	gs.npc_favor["hunter_ma"] = 88
	gs.player.injuries["internal_injury"] = 30
	gs.receive_sworn_tending()
	assert_eq(int(gs.player.injuries["internal_injury"]), 15)
	gs.receive_sworn_tending()
	assert_eq(int(gs.player.injuries["internal_injury"]), 15, "no second tending within the cooldown")
	gs.end_session()


func _sworn_setup(gs: Node) -> void:
	gs.start_session(new_character())
	gs.current_region = "withered_bone_marsh"
	gs.npc_favor["hunter_ma"] = 88
	gs.player.injuries["internal_injury"] = 30


func test_sworn_tend_hint() -> void:
	var gs := _root().get_node("GameState")
	_sworn_setup(gs)
	var ma: CharacterData = gs.npcs["hunter_ma"]
	var day := 500
	var line := Guidance.sworn_tend_hint(gs.player, gs.data, gs.current_region, gs.npcs, gs.npc_favor, gs.world_flags, day)
	var days := Guidance.route_days(gs.player, gs.data, gs.current_region, Npcs.region_of(ma, gs.data))
	if days >= 1 and days <= 3:
		assert_true(line.begins_with("Rest with %s in " % ma.name), line)
		assert_true(line.ends_with("a sworn friend tends your wounds"), line)
		assert_true(Guidance.short_hint(line, gs.data).contains(ma.name), "short form keeps the name")
		gs.npc_favor["hunter_ma"] = 84
		assert_eq(Guidance.sworn_tend_hint(gs.player, gs.data, gs.current_region, gs.npcs, gs.npc_favor, gs.world_flags, day), "", "favor 84")
		gs.npc_favor["hunter_ma"] = 88
		gs.world_flags["tended_hunter_ma"] = day - 10
		assert_eq(Guidance.sworn_tend_hint(gs.player, gs.data, gs.current_region, gs.npcs, gs.npc_favor, gs.world_flags, day), "", "cooldown")
		gs.world_flags.erase("tended_hunter_ma")
		gs.player.parents.append("hunter_ma")
		assert_eq(Guidance.sworn_tend_hint(gs.player, gs.data, gs.current_region, gs.npcs, gs.npc_favor, gs.world_flags, day), "", "family")
		gs.player.parents.erase("hunter_ma")
	gs.player.injuries.clear()
	assert_eq(Guidance.sworn_tend_hint(gs.player, gs.data, gs.current_region, gs.npcs, gs.npc_favor, gs.world_flags, day), "", "uninjured")
	gs.player.injuries["internal_injury"] = 30
	assert_eq(Guidance.sworn_tend_hint(gs.player, gs.data, "qingshi_village", gs.npcs, gs.npc_favor, gs.world_flags, day), "", "friend is in the current region")
	gs.end_session()


func test_friend_signals_fire_once() -> void:
	var gs := _root().get_node("GameState")
	_sworn_setup(gs)
	gs.current_region = "qingshi_village"
	var tended: Array = []
	var cb := func(id: String, days: int) -> void: tended.append([id, days])
	EventBus.friend_tended.connect(cb)
	gs.receive_sworn_tending()
	gs.receive_sworn_tending()
	EventBus.friend_tended.disconnect(cb)
	assert_eq(tended.size(), 1)
	assert_eq(tended[0][0], "hunter_ma")
	assert_eq(int(tended[0][1]), 15)
	var gifts: Array = []
	var gcb := func(id: String, item: String, count: int, text: String) -> void: gifts.append([id, item, count, text])
	EventBus.friend_gift_left.connect(gcb)
	gs.npc_favor["hunter_ma"] = 70
	var drop: Dictionary = gs.data.family["folk_visits"]["drop_by"]
	var chance: Variant = drop["chance"]
	drop["chance"] = 1.0
	gs.receive_drop_by_gifts()
	gs.receive_drop_by_gifts()
	drop["chance"] = chance
	EventBus.friend_gift_left.disconnect(gcb)
	assert_eq(gifts.size(), 1, "one gift, then the cooldown")
	assert_eq(gifts[0][0], "hunter_ma")
	assert_true(int(gifts[0][2]) >= 1)
	assert_true(String(gifts[0][3]) != "")
	gs.end_session()


## GUIDE-287: family is never tended, so the People card does not promise it.
func test_sworn_tend_line_skips_family() -> void:
	var gs := _root().get_node("GameState")
	gs.start_session(new_character())
	var ma: CharacterData = gs.npcs["hunter_ma"]
	assert_true(Folk.sworn_tend_line(gs.data, ma, {}, 500, 90, gs.player) != "")
	gs.player.parents.append("hunter_ma")
	assert_eq(Folk.sworn_tend_line(gs.data, ma, {}, 500, 90, gs.player), "")
	gs.end_session()
