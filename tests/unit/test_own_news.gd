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


func test_congratulate_menu_first_while_pending_then_gone() -> void:  # WU-629
	var c := _start()
	var gs := _gs()
	gs.npc_favor["xiao_ling"] = 50
	FolkNews.queue_own(c, gs.data, gs.npc_favor, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", GameClock.total_days)
	var menu: Node = load("res://src/world/interactables/npc.gd").new()
	menu.npc_id = "xiao_ling"
	assert_true(menu.own_news_waiting())
	var options: Array[Dictionary] = menu.get_options()
	assert_eq(String(options[0]["label"]), "Congratulate %s" % gs.npcs["xiao_ling"].name, "first while pending")
	(options[0]["action"] as Callable).call()
	assert_false(menu.own_news_waiting())
	for o in menu.get_options():
		assert_false(String(o["label"]).begins_with("Congratulate"), "gone after congratulating")
	menu.free()
	gs.end_session()


func test_congratulate_first_keeps_order_when_not_pending() -> void:  # WU-629
	var npc_script: GDScript = load("res://src/world/interactables/npc.gd")
	var opts: Array[Dictionary] = [{"label": "Look"}, {"label": "Talk"}, {"label": "Congratulate X"}]
	assert_eq(String(npc_script.congratulate_first(opts, "Congratulate X", false)[0]["label"]), "Look")
	assert_eq(String(npc_script.congratulate_first(opts, "Congratulate X", true)[0]["label"]), "Congratulate X")


func test_congratulate_opens_a_face_to_face_card() -> void:  # WU-629
	var card := FriendSceneCard.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(card)
	var c := _start()
	card.open("xiao_ling", "Xiao Ling", "Thank you.", "", "", "", true)
	assert_true(card.shows_player())
	card.open("xiao_ling", "Xiao Ling", "Hello.")
	assert_false(card.shows_player())
	card.queue_free()
	_gs().end_session()
	assert_true(EmoteBubble.KINDS.has("own_news"))
	assert_true(c != null)


func test_expired_own_news_shows_no_bubble_even_before_pruning() -> void:  # FOLK-051
	var c := _start()
	var gs := _gs()
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", 10)
	assert_true(FolkNews.has_pending(c, "xiao_ling", gs.data, 20), "fresh")
	assert_false(FolkNews.has_pending(c, "xiao_ling", gs.data, 10 + 31), "expired: no bubble")
	assert_true(c.friend_news.has("xiao_ling"), "pure: not erased")
	assert_true(FolkNews.has_pending(c, "xiao_ling"), "no day given keeps the old behavior")
	gs.end_session()


func test_liked_gift_with_news_stays_under_the_cap() -> void:  # FOLK-051
	var c := _start()
	var gs := _gs()
	var cap := Family.gift_cap(gs.data, false)
	gs.npc_favor["xiao_ling"] = cap - 1
	c.add_item("moon_cake", 1)
	FolkNews.queue_own(c, gs.data, gs.npc_favor, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", GameClock.total_days)
	gs.give_gift("xiao_ling", "moon_cake")
	assert_true(int(gs.npc_favor["xiao_ling"]) <= cap, "favor %d within cap %d" % [int(gs.npc_favor["xiao_ling"]), cap])
	assert_false(c.friend_news.has("xiao_ling"), "news still cleared")
	gs.end_session()
