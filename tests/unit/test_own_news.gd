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


## C-425: a bad congrats_reply is rejected; the thanks uses the NPC's own line.
func test_congrats_reply_validation() -> void:
	var d := data()
	var old: Variant = d.npcs["elder_mo"]["congrats_reply"]
	d.npcs["elder_mo"]["congrats_reply"] = ["x".repeat(121)]
	d.load_errors.clear()
	d._validate()
	var text := "\n".join(d.load_errors)
	assert_true(text.contains("'elder_mo' congrats_reply entries"), text)
	d.npcs["elder_mo"]["congrats_reply"] = ["a", "b", "c"]
	d.load_errors.clear()
	d._validate()
	assert_true("\n".join(d.load_errors).contains("'elder_mo' congrats_reply needs 1-2"))
	d.npcs["elder_mo"]["congrats_reply"] = old


func test_congratulate_uses_npc_voice() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["xiao_ling"] = 50
	FolkNews.queue_own(c, gs.data, gs.npc_favor, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", GameClock.total_days)
	var got: Array = []
	var cb := func(_id: String, _n: String, text: String) -> void: got.append(text)
	EventBus.friend_congratulated.connect(cb)
	gs.congratulate("xiao_ling")
	EventBus.friend_congratulated.disconnect(cb)
	assert_eq(got.size(), 1)
	var ok := false
	for l: String in gs.data.npcs["xiao_ling"]["congrats_reply"]:
		if got[0] == "\"%s\"" % l.replace("{player}", c.name):
			ok = true
	assert_true(ok, str(got))


## C-426: friends beyond the village have their own congrats, breakthrough and wedding lines.
func test_far_friends_have_own_voices() -> void:
	var data: GameData = _gs().data
	for id: String in ["herbalist_lan", "peddler_hei", "swordsman_yun", "disciple_bai", "broker_qian", "alchemist_hua", "hermit_gu"]:
		var def: Dictionary = data.npcs[id]
		assert_true(def.has("congrats_reply"), id + " congrats_reply")
		var nl: Dictionary = def.get("news_lines", {})
		assert_true((nl.get("breakthrough", []) as Array).size() >= 1 and String(nl["breakthrough"][0]).contains("{realm}"), id + " breakthrough")
		assert_true((nl.get("wedding", []) as Array).size() >= 1 and String(nl["wedding"][0]).contains("{spouse}"), id + " wedding")


func test_journal_rows_fresh_told_expired_sorted() -> void:
	var c := _start()
	var gs := _gs()
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50, "elder_mo": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", 10)
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50, "elder_mo": 50}, gs.npcs["elder_mo"], "breakthrough", "Core Formation", 20)
	var rows := FolkNews.journal_rows(c, gs.data, gs.npcs, 25)
	assert_eq(rows.size(), 2)
	assert_eq(String(rows[0]["npc_id"]), "xiao_ling", "fewest days left first")
	assert_true(String(rows[0]["text"]).contains("began Qi Refining: congratulate them (15 days left)"), String(rows[0]["text"]))
	assert_true(String(rows[1]["text"]).contains("broke through to Core Formation"))
	FolkNews.take_own(c, gs.data, "xiao_ling", 25)
	assert_eq(FolkNews.journal_rows(c, gs.data, gs.npcs, 25).size(), 2, "told but not congratulated is still listed")
	assert_eq(FolkNews.journal_rows(c, gs.data, gs.npcs, 45).size(), 1, "expired gone")
	assert_eq(c.friend_news.size(), 2, "pure: nothing erased")


func test_journal_includes_row_after_queued_news() -> void:
	var c := _start()
	var gs := _gs()
	gs.npc_favor["xiao_ling"] = 50
	FolkNews.queue_own(c, gs.data, gs.npc_favor, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", GameClock.total_days)
	var found := false
	for e: Dictionary in gs.journal_entries():
		if String(e.get("text", "")).contains("Xiao Ling began Qi Refining: congratulate them"):
			found = true
	assert_true(found, "journal row present")


func test_catch_up_queues_missed_qi_start() -> void:  # FOLK-053
	var c := _start()
	var gs := _gs()
	var xl: CharacterData = gs.npcs["xiao_ling"]
	c.friend_news_realm["xiao_ling"] = 0
	xl.realm_index = 1
	assert_eq(FolkNews.catch_up(c, gs.data, {"xiao_ling": 30}, gs.npcs, 50).size(), 0, "favor 30 queues nothing")
	assert_eq(int(c.friend_news_realm["xiao_ling"]), 0, "memory unchanged")
	var got := FolkNews.catch_up(c, gs.data, {"xiao_ling": 40}, gs.npcs, 50)
	assert_eq(got, ["xiao_ling"] as Array[String])
	assert_eq(String(c.friend_news["xiao_ling"]["kind"]), "qi_start")
	assert_eq(int(c.friend_news_realm["xiao_ling"]), 1)
	assert_eq(FolkNews.catch_up(c, gs.data, {"xiao_ling": 40}, gs.npcs, 50).size(), 0, "not twice")


func test_seed_does_not_announce_starting_realms() -> void:  # FOLK-053
	var c := _start()
	var gs := _gs()
	c.friend_news_realm.clear()
	FolkNews.remember_realms(c, gs.data, gs.npcs)
	assert_eq(FolkNews.catch_up(c, gs.data, {"elder_mo": 60, "xiao_ling": 60}, gs.npcs, 5).size(), 0)


func test_old_save_without_memory_loads_quietly() -> void:  # FOLK-053
	var c := _start()
	var gs := _gs()
	var d := c.to_dict()
	d.erase("friend_news_realm")
	var c2 := CharacterData.from_dict(d)
	assert_true(c2.friend_news_realm.is_empty())
	gs.npcs["xiao_ling"].realm_index = 1
	FolkNews.remember_realms(c2, gs.data, gs.npcs)
	assert_eq(FolkNews.catch_up(c2, gs.data, {"xiao_ling": 90}, gs.npcs, 5).size(), 0)
	var c3 := CharacterData.from_dict(c2.to_dict())
	assert_eq(int(c3.friend_news_realm.get("xiao_ling", -1)), 1, "round trip")


func test_daily_handler_catches_up_once() -> void:  # FOLK-053
	var c := _start()
	var gs := _gs()
	c.friend_news_realm["xiao_ling"] = 0
	gs.npcs["xiao_ling"].realm_index = 1
	gs.npc_favor["xiao_ling"] = 45
	gs._pass_time(1)
	assert_true(c.friend_news.has("xiao_ling"), "news reached the player")
	assert_eq(int(c.friend_news_realm["xiao_ling"]), 1)


func test_journal_row_names_current_region() -> void:  # FOLK-053
	var c := _start()
	var gs := _gs()
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", 10)
	var xl: CharacterData = gs.npcs["xiao_ling"]
	var other := ""
	for r: String in gs.data.regions:
		if r != Npcs.region_of(xl, gs.data):
			other = r
			break
	xl.home_region = other
	var rows := FolkNews.journal_rows(c, gs.data, gs.npcs, 12)
	assert_eq(String(rows[0]["region"]), Npcs.region_of(xl, gs.data))


func test_letter_favor_and_rows() -> void:
	var c := _start()
	var gs := _gs()
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", 10)
	assert_eq(FolkNews.letter_rows(c, gs.data, gs.npcs, "qingshi_village", 12).size(), 0, "friend is in this region")
	assert_eq(FolkNews.letter_rows(c, gs.data, gs.npcs, "elsewhere", 12).size(), 1)
	assert_eq(FolkNews.congratulate_by_letter(c, gs.data, "xiao_ling", 12), 2, "letter favor")
	assert_false(c.friend_news.has("xiao_ling"), "entry erased")
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", 10)
	assert_eq(FolkNews.congratulate_by_letter(c, gs.data, "xiao_ling", 10 + 31), 0, "stale")


func test_send_congratulations_integration() -> void:
	var c := _start()
	var gs := _gs()
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", GameClock.total_days)
	gs.npc_favor["xiao_ling"] = 50
	gs.send_congratulations("xiao_ling")
	assert_eq(int(gs.npc_favor["xiao_ling"]), 50, "refused in the same region")
	assert_true(c.friend_news.has("xiao_ling"), "news kept")
	gs.current_region = "withered_bone_marsh"
	var seen: Array = []
	var cb := func(t: String, _cat: String) -> void: seen.append(t)
	EventBus.message_posted.connect(cb)
	gs.send_congratulations("xiao_ling")
	EventBus.message_posted.disconnect(cb)
	assert_eq(int(gs.npc_favor["xiao_ling"]), 52)
	assert_false(c.friend_news.has("xiao_ling"))
	var posted := false  # C-435: the reply is one of her lines
	for t: String in seen:
		for l: String in gs.data.npcs["xiao_ling"]["letter_thanks_lines"]:
			if t.contains(l.replace("{player}", c.name)):
				posted = true
	assert_true(posted, "reply posted")


func test_letter_thanks_lines_validation() -> void:
	var d := data()
	var orig: Array = d.npcs["xiao_ling"]["letter_thanks_lines"]
	d.npcs["xiao_ling"]["letter_thanks_lines"] = ["x".repeat(141)]
	d.load_errors.clear()
	d._validate()
	assert_true("\n".join(d.load_errors).contains("'xiao_ling' letter_thanks_lines entries"))
	d.npcs["xiao_ling"]["letter_thanks_lines"] = orig
	d.load_errors.clear()


func test_letter_hint() -> void:
	var c := _start()
	var gs := _gs()
	var today := 100
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", today - 22)  # 8 days left
	assert_eq(Guidance.congratulate_letter_hint(c, gs.data, gs.npcs, "qingshi_village", today), "", "friend is here")
	var far := ""
	for id: String in gs.data.regions.keys():
		if id != "qingshi_village" and Guidance.route_days(c, gs.data, id, "qingshi_village") > int(gs.data.family["home_call"]["max_route_days"]):
			far = id
	if far != "":
		var line := Guidance.congratulate_letter_hint(c, gs.data, gs.npcs, far, today)
		assert_true(line.begins_with("Write to Xiao Ling: congratulations on Qi Refining (8 days left)"), line)
	FolkNews.queue_own(c, gs.data, {"xiao_ling": 50}, gs.npcs["xiao_ling"], "qi_start", "Qi Refining", today - 5)  # 25 left
	assert_eq(Guidance.congratulate_letter_hint(c, gs.data, gs.npcs, "withered_bone_marsh", today), "", "too many days left")
