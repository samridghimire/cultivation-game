extends TestCase
## FOLK-050: friends' own news (queue_own, take_own, congratulate, save round trip, GameState wiring).


func _gs() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")


func _start() -> CharacterData:
	var gs := _gs()
	var c := CharacterFactory.create("Newsy", gs.data, seeded_rng(77))
	c.spiritual_roots = {"fire": 80}
	gs.start_session(c)
	c.home_region = "qingshi_village"
	gs.current_region = "qingshi_village"
	return c


func test_queue_own_requires_named_living_friend() -> void:
	var c := _start()
	var gs := _gs()
	var xl: CharacterData = gs.npcs["xiao_ling"]
	assert_false(FolkNews.queue_own(c, gs.data, {"xiao_ling": 20}, xl, "qi_start", "Qi Refining", 10), "low favor ignored")
	assert_true(FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, xl, "qi_start", "Qi Refining", 10))
	var stranger := CharacterFactory.create("Nobody", gs.data, seeded_rng(5))
	assert_false(FolkNews.queue_own(c, gs.data, {stranger.id: 90}, stranger, "qi_start", "x", 10), "generated NPC ignored")
	xl.alive = false
	c.friend_news.clear()
	assert_false(FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, xl, "qi_start", "x", 10), "dead ignored")


func test_take_own_once_then_congratulate_once() -> void:
	var c := _start()
	var gs := _gs()
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "breakthrough", "Foundation Establishment", 10)
	assert_true(FolkNews.has_own(c, gs.data, "xiao_ling", 12))
	assert_true(FolkNews.has_pending(c, "xiao_ling"), "bubble")
	var line := FolkNews.take_own(c, gs.data, "xiao_ling", 12)
	assert_true(line != "" and not line.contains("{"), "line filled: " + line)
	assert_eq(FolkNews.take_own(c, gs.data, "xiao_ling", 12), "", "once")
	assert_false(FolkNews.has_pending(c, "xiao_ling"), "bubble gone after hearing")
	assert_true(FolkNews.can_congratulate(c, gs.data, "xiao_ling", 12))
	assert_eq(FolkNews.congratulate(c, gs.data, "xiao_ling", 12), 3)
	assert_eq(FolkNews.congratulate(c, gs.data, "xiao_ling", 12), 0, "only once")


func test_own_news_expires() -> void:
	var c := _start()
	var gs := _gs()
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", 10)
	assert_false(FolkNews.has_own(c, gs.data, "xiao_ling", 10 + 31))
	assert_false(c.friend_news.has("xiao_ling"), "dropped")


func test_save_round_trip_and_old_dict() -> void:
	var c := _start()
	var gs := _gs()
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", 10)
	var d := c.to_dict()
	assert_true(CharacterData.from_dict(d).friend_news.has("xiao_ling"))
	d.erase("friend_news")
	assert_eq(CharacterData.from_dict(d).friend_news.size(), 0)


func test_gamestate_greeting_congratulate_and_gift() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["xiao_ling"] = 50
	FolkNews.queue_own(c, gs.data, gs.npc_favor, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", GameClock.total_days)
	var greeting: String = gs.greeting_for("xiao_ling")
	assert_true(greeting.contains("Qi Refining") or greeting.contains("Newsy"), "own line: " + greeting)
	assert_true(gs.can_congratulate("xiao_ling"))
	gs.congratulate("xiao_ling")
	assert_eq(int(gs.npc_favor["xiao_ling"]), 53)
	gs.congratulate("xiao_ling")
	assert_eq(int(gs.npc_favor["xiao_ling"]), 53, "second congratulate does nothing")
	assert_false(gs.can_congratulate("xiao_ling"))


func test_simulate_events_carry_kind() -> void:
	var gs := _gs()
	_start()
	var xl: CharacterData = gs.npcs["xiao_ling"]
	xl.realm_index = 0
	var seen := false
	for i in 400:
		xl.qi = 1.0e9
		for ev in Npcs.simulate(gs.npcs, gs.data, 30, seeded_rng(i), {}, gs.world_flags):
			if ev["npc_id"] == "xiao_ling" and ev.get("kind", "") == "qi_start":
				seen = true
				assert_eq(String(ev["realm"]), "Qi Refining")
		if seen:
			break
	assert_true(seen, "Xiao Ling's qi_start event carries kind and realm")
