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
